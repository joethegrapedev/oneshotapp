-- 0002_rls.sql — Row Level Security + client-column guard triggers per CONTRACTS §2.
--
-- Service-role detection
-- ----------------------
-- The service_role key bypasses RLS, but BEFORE-UPDATE triggers STILL fire for
-- it, so the column guards must let the service role through. We detect it from
-- the JWT claims. The reliable signal is the `role` claim on the request JWT:
--   current_setting('request.jwt.claims', true)::jsonb ->> 'role'
-- We also accept auth.role() (Supabase helper reading the same claim) as a
-- fallback. We treat "no JWT claims at all" (e.g. a raw psql superuser session
-- running migrations/maintenance) as privileged too, so admin scripts are not
-- blocked. Only genuine authenticated/anon PostgREST sessions carry a non-service
-- role claim and are therefore guarded.

create or replace function public.is_service_role()
returns boolean
language plpgsql
stable
as $$
declare
  claims text;
  claim_role text;
begin
  -- auth.role() is the canonical Supabase helper; use it first.
  begin
    if auth.role() = 'service_role' then
      return true;
    end if;
  exception when others then
    -- auth schema/helper unavailable (e.g. plain psql) — fall through.
    null;
  end;

  claims := current_setting('request.jwt.claims', true);
  if claims is null or claims = '' then
    -- No request JWT (superuser/admin/migration session) => privileged.
    return true;
  end if;

  claim_role := (claims::jsonb) ->> 'role';
  return claim_role = 'service_role';
end;
$$;

-- ===========================================================================
-- Enable RLS on ALL tables.
-- ===========================================================================
alter table public.profiles       enable row level security;
alter table public.entries        enable row level security;
alter table public.matches        enable row level security;
alter table public.reports        enable row level security;
alter table public.blocks         enable row level security;
alter table public.moderation_log enable row level security;

-- ===========================================================================
-- profiles: select/update own row only. suspended/report_strikes guarded.
-- ===========================================================================
drop policy if exists profiles_select_own on public.profiles;
create policy profiles_select_own on public.profiles
  for select to authenticated
  using (id = auth.uid());

drop policy if exists profiles_insert_own on public.profiles;
create policy profiles_insert_own on public.profiles
  for insert to authenticated
  with check (id = auth.uid());

drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- Reject client changes to service-role-only columns.
create or replace function public.profiles_guard_client_columns()
returns trigger
language plpgsql
as $$
begin
  if public.is_service_role() then
    return new;  -- trusted server path may change anything.
  end if;
  if new.suspended is distinct from old.suspended then
    raise exception 'profiles.suspended is not client-updatable';
  end if;
  if new.report_strikes is distinct from old.report_strikes then
    raise exception 'profiles.report_strikes is not client-updatable';
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_guard_client_columns on public.profiles;
create trigger profiles_guard_client_columns
  before update on public.profiles
  for each row execute function public.profiles_guard_client_columns();

-- ===========================================================================
-- entries
-- ===========================================================================
-- SELECT: own rows OR rows served to me via matches. No direct pool read.
drop policy if exists entries_select_own_or_served on public.entries;
create policy entries_select_own_or_served on public.entries
  for select to authenticated
  using (
    author_id = auth.uid()
    or exists (
      select 1 from public.matches m
      where m.entry_id = entries.id
        and m.reader_id = auth.uid()
    )
  );

-- INSERT: only own, never shareable, only private/pending status.
drop policy if exists entries_insert_own on public.entries;
create policy entries_insert_own on public.entries
  for insert to authenticated
  with check (
    author_id = auth.uid()
    and is_shareable = false
    and moderation_status in ('private', 'pending')
  );

-- UPDATE: own rows only. Column-level restrictions in the guard trigger below.
drop policy if exists entries_update_own on public.entries;
create policy entries_update_own on public.entries
  for update to authenticated
  using (author_id = auth.uid())
  with check (author_id = auth.uid());

-- DELETE: own rows only.
drop policy if exists entries_delete_own on public.entries;
create policy entries_delete_own on public.entries
  for delete to authenticated
  using (author_id = auth.uid());

-- Guard: a NON-service-role session may not change is_shareable,
-- moderation_status (except transitioning to 'removed' for soft delete), or
-- moderation_categories. The service role (gate) may change all of them.
create or replace function public.entries_guard_client_columns()
returns trigger
language plpgsql
as $$
begin
  if public.is_service_role() then
    return new;  -- trusted server / SECURITY DEFINER path.
  end if;

  if new.is_shareable is distinct from old.is_shareable then
    raise exception 'entries.is_shareable is not client-updatable';
  end if;

  if new.moderation_status is distinct from old.moderation_status
     and new.moderation_status <> 'removed' then
    raise exception
      'entries.moderation_status may only be changed by the moderation gate (client may only set ''removed'')';
  end if;

  if new.moderation_categories is distinct from old.moderation_categories then
    raise exception 'entries.moderation_categories is not client-updatable';
  end if;

  return new;
end;
$$;

drop trigger if exists entries_guard_client_columns on public.entries;
create trigger entries_guard_client_columns
  before update on public.entries
  for each row execute function public.entries_guard_client_columns();

-- ===========================================================================
-- matches: select own only. NO client insert/update/delete
-- (only the serve_entry SECURITY DEFINER function writes rows).
-- ===========================================================================
drop policy if exists matches_select_own on public.matches;
create policy matches_select_own on public.matches
  for select to authenticated
  using (reader_id = auth.uid());
-- (Intentionally no insert/update/delete policies => denied for clients.)

-- ===========================================================================
-- reports: insert own, select own.
-- ===========================================================================
drop policy if exists reports_insert_own on public.reports;
create policy reports_insert_own on public.reports
  for insert to authenticated
  with check (reporter_id = auth.uid());

drop policy if exists reports_select_own on public.reports;
create policy reports_select_own on public.reports
  for select to authenticated
  using (reporter_id = auth.uid());

-- ===========================================================================
-- blocks: full CRUD on own rows.
-- ===========================================================================
drop policy if exists blocks_select_own on public.blocks;
create policy blocks_select_own on public.blocks
  for select to authenticated
  using (blocker_id = auth.uid());

drop policy if exists blocks_insert_own on public.blocks;
create policy blocks_insert_own on public.blocks
  for insert to authenticated
  with check (blocker_id = auth.uid());

drop policy if exists blocks_update_own on public.blocks;
create policy blocks_update_own on public.blocks
  for update to authenticated
  using (blocker_id = auth.uid())
  with check (blocker_id = auth.uid());

drop policy if exists blocks_delete_own on public.blocks;
create policy blocks_delete_own on public.blocks
  for delete to authenticated
  using (blocker_id = auth.uid());

-- ===========================================================================
-- moderation_log: NO policies for authenticated/anon. RLS is enabled, so with
-- zero policies every non-service request is denied. Service role bypasses RLS.
-- ===========================================================================
-- (deliberately empty)
