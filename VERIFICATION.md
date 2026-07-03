# Verification record

What was actually executed in the build environment, and the results. This is a
record of real runs, not a claim of intent.

## ✅ Ran and passed

| Suite | Command | Result |
|---|---|---|
| Flutter static analysis | `flutter analyze` | **No issues found** (0 errors/warnings/lints) |
| Flutter unit + widget tests | `flutter test` | **26 passed**, 0 failed |
| Moderation gate + PII (pure logic) | `node --test 'tests/**/*.test.ts'` (in `supabase/`) | **30 passed**, 0 failed |
| RLS + gate security tests (real Postgres) | `supabase/tests/pg_harness/run.sh` | **19 assertions passed**, exit 0 |
| Dependency resolution | `flutter pub get` | resolved 103 deps, compatible |

Toolchain used: Flutter 3.44.4 / Dart 3.12.2, Node v22.22, PostgreSQL 16.13.

### What the Postgres harness proves (against the *actual* migrations)
It boots a throwaway cluster, stubs the Supabase `auth` schema + `anon` /
`authenticated` / `service_role` roles with the same privilege posture Supabase
uses, applies `0001`→`0002`→`0003`, then asserts:

- A client **cannot** set `is_shareable=true` or `moderation_status='clean'` on
  its own entry (guard trigger blocks it).
- A client **cannot** insert an entry pre-marked `is_shareable=true` or
  `moderation_status='clean'` (RLS `WITH CHECK`).
- A client **cannot** read the pool directly (only its own + entries served to
  it via `matches`).
- A client **cannot** read `moderation_log`, forge a `matches` row, or flip its
  own `profiles.suspended`.
- `serve_entry()` serves exactly one *clean, pooled, non-own, non-blocked,
  non-suspended* entry, records the match, and never re-serves it.
- `held_selfharm` and `rejected` entries are **never** served or visible to
  another user.
- `apply_report()` performs its optimistic takedown from a client context
  (verifies the `SECURITY DEFINER` guard-bypass fix).
- `block` and author `suspended` both stop serving.
- `delete_my_account()` purges the caller's entries and profile.

Re-run any time:
```bash
# Flutter
flutter analyze && flutter test
# Moderation/PII pure-logic tests
cd supabase && node --test 'tests/**/*.test.ts'
# RLS/gate tests against a real Postgres (needs a local postgresql install)
cd supabase/tests/pg_harness && ./run.sh   # run as a non-root user
```

## ⚠️ Could NOT run in this environment (org egress policy) — verified by inspection instead

| Item | Why blocked | Mitigation |
|---|---|---|
| `flutter build appbundle` (AAB) | Android SDK + Google Maven (`dl.google.com`) return HTTP 403 through the egress proxy; the SDK cannot be installed here | Gradle config written to Flutter 3.44 / AGP 8.7 / Gradle 8.9 standards: `compileSdk`/`targetSdk = 36`, `minSdk = 26`, AAB + Play App Signing wired. Build steps in `docs/deployment.md`. Runs on a machine with the Android SDK + network. |
| `deno check` on edge functions | `deno.land` returns HTTP 403 through the egress proxy | The security-critical logic (`_shared/moderation.ts`, `_shared/pii.ts`) is **pure** and covered by the 30 Node tests. Function wiring (JWT verify, service-role client, OpenAI call, response shape) verified by inspection and matches `CONTRACTS.md §4`. |
| Live OpenAI moderation call | Requires a real `OPENAI_API_KEY` (server-side only) | Decision matrix tested exhaustively offline with fixture `ModerationResult`s. |

These two are environment limits, not defects in the deliverable.

## Known before-launch TODOs (documented, not code bugs)
- Verify SG crisis numbers/hours against sos.org.sg and mindline.sg
  (`docs/crisis-resources.md`).
- Replace the placeholder launcher icon with exported mipmap PNGs.
- Legal templates (`LEGAL/`) need counsel review before store submission.
- Fill real values for all `--dart-define` keys and set edge-function secrets.
