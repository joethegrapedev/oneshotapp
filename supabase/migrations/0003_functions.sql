-- 0003_functions.sql — SQL functions per CONTRACTS §3.
-- All SECURITY DEFINER with `set search_path = public` so they run with the
-- owner's privileges (bypassing RLS) but resolve only trusted objects.

-- Config constant (CONTRACTS §1): UPHELD_REPORTS_TO_SUSPEND = 3.

-- ---------------------------------------------------------------------------
-- serve_entry() — return one random eligible pool entry and record the match.
-- Eligible: is_shareable=true, moderation_status='clean', author<>me,
-- not already matched to me, author not blocked by me, author not suspended.
-- Returns the shaped row (id, body, created_at, author_id) or no rows.
-- ---------------------------------------------------------------------------
create or replace function public.serve_entry()
returns table (
  id         uuid,
  body       text,
  created_at timestamptz,
  author_id  uuid
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid   uuid := auth.uid();
  v_entry public.entries%rowtype;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  select e.* into v_entry
  from public.entries e
  join public.profiles p on p.id = e.author_id
  where e.is_shareable = true
    and e.moderation_status = 'clean'
    and e.author_id <> v_uid
    and p.suspended = false
    and not exists (
      select 1 from public.matches m
      where m.reader_id = v_uid and m.entry_id = e.id
    )
    and not exists (
      select 1 from public.blocks b
      where b.blocker_id = v_uid and b.blocked_id = e.author_id
    )
  order by random()
  limit 1;

  if not found then
    return;  -- empty pool for this user (cold start).
  end if;

  -- Record the match. ON CONFLICT guards a race on the UNIQUE(reader,entry).
  insert into public.matches (reader_id, entry_id)
  values (v_uid, v_entry.id)
  on conflict (reader_id, entry_id) do nothing;

  id         := v_entry.id;
  body       := v_entry.body;
  created_at := v_entry.created_at;
  author_id  := v_entry.author_id;
  return next;
end;
$$;

revoke all on function public.serve_entry() from public;
grant execute on function public.serve_entry() to authenticated;

-- ---------------------------------------------------------------------------
-- apply_report(p_entry_id, p_reason) — report + optimistic takedown.
-- ---------------------------------------------------------------------------
create or replace function public.apply_report(p_entry_id uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  insert into public.reports (reporter_id, entry_id, reason)
  values (v_uid, p_entry_id, coalesce(p_reason, ''));

  -- Optimistically pull the entry from the pool.
  update public.entries
  set is_shareable = false,
      moderation_status = 'removed'
  where id = p_entry_id;

  -- Remove my match so it stops appearing for me.
  delete from public.matches
  where reader_id = v_uid and entry_id = p_entry_id;
end;
$$;

revoke all on function public.apply_report(uuid, text) from public;
grant execute on function public.apply_report(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- resolve_report(p_report_id, p_uphold) — service-role review action.
-- Marks report; on uphold increments author strikes and suspends at >= 3.
-- NOT granted to authenticated (service role only).
-- ---------------------------------------------------------------------------
create or replace function public.resolve_report(p_report_id uuid, p_uphold boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_entry_id  uuid;
  v_author_id uuid;
  v_strikes   int;
  c_suspend_threshold constant int := 3;  -- UPHELD_REPORTS_TO_SUSPEND
begin
  -- Mark the report only if it is still open; capture its entry_id.
  update public.reports
  set status = case when p_uphold then 'upheld' else 'dismissed' end,
      resolved_at = now()
  where id = p_report_id
    and status = 'open'
  returning entry_id into v_entry_id;

  if v_entry_id is null then
    -- Already resolved or not found: nothing more to do.
    return;
  end if;

  if not p_uphold then
    return;
  end if;

  -- Resolve the author of the reported entry.
  select author_id into v_author_id
  from public.entries
  where id = v_entry_id;

  if v_author_id is null then
    return;  -- entry was hard-deleted.
  end if;

  update public.profiles
  set report_strikes = report_strikes + 1
  where id = v_author_id
  returning report_strikes into v_strikes;

  if v_strikes >= c_suspend_threshold then
    update public.profiles
    set suspended = true
    where id = v_author_id;
  end if;
end;
$$;

revoke all on function public.resolve_report(uuid, boolean) from public;
-- (no grant to authenticated — service role invokes this)

-- ---------------------------------------------------------------------------
-- delete_my_account() — purge caller's data. Auth user is deleted separately
-- by the delete-account edge function via the admin API.
-- ---------------------------------------------------------------------------
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  -- reports filed by me.
  delete from public.reports where reporter_id = v_uid;
  -- matches where I was the reader.
  delete from public.matches where reader_id = v_uid;
  -- blocks I created or that target me.
  delete from public.blocks where blocker_id = v_uid or blocked_id = v_uid;
  -- my entries (cascades to matches on those entries + reports on them).
  delete from public.entries where author_id = v_uid;
  -- my profile row (auth.users row deleted by the edge function).
  delete from public.profiles where id = v_uid;
end;
$$;

revoke all on function public.delete_my_account() from public;
grant execute on function public.delete_my_account() to authenticated;

-- ---------------------------------------------------------------------------
-- handle_new_user() — auto-create a profiles row on new auth user (robustness;
-- client ensureProfile() is still safe due to the ON CONFLICT no-op).
-- ---------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id)
  values (new.id)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
