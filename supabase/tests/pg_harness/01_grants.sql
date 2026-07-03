-- Mirror Supabase's platform-level default grants: DML is granted to
-- anon/authenticated on public tables, and RLS (not the grant) does the gating.
-- Run AFTER the migrations so all tables exist.
grant select, insert, update, delete
  on all tables in schema public to anon, authenticated;
grant usage, select on all sequences in schema public to anon, authenticated;
