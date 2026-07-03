# Supabase backend — anonymous journaling with a moderation gate

Backend for the app described in [`../CONTRACTS.md`](../CONTRACTS.md) — the single
source of truth for names/shapes/rules. This directory contains the database
schema, RLS, SQL functions, and edge functions.

```
supabase/
  config.toml                 CLI project config (project_id "oneshot")
  migrations/
    0001_init.sql             tables, indexes, constraints (§1)
    0002_rls.sql              RLS policies + client-column guard triggers (§2)
    0003_functions.sql        SECURITY DEFINER functions + new-user trigger (§3)
  functions/
    _shared/cors.ts           CORS + JSON helpers
    _shared/moderation.ts     PURE decide() decision logic (§5) — unit tested
    _shared/pii.ts            PURE detectPii() — unit tested
    moderate-and-pool/        the moderation gate (§4)
    serve-entry/              rpc('serve_entry') wrapper (§4)
    delete-account/          purge + auth-user delete (§4)
    package.json              { "type": "module" }
  tests/
    moderation.test.ts        node:test unit tests for decide()
    pii.test.ts               node:test unit tests for detectPii()
    rls_notes.md              intended failing-attempt RLS tests (run in DB)
    RESULTS.txt               captured passing test output
```

## Prerequisites

- Supabase CLI (`supabase`) and Docker for local dev.
- Node 22+ for the pure-logic unit tests (used here: v22.22).

## Run migrations

Local:

```bash
supabase start
supabase db reset          # applies migrations/*.sql in filename order
```

Remote (linked project):

```bash
supabase link --project-ref <your-ref>
supabase db push
```

Migrations run in filename order: `0001` (schema) → `0002` (RLS) → `0003`
(functions). They are written idempotent-ish (`create ... if not exists`,
`create or replace`, `drop policy if exists`) so re-runs are safe.

## Set function secrets

The OpenAI key lives ONLY in the edge-function environment — never in the app.

```bash
supabase secrets set OPENAI_API_KEY=sk-...
# SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY are injected
# automatically by the platform for deployed functions. For `supabase functions
# serve` locally, provide them via --env-file:
#   supabase functions serve --env-file ./functions/.env
```

Edge functions read: `SUPABASE_URL`, `SUPABASE_ANON_KEY`,
`SUPABASE_SERVICE_ROLE_KEY`, `OPENAI_API_KEY`.

## Deploy functions

All three verify the caller JWT (`verify_jwt = true` in `config.toml`) and
re-verify the user via `supabase.auth.getUser(jwt)` internally.

```bash
supabase functions deploy moderate-and-pool
supabase functions deploy serve-entry
supabase functions deploy delete-account
```

## Run the unit tests

The `_shared/moderation.ts` and `_shared/pii.ts` modules are pure TypeScript
(no Deno/URL imports) so Node's type-stripping runs them directly.

```bash
cd supabase
node --test 'tests/**/*.test.ts'
# (node v22.22 strips types by default; on older 22.x add --experimental-strip-types)
```

Latest run: **30 passing, 0 failing** — see [`tests/RESULTS.txt`](tests/RESULTS.txt).

### Adversarial-testing note

`tests/moderation.test.ts` is intentionally adversarial. It asserts the safety
invariants that must never regress:

- **Self-harm precedence** — self-harm routes to `held_selfharm` (never poolable,
  always crisis) *even when* objectionable categories also trip.
- **sexual/minors** is a hard `rejected` regardless of any other signal.
- **Fail closed** — borderline scores just below threshold stay `clean`, but the
  gate itself (`moderate-and-pool`) never pools an entry when OpenAI errors or is
  unreachable; it sets `pending`/held instead (see `moderate-and-pool/index.ts`).
- **PII** present but otherwise clean → `held_pii`, not shareable.

Database-level guarantees (client can never set `is_shareable` or promote
`moderation_status`) can't be exercised without Postgres here; the intended
failing-attempt tests are specified in [`tests/rls_notes.md`](tests/rls_notes.md)
for the Flutter/pgTAP integration suite, and proven inline via SQL comments in
`migrations/0002_rls.sql`.

## Crisis resources

`moderate-and-pool` returns Singapore crisis resources in the `crisis` payload
only when `status == held_selfharm` (CONTRACTS §9). These are placeholders marked
`"verify at build time"` and MUST be verified against SOS/mindline before store
submission.
