// serve-entry — authenticated wrapper over rpc('serve_entry') (CONTRACTS §4).
// The RPC relies on auth.uid(), so we forward the caller's JWT (client authed
// AS THE USER) rather than using the service role.

import { createClient } from 'jsr:@supabase/supabase-js@2';
import { handlePreflight, jsonResponse } from '../_shared/cors.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!;

Deno.serve(async (req: Request) => {
  const pf = handlePreflight(req);
  if (pf) return pf;

  if (req.method !== 'POST') {
    return jsonResponse({ error: 'method not allowed' }, 405);
  }

  const authHeader = req.headers.get('Authorization') ?? '';
  const jwt = authHeader.replace(/^Bearer\s+/i, '').trim();
  if (!jwt) {
    return jsonResponse({ error: 'missing authorization' }, 401);
  }

  // Client authed AS THE USER: forward the JWT so auth.uid() resolves in the RPC.
  const supabase = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: `Bearer ${jwt}` } },
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // Verify the token is valid (also returns a clean 401 for expired tokens).
  const { data: userData, error: userErr } = await supabase.auth.getUser(jwt);
  if (userErr || !userData?.user) {
    return jsonResponse({ error: 'invalid token' }, 401);
  }

  const { data, error } = await supabase.rpc('serve_entry');
  if (error) {
    return jsonResponse({ error: error.message }, 500);
  }

  // serve_entry returns a set; take the first row (or null on cold-start).
  const row = Array.isArray(data) ? (data[0] ?? null) : (data ?? null);
  return jsonResponse({ entry: row });
});
