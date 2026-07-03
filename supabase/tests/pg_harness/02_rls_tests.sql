-- Real RLS + gate failing-attempt tests (CONTRACTS §2, acceptance criteria).
-- Run with ON_ERROR_STOP=on: any assertion failure aborts with a nonzero exit.
-- Roles: we SET ROLE + set request.jwt.claims to impersonate each client.

\set ON_ERROR_STOP on
\set u1 '11111111-1111-1111-1111-111111111111'
\set u2 '22222222-2222-2222-2222-222222222222'
\set e_priv   'a0000000-0000-0000-0000-000000000001'
\set e_share  'b0000000-0000-0000-0000-000000000002'
\set e_harm   'c0000000-0000-0000-0000-000000000003'
\set e_bad    'd0000000-0000-0000-0000-000000000004'

-- ===========================================================================
-- Setup as superuser: create two auth users (trigger auto-creates profiles).
-- ===========================================================================
insert into auth.users (id, email) values
  (:'u1', 'u1@example.com'),
  (:'u2', 'u2@example.com');

select public._expect_count(
  'select count(*) from public.profiles', 2,
  'handle_new_user created a profile per auth user');

-- ===========================================================================
-- As u2 (authenticated): author entries. Client can only insert non-poolable.
-- ===========================================================================
set role authenticated;
select set_config('request.jwt.claims',
  json_build_object('sub', :'u2', 'role', 'authenticated')::text, false);

insert into public.entries (id, author_id, body, visibility, moderation_status)
values (:'e_share', :'u2', 'a gentle hopeful note', 'shared', 'pending');
insert into public.entries (id, author_id, body, visibility, moderation_status)
values (:'e_harm', :'u2', 'a held entry', 'shared', 'pending');
insert into public.entries (id, author_id, body, visibility, moderation_status)
values (:'e_bad', :'u2', 'a rejected entry', 'shared', 'pending');

reset role;

-- ===========================================================================
-- As service_role (edge function): run the gate outcomes.
--   e_share -> clean + shareable ; e_harm -> held_selfharm ; e_bad -> rejected.
-- Exercises the guard's service-role bypass.
-- ===========================================================================
set role service_role;
update public.entries
  set moderation_status = 'clean', is_shareable = true, moderated_at = now()
  where id = :'e_share';
update public.entries
  set moderation_status = 'held_selfharm', is_shareable = false
  where id = :'e_harm';
update public.entries
  set moderation_status = 'rejected', is_shareable = false
  where id = :'e_bad';
insert into public.moderation_log (entry_id, provider, result, action)
  values (:'e_share', 'openai:omni-moderation-latest', '{"flagged":false}', 'clean');
reset role;

-- ===========================================================================
-- As u1 (authenticated): the security invariants.
-- ===========================================================================
set role authenticated;
select set_config('request.jwt.claims',
  json_build_object('sub', :'u1', 'role', 'authenticated')::text, false);

-- u1 authors a private entry (allowed).
insert into public.entries (id, author_id, body, visibility, moderation_status)
values (:'e_priv', :'u1', 'my private thoughts', 'private', 'private');

-- (1) Client CANNOT promote own entry to the pool (guard trigger).
select public._expect_error(
  format('update public.entries set is_shareable = true where id = %L', :'e_priv'),
  'client cannot set is_shareable=true on own entry');

-- (2) Client CANNOT set own moderation_status to a gate outcome (only removed).
select public._expect_error(
  format('update public.entries set moderation_status = ''clean'' where id = %L', :'e_priv'),
  'client cannot set moderation_status=clean');

-- (3) Client CANNOT insert an entry pre-marked shareable (RLS WITH CHECK).
select public._expect_error(
  format('insert into public.entries (author_id, body, visibility, moderation_status, is_shareable) values (%L, ''x'', ''shared'', ''pending'', true)', :'u1'),
  'client cannot insert is_shareable=true');

-- (4) Client CANNOT insert an entry pre-marked clean (RLS WITH CHECK).
select public._expect_error(
  format('insert into public.entries (author_id, body, visibility, moderation_status) values (%L, ''x'', ''shared'', ''clean'')', :'u1'),
  'client cannot insert moderation_status=clean');

-- (5) Client CANNOT read the pool directly: u2's clean pooled entry is invisible
--     until served. u1 sees only its own 1 entry.
select public._expect_count(
  'select count(*) from public.entries', 1,
  'u1 sees only its own entries, never the pool');
select public._expect_count(
  format('select count(*) from public.entries where id = %L', :'e_share'), 0,
  'u1 cannot directly read a pooled entry');

-- (6) Client CANNOT read moderation_log (service-role only -> 0 rows).
select public._expect_count(
  'select count(*) from public.moderation_log', 0,
  'client cannot read moderation_log');

-- (7) Client CANNOT flip its own profile.suspended (guard trigger).
select public._expect_error(
  format('update public.profiles set suspended = true where id = %L', :'u1'),
  'client cannot self-unsuspend/suspend');

-- (8) Client CANNOT insert a matches row directly (no client insert policy).
select public._expect_error(
  format('insert into public.matches (reader_id, entry_id) values (%L, %L)', :'u1', :'e_share'),
  'client cannot forge a matches row');

-- (9) serve_entry() returns the ONE clean pooled entry (never held/rejected),
--     records a match, and is then not served again.
select public._expect_count(
  'select count(*) from public.serve_entry()', 1,
  'serve_entry returns one eligible entry');
select public._expect_count(
  'select count(*) from public.serve_entry()', 0,
  'serve_entry does not re-serve an already-matched entry');

-- (10) After being served, u1 CAN read that entry (via matches) — and still
--      cannot see the held/rejected ones.
select public._expect_count(
  format('select count(*) from public.entries where id = %L', :'e_share'), 1,
  'u1 can read the entry served to it');
select public._expect_count(
  format('select count(*) from public.entries where id in (%L, %L)', :'e_harm', :'e_bad'), 0,
  'held_selfharm and rejected entries are never visible to u1');

-- (11) apply_report(): optimistic takedown WORKS from a client (this is the
--      guard-bypass fix — a definer function may change is_shareable).
select public.apply_report(:'e_share', 'harmful');
reset role;
set role service_role;
select public._expect_count(
  format('select count(*) from public.entries where id = %L and is_shareable = false and moderation_status = ''removed''', :'e_share'), 1,
  'apply_report pulled the entry from the pool');
reset role;

-- (12) Block: u1 blocks u2, so even a fresh clean entry from u2 is never served.
set role service_role;
insert into public.entries (author_id, body, visibility, moderation_status, is_shareable)
  values (:'u2', 'another clean note', 'shared', 'clean', true);
reset role;
set role authenticated;
select set_config('request.jwt.claims',
  json_build_object('sub', :'u1', 'role', 'authenticated')::text, false);
insert into public.blocks (blocker_id, blocked_id) values (:'u1', :'u2');
select public._expect_count(
  'select count(*) from public.serve_entry()', 0,
  'serve_entry never serves a blocked author');
reset role;

-- (13) Suspended author: their clean entries stop being served.
set role service_role;
update public.profiles set suspended = true where id = :'u2';
-- Give u1 a fresh, unblocked author path is out of scope here; just assert the
-- suspended filter by removing the block and checking again.
reset role;
set role authenticated;
select set_config('request.jwt.claims',
  json_build_object('sub', :'u1', 'role', 'authenticated')::text, false);
delete from public.blocks where blocker_id = :'u1' and blocked_id = :'u2';
select public._expect_count(
  'select count(*) from public.serve_entry()', 0,
  'serve_entry never serves a suspended author');
reset role;

-- (14) delete_my_account(): purges the caller's data.
set role authenticated;
select set_config('request.jwt.claims',
  json_build_object('sub', :'u2', 'role', 'authenticated')::text, false);
select public.delete_my_account();
reset role;
set role service_role;
select public._expect_count(
  format('select count(*) from public.entries where author_id = %L', :'u2'), 0,
  'delete_my_account purged the caller''s entries');
select public._expect_count(
  format('select count(*) from public.profiles where id = %L', :'u2'), 0,
  'delete_my_account purged the caller''s profile');
reset role;

\echo '============================================'
\echo 'ALL RLS / GATE SECURITY TESTS PASSED'
\echo '============================================'
