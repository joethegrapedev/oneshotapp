# One Shot

An anonymous private journaling app with an **opt-in, server-moderated
exchange**. Write privately; when you choose to *share* an entry it passes a
server-side moderation gate, and in return you're shown **one** stranger's
already-cleared entry — anonymously. No usernames, profiles, DMs, or replies.

- **Launch:** Singapore, **18+**, Android first (Flutter; iOS later from the same
  codebase).
- **applicationId:** `com.oneshot.journal` · **package:** `oneshot_journal`
- **Stack:** Flutter 3.24+ / Dart 3, Supabase (Postgres + Auth + Edge Functions),
  RevenueCat (subscriptions), OpenAI moderation (server-side only).

> The single source of truth for names/shapes/rules is **[`CONTRACTS.md`](./CONTRACTS.md)**.

---

## Architecture in brief

```
Flutter app (lib/)  ──HTTPS──▶  Supabase (Postgres + RLS + SECURITY DEFINER fns)
      │                               │
      │  share entry                  ├─ Edge fn: moderate-and-pool ─▶ OpenAI moderation
      │  (moderate-and-pool)          ├─ Edge fn: serve-entry  (rpc serve_entry)
      │                               └─ Edge fn: delete-account (rpc + admin delete)
      └─ optional on-device pre-check (advisory only; ML Kit GenAI / Gemini Nano)
```

See **[`ARCHITECTURE.md`](./ARCHITECTURE.md)** for data flow, the moderation
decision matrix, the RLS model, and the module map.

---

## Security model (read this)

The moderation gate is **authoritative and server-side**. The client cannot
promote its own content into the shared pool:

- **Clients can never set `is_shareable`** or change `moderation_status` /
  `moderation_categories` — RLS + triggers reject it. Promotion happens only via
  service-role / `SECURITY DEFINER` functions (CONTRACTS §2/§3).
- **No client reads the pool directly.** You can only select your own entries or
  entries served to you via the `serve_entry` function.
- The on-device pre-check is **advisory/UX only** — never a security boundary; it
  fails open toward the server (`docs/on_device_precheck.md`).
- **RLS** is enforced on every table (CONTRACTS §2); tests assert it.

## Secrets

- **The OpenAI API key lives ONLY in the Supabase Edge Function environment**
  (`supabase secrets set OPENAI_API_KEY=...`). It is **never** in the app.
- **Anon / public keys** (Supabase anon key, RevenueCat *public* SDK key) are
  passed at build time via `--dart-define` and read in
  [`lib/core/env.dart`](./lib/core/env.dart). These are safe to ship.
- Nothing secret is committed. Signing keys (`key.properties`, `*.jks`),
  `local.properties`, and `.env` are git-ignored.

---

## Configure & run

Config is injected via `--dart-define` (no secrets compiled in). Keys:
`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `REVENUECAT_ANDROID_KEY`,
`REVENUECAT_IOS_KEY`, `POSTHOG_KEY` (opt), `POSTHOG_HOST` (opt), `TOS_URL`,
`PRIVACY_URL`, `SUPPORT_EMAIL`, `TOS_VERSION`.

```bash
flutter pub get

flutter run \
  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJ... \
  --dart-define=REVENUECAT_ANDROID_KEY=goog_... \
  --dart-define=TOS_URL=https://oneshot.app/terms \
  --dart-define=PRIVACY_URL=https://oneshot.app/privacy \
  --dart-define=SUPPORT_EMAIL=support@oneshot.app \
  --dart-define=TOS_VERSION=2026-07-01
```

Tip: keep the defines in a git-ignored JSON and use
`--dart-define-from-file=dart_defines/prod.json`.

## Tests

```bash
flutter test                       # Flutter/Dart unit + widget tests
# Supabase backend tests (Node) — the pure moderation decision logic etc.:
cd supabase/tests && npm install && npm test
```

## Build the release App Bundle (AAB)

```bash
flutter build appbundle --release --dart-define=...   # (all keys above)
# Output: build/app/outputs/bundle/release/app-release.aab
```

Signing uses **Play App Signing**: put your **upload key** in
`android/key.properties` (see `android/key.properties.example`); Google manages
the app signing key. If `key.properties` is absent the build falls back to debug
signing so it still assembles (not accepted by Play). Full steps:
[`docs/deployment.md`](./docs/deployment.md).

- **compileSdk / targetSdk: 36 · minSdk: 26.**

---

## Documentation

- [`docs/deployment.md`](./docs/deployment.md) — end-to-end build & release.
- [`docs/data-safety.md`](./docs/data-safety.md) — Play Data Safety mapping.
- [`docs/content-rating.md`](./docs/content-rating.md) — IARC questionnaire.
- [`docs/crisis-resources.md`](./docs/crisis-resources.md) — SG crisis resources
  + **build-time verification checklist**.
- [`docs/on_device_precheck.md`](./docs/on_device_precheck.md) — ML Kit GenAI
  wiring (advisory, optional).
- [`docs/ios-followon.md`](./docs/ios-followon.md) — the iOS plan (later).
- [`LEGAL/`](./LEGAL/) — hostable Terms of Use & Privacy Policy (templates for
  counsel review). In-app copies live in `assets/legal/`.

## Repository layout

```
lib/            Flutter app (see ARCHITECTURE.md module map)
supabase/       migrations, edge functions, tests (backend)
android/        Android Gradle project (embedding v2, AGP 8.7 / Gradle 8.9)
assets/legal/   in-app Terms & Privacy copies (offline)
LEGAL/          canonical hostable Terms & Privacy
docs/           deployment + compliance docs
CONTRACTS.md    single source of truth
```
