# Architecture — One Shot

Deeper companion to `README.md`. Authoritative names/shapes/rules are in
`CONTRACTS.md`; this document explains how the pieces fit and why the security
model holds.

---

## 1. Components

- **Flutter app** (`lib/`) — UI, state (Riverpod), routing (GoRouter),
  repositories that call Supabase. Holds **no secrets** and **no authority** over
  moderation.
- **Supabase Postgres** — tables + **RLS** + `SECURITY DEFINER` functions
  (CONTRACTS §1–§3). The database is where the security invariants live.
- **Supabase Edge Functions** (Deno) — `moderate-and-pool`, `serve-entry`,
  `delete-account` (CONTRACTS §4). Only the server holds the OpenAI key.
- **OpenAI moderation** — called only from `moderate-and-pool`.
- **RevenueCat + Google Play** — subscription entitlement `pro` (hard paywall).
- **Optional on-device pre-check** — advisory-only warning (ML Kit GenAI).

---

## 2. Data flow: write → gate → pool → serve

```
        WRITE (private by default)
  user ─▶ EntriesRepository.saveDraft(body, private)
        └▶ INSERT entries (author_id=auth.uid(), is_shareable=false,
                           moderation_status in {private,pending})     [RLS insert]

        SHARE (opt-in) → GATE
  user taps "share" ─▶ ModerationRepository.submitForSharing(entryId)
        └▶ Edge fn moderate-and-pool (JWT verified; loads entry as service role;
             confirms caller == author)
             ├─ OpenAI moderation  ─┐
             ├─ PII regex check   ──┤
             │                      ▼
             │             decide(m, pii)  (pure, _shared/moderation.ts)
             ▼
           UPDATE entries.moderation_status / is_shareable / categories  ← SERVICE ROLE ONLY
           INSERT moderation_log
           returns {status, is_shareable, categories, message, crisis?}

        POOL → SERVE (reciprocity)
  user ─▶ PoolRepository.serveOne()  ─▶ rpc serve_entry()   [SECURITY DEFINER]
        └▶ picks a random entry: is_shareable=true, moderation_status='clean',
             author<>me, not already matched to me, author not blocked by me,
             author not suspended; INSERTs matches(reader=me, entry); returns it.
        (empty pool → null / cold start)

        SAFETY
  report ─▶ rpc apply_report(entry, reason): INSERT reports(reporter=me);
             optimistically is_shareable=false, moderation_status='removed';
             delete my matches row for it.
  block  ─▶ INSERT blocks(blocker=me, blocked=author) → never served again.
  resolve_report (service role): upheld → author.report_strikes++;
             strikes >= UPHELD_REPORTS_TO_SUSPEND(3) → author.suspended=true.
```

---

## 3. Moderation decision matrix (summary)

Pure function `decide(m, pii)` in `supabase/functions/_shared/moderation.ts`.
**Order matters — first match wins.** A category "trips" if flagged **or** its
score ≥ threshold.

| # | Condition | Decision | isShareable |
|---|---|---|---|
| 1 | `sexual/minors` (score ≥ 0.2) | `rejected` (hard) | false |
| 2 | any `self-harm*` (score ≥ 0.5) | `held_selfharm` → crisis payload | false |
| 3 | any of `sexual`, `violence/graphic`, `harassment*`, `hate*`, `illicit*` (score ≥ 0.5) | `rejected_objectionable` | false |
| 4 | `pii.hasPii` | `held_pii` | false |
| 5 | otherwise | `clean` | **true** |

Self-harm is checked **before** generic objectionable so distressed users are
always routed to crisis resources, never to a plain rejection. Thresholds
(`SEXUAL_MINORS_THRESHOLD`, `SELF_HARM_THRESHOLD`, `OBJECTIONABLE_THRESHOLD`) are
named constants — the single place to tune.

---

## 4. RLS / security model (why the client can't cheat)

The client is **untrusted**. Authority lives in Postgres:

- **entries.insert** — allowed only with `author_id = auth.uid()`,
  `is_shareable = false`, `moderation_status ∈ {private, pending}`. A client
  literally cannot insert a shareable entry.
- **entries.update** — own rows only, and a trigger **rejects** any client change
  to `is_shareable`, `moderation_status`, or `moderation_categories`. Clients may
  edit `body`/`visibility` of their private drafts and may soft-delete
  (`moderation_status='removed'`) their own entry.
- **entries.select** — own rows **or** rows served to me (present in `matches`).
  **No client can read the pool directly.**
- **Promotion to the pool** (`is_shareable=true`, gate outcomes) happens **only**
  via service role / `SECURITY DEFINER` functions.
- **matches** — select own; **no client insert** (only `serve_entry` inserts).
- **profiles** — select/update own row; `suspended` and `report_strikes` are
  **never** client-updatable (trigger-enforced).
- **reports** — insert/select own. **blocks** — full CRUD on own.
- **moderation_log** — no client access (service role only).

Net effect: even a fully malicious client can only manage its own private data;
it cannot inject into the shared pool, read the pool, unsuspend itself, or alter
moderation outcomes.

---

## 5. Module map (`lib/`)

```
lib/
  main.dart            bootstrap: env, Supabase.initialize, RevenueCat, runApp
  app.dart             MaterialApp.router + theme + GoRouter
  core/
    env.dart           --dart-define values; NO secrets
    theme.dart         AppColors/Typography/AppTheme (paper/ink/terracotta)
    result.dart        sealed Result<T>/Failure
    supabase_client.dart
    providers.dart     Riverpod wiring
    app_session.dart
  models/              entry, profile, served_entry, moderation_outcome, crisis_resource
  data/                *_repository.dart (auth, profile, entries, moderation, pool)
  services/
    precheck/          on_device_precheck (abstract), precheck_stub,
                       android_genai_precheck (MethodChannel oneshot/genai_precheck)
    purchases_service.dart   RevenueCat + entitlement `pro`
    analytics_service.dart   PostHog (no-op if unconfigured)
  widgets/             paper_scaffold, hand_button, doodles, warning_banner
  features/            onboarding, paywall, write, journal, read, crisis, settings
```

Routes (GoRouter): `onboarding /`, `paywall /paywall`, `write /write`,
`journal /journal`, `read /read`, `crisis /crisis`, `settings /settings`.
Redirects: anon sign-in if needed → onboarding until `age_confirmed` &
`tos_accepted_at` → hard paywall until entitled → app routes.

### Native (Android)
```
android/app/src/main/kotlin/com/oneshot/journal/
  MainActivity.kt          FlutterActivity; registers the precheck plugin
  GenAiPrecheckPlugin.kt   MethodChannel oneshot/genai_precheck (STUB; see docs)
```

---

## 6. Build order

1. **Backend first:** `supabase db push` (schema + RLS + functions), set
   `OPENAI_API_KEY`, deploy edge functions, enable anonymous auth.
2. **Monetization:** RevenueCat entitlement `pro` + weekly/yearly offerings;
   Google Play products.
3. **App config:** collect `--dart-define` values (`lib/core/env.dart`).
4. **Android project:** `android/` (this project) — AGP 8.7 / Gradle 8.9 /
   Kotlin 1.9, compileSdk/targetSdk 36, minSdk 26; upload key in `key.properties`.
5. **Build:** `flutter build appbundle --release --dart-define=...` → AAB.
6. **Compliance:** Data Safety, content rating, Terms/Privacy hosting, crisis
   verification (`docs/`).
7. **iOS follow-on** later (`docs/ios-followon.md`).
