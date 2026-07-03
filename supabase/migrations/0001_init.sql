-- 0001_init.sql — schema per CONTRACTS §1.
-- All tables in schema public. id uuid default gen_random_uuid().
-- gen_random_uuid() is built into modern Postgres (pgcrypto also provides it);
-- enable pgcrypto defensively so the default works on any supported version.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- profiles  (row keyed 1:1 to auth.users.id)
-- ---------------------------------------------------------------------------
create table if not exists public.profiles (
  id              uuid primary key references auth.users (id) on delete cascade,
  created_at      timestamptz not null default now(),
  age_confirmed   boolean     not null default false,
  tos_accepted_at timestamptz,
  tos_version     text,
  suspended       boolean     not null default false,   -- service-role only
  report_strikes  int         not null default 0        -- service-role only
);

-- ---------------------------------------------------------------------------
-- entries
-- ---------------------------------------------------------------------------
create table if not exists public.entries (
  id                    uuid primary key default gen_random_uuid(),
  author_id             uuid not null default auth.uid()
                          references public.profiles (id) on delete cascade,
  body                  text not null,
  created_at            timestamptz not null default now(),
  visibility            text not null default 'private'
                          check (visibility in ('private', 'shared')),
  moderation_status     text not null default 'private'
                          check (moderation_status in (
                            'private', 'pending', 'clean',
                            'held_selfharm', 'held_pii',
                            'rejected', 'rejected_objectionable', 'removed'
                          )),
  is_shareable          boolean not null default false,  -- service-role only
  moderation_categories jsonb   not null default '{}'::jsonb,
  moderated_at          timestamptz
);

-- Pool eligibility lookup (serve_entry filters is_shareable + moderation_status).
create index if not exists entries_shareable_status_idx
  on public.entries (is_shareable, moderation_status);
-- "my entries" lookups.
create index if not exists entries_author_idx
  on public.entries (author_id);

-- ---------------------------------------------------------------------------
-- matches  (which reader was shown which entry)
-- ---------------------------------------------------------------------------
create table if not exists public.matches (
  id        uuid primary key default gen_random_uuid(),
  reader_id uuid not null references public.profiles (id) on delete cascade,
  entry_id  uuid not null references public.entries (id)  on delete cascade,
  served_at timestamptz not null default now(),
  unique (reader_id, entry_id)
);

create index if not exists matches_reader_idx on public.matches (reader_id);
create index if not exists matches_entry_idx  on public.matches (entry_id);

-- ---------------------------------------------------------------------------
-- reports
-- ---------------------------------------------------------------------------
create table if not exists public.reports (
  id          uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles (id) on delete cascade,
  entry_id    uuid not null references public.entries (id)  on delete cascade,
  reason      text not null,
  status      text not null default 'open'
                check (status in ('open', 'upheld', 'dismissed')),
  created_at  timestamptz not null default now(),
  resolved_at timestamptz
);

create index if not exists reports_reporter_idx on public.reports (reporter_id);
create index if not exists reports_entry_idx    on public.reports (entry_id);

-- ---------------------------------------------------------------------------
-- blocks
-- ---------------------------------------------------------------------------
create table if not exists public.blocks (
  blocker_id uuid not null references public.profiles (id) on delete cascade,
  blocked_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id)
);

create index if not exists blocks_blocker_idx on public.blocks (blocker_id);

-- ---------------------------------------------------------------------------
-- moderation_log  (service-role only; no client access)
-- ---------------------------------------------------------------------------
create table if not exists public.moderation_log (
  id         uuid primary key default gen_random_uuid(),
  entry_id   uuid references public.entries (id) on delete set null,
  provider   text not null,
  result     jsonb not null default '{}'::jsonb,
  action     text not null,
  created_at timestamptz not null default now()
);

create index if not exists moderation_log_entry_idx on public.moderation_log (entry_id);
