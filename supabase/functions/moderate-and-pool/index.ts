// moderate-and-pool — the server-side moderation gate (CONTRACTS §4, §5, §9).
//
// Flow:
//   1. Verify caller JWT -> user.
//   2. Load entry (service role); confirm caller is the author.
//   3. Call OpenAI omni-moderation-latest on the body.
//   4. Map -> ModerationResult, run detectPii, decide().
//   5. Update entry (service role) + insert moderation_log.
//   6. Return the CONTRACTS §4 JSON (with crisis payload when held_selfharm).
//
// FAIL CLOSED: on any OpenAI/parse error we do NOT pool. The entry is left in a
// non-shareable held state ('pending') and a safe message is returned.

import { createClient } from 'jsr:@supabase/supabase-js@2';
import { corsHeaders, handlePreflight, jsonResponse } from '../_shared/cors.ts';
import {
  decide,
  type ModerationResult,
  type Decision,
} from '../_shared/moderation.ts';
import { detectPii } from '../_shared/pii.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const OPENAI_API_KEY = Deno.env.get('OPENAI_API_KEY') ?? '';

// Crisis resources for Singapore (CONTRACTS §9). VERIFY AT BUILD TIME against
// SOS / mindline before store submission — see docs/crisis-resources.md.
const CRISIS_SG = {
  region: 'SG',
  resources: [
    {
      name: 'Samaritans of Singapore (SOS)',
      contact: '1-767',
      hours: '24h',
      note: 'verify at build time',
    },
    {
      name: 'SOS CareText (WhatsApp)',
      contact: '9151 1767',
      hours: '24h',
      note: 'verify at build time',
    },
    {
      name: 'national mindline',
      contact: '1771',
      hours: 'verify hours',
      note: 'verify at build time',
    },
  ],
};

interface OpenAiModerationCategory {
  categories: Record<string, boolean>;
  category_scores: Record<string, number>;
  flagged: boolean;
}

function mapOpenAi(result: OpenAiModerationCategory): ModerationResult {
  return {
    flagged: !!result.flagged,
    categories: result.categories ?? {},
    category_scores: result.category_scores ?? {},
  };
}

Deno.serve(async (req: Request) => {
  const pf = handlePreflight(req);
  if (pf) return pf;

  if (req.method !== 'POST') {
    return jsonResponse({ error: 'method not allowed' }, 405);
  }

  // --- 1. Verify JWT ---------------------------------------------------------
  const authHeader = req.headers.get('Authorization') ?? '';
  const jwt = authHeader.replace(/^Bearer\s+/i, '').trim();
  if (!jwt) {
    return jsonResponse({ error: 'missing authorization' }, 401);
  }

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { data: userData, error: userErr } = await admin.auth.getUser(jwt);
  if (userErr || !userData?.user) {
    return jsonResponse({ error: 'invalid token' }, 401);
  }
  const userId = userData.user.id;

  // --- parse body ------------------------------------------------------------
  let entryId: string | undefined;
  try {
    const parsed = await req.json();
    entryId = parsed?.entry_id;
  } catch {
    return jsonResponse({ error: 'invalid json body' }, 400);
  }
  if (!entryId) {
    return jsonResponse({ error: 'entry_id required' }, 400);
  }

  // --- 2. Load entry (service role) + confirm author -------------------------
  const { data: entry, error: entryErr } = await admin
    .from('entries')
    .select('id, author_id, body')
    .eq('id', entryId)
    .single();

  if (entryErr || !entry) {
    return jsonResponse({ error: 'entry not found' }, 404);
  }
  if (entry.author_id !== userId) {
    return jsonResponse({ error: 'forbidden' }, 403);
  }

  // --- 3. OpenAI moderation (fail closed) -----------------------------------
  let modResult: ModerationResult | null = null;
  let rawResult: unknown = null;
  let openAiFailed = false;

  if (!OPENAI_API_KEY) {
    openAiFailed = true;
  } else {
    try {
      const resp = await fetch('https://api.openai.com/v1/moderations', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${OPENAI_API_KEY}`,
        },
        body: JSON.stringify({
          model: 'omni-moderation-latest',
          input: entry.body ?? '',
        }),
      });

      if (!resp.ok) {
        openAiFailed = true;
        rawResult = { error: `openai status ${resp.status}` };
      } else {
        const json = await resp.json();
        rawResult = json;
        const first = json?.results?.[0];
        if (!first) {
          openAiFailed = true;
        } else {
          modResult = mapOpenAi(first as OpenAiModerationCategory);
        }
      }
    } catch (e) {
      openAiFailed = true;
      rawResult = { error: String(e) };
    }
  }

  // --- FAIL CLOSED: do not pool on any moderation failure -------------------
  if (openAiFailed || !modResult) {
    await admin
      .from('entries')
      .update({
        moderation_status: 'pending',
        is_shareable: false,
        moderated_at: new Date().toISOString(),
      })
      .eq('id', entry.id);

    await admin.from('moderation_log').insert({
      entry_id: entry.id,
      provider: 'openai:omni-moderation-latest',
      result: rawResult ?? { error: 'moderation unavailable' },
      action: 'pending',
    });

    return jsonResponse({
      status: 'pending',
      is_shareable: false,
      categories: {},
      message:
        'We could not check this entry right now, so it was not shared. Please try again later.',
    });
  }

  // --- 4. PII + decision -----------------------------------------------------
  const piiResult = detectPii(entry.body ?? '');
  const { decision, isShareable, reason } = decide(modResult, piiResult);

  // --- 5. Persist entry + log ------------------------------------------------
  const nowIso = new Date().toISOString();
  await admin
    .from('entries')
    .update({
      moderation_status: decision as Decision,
      is_shareable: isShareable,
      moderation_categories: modResult.category_scores,
      moderated_at: nowIso,
    })
    .eq('id', entry.id);

  await admin.from('moderation_log').insert([
    {
      entry_id: entry.id,
      provider: 'openai:omni-moderation-latest',
      result: rawResult ?? {},
      action: decision,
    },
    {
      entry_id: entry.id,
      provider: 'pii-regex',
      result: { hasPii: piiResult.hasPii, kinds: piiResult.kinds },
      action: decision,
    },
  ]);

  // --- 6. Response -----------------------------------------------------------
  const body: Record<string, unknown> = {
    status: decision,
    is_shareable: isShareable,
    categories: modResult.category_scores,
    message: reason,
  };
  if (decision === 'held_selfharm') {
    body.crisis = CRISIS_SG;
  }

  return jsonResponse(body);
});
