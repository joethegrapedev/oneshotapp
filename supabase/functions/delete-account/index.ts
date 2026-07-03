// delete-account — purge caller data then delete the auth user (CONTRACTS §4).
//   1. Verify JWT.
//   2. rpc('delete_my_account') as the user (auth.uid()-scoped purge).
//   3. auth.admin.deleteUser(userId) via service role.

import { createClient } from 'jsr:@supabase/supabase-js@2';
import { handlePreflight, jsonResponse } from '../_shared/cors.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

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

  // Client authed AS THE USER for the RPC (auth.uid() must resolve).
  const asUser = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: `Bearer ${jwt}` } },
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { data: userData, error: userErr } = await asUser.auth.getUser(jwt);
  if (userErr || !userData?.user) {
    return jsonResponse({ error: 'invalid token' }, 401);
  }
  const userId = userData.user.id;

  // 2. Purge personal data.
  const { error: rpcErr } = await asUser.rpc('delete_my_account');
  if (rpcErr) {
    return jsonResponse({ error: rpcErr.message }, 500);
  }

  // 3. Delete the auth user via service-role admin API.
  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { error: delErr } = await admin.auth.admin.deleteUser(userId);
  if (delErr) {
    return jsonResponse({ error: delErr.message }, 500);
  }

  return jsonResponse({ ok: true });
});
