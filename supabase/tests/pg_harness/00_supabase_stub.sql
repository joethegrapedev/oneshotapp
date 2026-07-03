-- Minimal Supabase-compatible stub so the real migrations run on a vanilla
-- Postgres cluster: the auth schema, auth.users, auth.uid()/auth.role(), and the
-- anon/authenticated/service_role roles with the same privilege posture Supabase
-- uses (service_role BYPASSRLS; PostgREST switches into authenticated/anon).

create extension if not exists pgcrypto;

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin noinherit bypassrls;
  end if;
end $$;

create schema if not exists auth;

create table if not exists auth.users (
  id uuid primary key default gen_random_uuid(),
  email text,
  created_at timestamptz default now()
);

-- auth.uid()/auth.role() read the request JWT claims GUC, exactly like Supabase.
create or replace function auth.uid()
returns uuid
language sql
stable
as $$
  select nullif(
    current_setting('request.jwt.claims', true)::jsonb ->> 'sub', ''
  )::uuid
$$;

create or replace function auth.role()
returns text
language sql
stable
as $$
  select current_setting('request.jwt.claims', true)::jsonb ->> 'role'
$$;

-- Let the client roles resolve auth helpers and the public objects.
grant usage on schema auth to anon, authenticated, service_role;
grant usage on schema public to anon, authenticated, service_role;
grant all on all tables in schema public to service_role;
grant execute on all functions in schema public to service_role;
alter default privileges in schema public
  grant all on tables to service_role;

-- Test helper: assert that a statement is REJECTED (RLS/trigger/permission).
-- SECURITY INVOKER (default) so EXECUTE runs as whatever role called it.
create or replace function public._expect_error(p_sql text, p_label text)
returns void
language plpgsql
as $$
begin
  execute p_sql;
  raise exception 'SECURITY FAIL [%]: statement unexpectedly SUCCEEDED: %',
    p_label, p_sql;
exception
  when raise_exception then
    -- Re-raise our own assertion failure.
    if sqlerrm like 'SECURITY FAIL%' then raise; end if;
    raise notice 'PASS [blocked as expected] %', p_label;
  when others then
    raise notice 'PASS [blocked as expected] %: %', p_label, sqlerrm;
end;
$$;

grant execute on function public._expect_error(text, text)
  to anon, authenticated, service_role;

-- Test helper: assert a `select count(*) ...` returns the expected number under
-- the CURRENT role (so RLS visibility is exercised). SECURITY INVOKER.
create or replace function public._expect_count(
  p_sql text, p_expected bigint, p_label text
)
returns void
language plpgsql
as $$
declare
  n bigint;
begin
  execute p_sql into n;
  if n is distinct from p_expected then
    raise exception 'ASSERT FAIL [%]: got %, want %', p_label, n, p_expected;
  end if;
  raise notice 'PASS [count=%] %', n, p_label;
end;
$$;

grant execute on function public._expect_count(text, bigint, text)
  to anon, authenticated, service_role;

