# RLS & guard-trigger reasoning (integration-test spec)

Postgres cannot be executed in this build environment, so this file documents
the intended **failing-attempt** tests that the Flutter/pgTAP integration suite
must run against a real database. Each item states the attempt, the mechanism
that blocks it, and the expected outcome. File/line references are to
`../migrations/0002_rls.sql` and `../migrations/0003_functions.sql`.

Two enforcement layers combine:
1. **RLS policies** — decide which *rows* a role may see/write.
2. **Guard triggers** (`entries_guard_client_columns`, `profiles_guard_client_columns`)
   — decide which *columns* a non-service session may change on an UPDATE.
   RLS's `WITH CHECK` alone cannot express "column X may not change vs. its old
   value", so the triggers cover column-level immutability.

Service-role detection: `public.is_service_role()` returns true when
`auth.role() = 'service_role'` OR the `role` claim in `request.jwt.claims` is
`service_role` OR there is no request JWT at all (raw admin/psql). Only genuine
`authenticated`/`anon` PostgREST sessions are guarded.

## entries — the critical pooling guarantees

1. **Client cannot insert a pre-approved entry.**
   Attempt: authenticated INSERT with `is_shareable = true`.
   Blocked by: `entries_insert_own` WITH CHECK (`is_shareable = false`).
   Expect: INSERT rejected (RLS violation).

2. **Client cannot insert with a promoted status.**
   Attempt: INSERT `moderation_status = 'clean'`.
   Blocked by: `entries_insert_own` WITH CHECK (`moderation_status in ('private','pending')`).
   Expect: rejected.

3. **Client cannot flip is_shareable on UPDATE.**
   Attempt: own-row UPDATE setting `is_shareable = true`.
   Blocked by: `entries_guard_client_columns` -> RAISE `is_shareable is not client-updatable`.
   Expect: UPDATE errors.

4. **Client cannot promote moderation_status.**
   Attempt: own-row UPDATE `moderation_status = 'clean'` (or 'held_*').
   Blocked by: trigger RAISE (only `'removed'` is allowed for the client).
   Expect: errors. UPDATE to `'removed'` (soft delete) SUCCEEDS.

5. **Client cannot rewrite moderation_categories.**
   Attempt: own-row UPDATE `moderation_categories = '{"self-harm":0}'`.
   Blocked by: trigger RAISE.
   Expect: errors.

6. **Client cannot read the pool directly.**
   Attempt: authenticated SELECT on entries authored by someone else that were
   never served to me.
   Blocked by: `entries_select_own_or_served` USING (own OR served-to-me).
   Expect: zero rows.

7. **Client can read an entry served to them** (positive control).
   After `serve_entry()` inserts a matches row for me, SELECT of that entry
   returns 1 row via the `exists(matches ...)` branch.

8. **Service role (moderate-and-pool) CAN set is_shareable/status/categories.**
   Positive control: `is_service_role()` short-circuits the trigger; RLS is
   bypassed by the service role. The gate update succeeds.

## profiles

9. **Client cannot self-suspend/unsuspend or edit strikes.**
   Attempt: own-row UPDATE `suspended = false` or `report_strikes = 0`.
   Blocked by: `profiles_guard_client_columns` RAISE.
   Expect: errors. Editing `age_confirmed`/`tos_*` on own row SUCCEEDS.

10. **Client cannot read/update another user's profile.**
    Blocked by: `profiles_select_own` / `profiles_update_own` (`id = auth.uid()`).
    Expect: zero rows / no-op.

## matches

11. **Client cannot INSERT a match** (fabricate a "served to me" grant to read
    the pool). No insert policy exists on matches -> denied for authenticated.
    Only `serve_entry` (SECURITY DEFINER) inserts. Expect: INSERT rejected.

12. **Client cannot see another reader's matches.**
    `matches_select_own` (`reader_id = auth.uid()`). Expect: zero rows.

## reports / blocks

13. **Client can insert a report as themselves only** (`reporter_id = auth.uid()`);
    inserting with someone else's reporter_id is rejected by `reports_insert_own`.
14. **Client sees only their own reports** (`reports_select_own`).
15. **Blocks: full CRUD limited to `blocker_id = auth.uid()`**; cannot create or
    read a block owned by another user.

## moderation_log

16. **Client has zero access.** RLS enabled with NO policies -> every
    authenticated/anon SELECT/INSERT/UPDATE/DELETE is denied. Service role
    bypasses RLS and writes freely (used by moderate-and-pool).

## functions (SECURITY DEFINER)

17. `serve_entry()` only returns entries with `is_shareable=true`,
    `moderation_status='clean'`, author not me, not already matched, author not
    blocked by me, author not suspended — asserted by seeding rows that violate
    each predicate and confirming they are never served.
18. `apply_report()` sets the entry `is_shareable=false`,
    `moderation_status='removed'` and deletes the caller's match.
19. `resolve_report(uphold=true)` increments `report_strikes`; the 3rd upheld
    report (`UPHELD_REPORTS_TO_SUSPEND=3`) sets `suspended=true`.
20. `delete_my_account()` removes the caller's entries, reader-matches, reports,
    blocks (by/of me), and profile row.
