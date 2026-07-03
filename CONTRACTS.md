# CONTRACTS — single source of truth

Every module (Flutter app, Supabase backend, tests, docs) MUST conform to the
names, shapes, and rules below. If something here looks wrong, flag it — do not
silently diverge.

Product: an anonymous private journaling app with an **opt-in exchange**. When a
user shares an entry it passes a **server-side moderation gate** before it can
enter the shared pool; sharing shows the author one stranger's already-cleared
entry. Private entries never leave the device-owner's account. Anonymous: no
usernames, profiles, DMs, or reply channel. Launch: Singapore, 18+, Android
first (Flutter, iOS later from same codebase).

---

## 1. Database (Postgres) — table & column names

All tables live in schema `public`. `id` columns are `uuid` (default
`gen_random_uuid()`), timestamps are `timestamptz default now()`.

### profiles
| column | type | notes |
|---|---|---|
| id | uuid PK | = `auth.users.id` |
| created_at | timestamptz | |
| age_confirmed | boolean default false | set true only after 18+ gate |
| tos_accepted_at | timestamptz null | null until ToS accepted |
| tos_version | text null | version string accepted |
| suspended | boolean default false | service-role only |
| report_strikes | int default 0 | service-role only |

### entries
| column | type | notes |
|---|---|---|
| id | uuid PK | |
| author_id | uuid | FK profiles.id, `default auth.uid()` |
| body | text | the entry text |
| created_at | timestamptz | |
| visibility | text | `'private'` \| `'shared'` (author intent) |
| moderation_status | text | enum below; default `'private'` |
| is_shareable | boolean default false | **service-role only**; pool eligibility |
| moderation_categories | jsonb default '{}' | provider category scores/flags |
| moderated_at | timestamptz null | |

`moderation_status` values:
`private` (never submitted), `pending` (submitted, awaiting gate),
`clean` (passed → is_shareable=true), `held_selfharm`, `held_pii`,
`rejected` (sexual/minors hard reject), `rejected_objectionable`,
`removed` (pulled by report/block/deletion).

### matches
| column | type | notes |
|---|---|---|
| id | uuid PK | |
| reader_id | uuid | FK profiles.id — who was shown the entry |
| entry_id | uuid | FK entries.id — the entry shown |
| served_at | timestamptz | |
UNIQUE(reader_id, entry_id).

### reports
| column | type | notes |
|---|---|---|
| id | uuid PK | |
| reporter_id | uuid | FK profiles.id |
| entry_id | uuid | FK entries.id |
| reason | text | short enum-ish string |
| status | text | `'open'` \| `'upheld'` \| `'dismissed'` default `'open'` |
| created_at | timestamptz | |
| resolved_at | timestamptz null | |

### blocks
| column | type | notes |
|---|---|---|
| blocker_id | uuid | FK profiles.id |
| blocked_id | uuid | FK profiles.id (author of a served entry) |
| created_at | timestamptz | |
PRIMARY KEY(blocker_id, blocked_id).

### moderation_log
| column | type | notes |
|---|---|---|
| id | uuid PK | |
| entry_id | uuid null | FK entries.id |
| provider | text | e.g. `'openai:omni-moderation-latest'`, `'pii-regex'` |
| result | jsonb | raw provider result / decision detail |
| action | text | e.g. `clean`, `held_selfharm`, `rejected`, `held_pii`, `rejected_objectionable` |
| created_at | timestamptz | |

Config constant: `UPHELD_REPORTS_TO_SUSPEND = 3`.

---

## 2. RLS rules (must hold; tests assert them)

- `profiles`: user may `select`/`update` only their own row (`id = auth.uid()`).
  Columns `suspended`, `report_strikes` are **never** client-updatable (enforced
  by trigger — a client UPDATE that changes them is rejected).
- `entries`:
  - `select`: own rows (`author_id = auth.uid()`) OR rows served to me
    (exists in `matches` where `reader_id = auth.uid()` and `entry_id = entries.id`).
    **No client can select the pool directly.**
  - `insert`: only with `author_id = auth.uid()`, `is_shareable = false`,
    `moderation_status in ('private','pending')`. Client cannot insert
    `is_shareable = true`.
  - `update`: own rows only, and a client UPDATE may **not** change
    `is_shareable`, `moderation_status`, or `moderation_categories`
    (enforced by trigger). Client may change `body`/`visibility` of own private
    drafts and may set `moderation_status='removed'` on own entry (soft delete).
  - `delete`: own rows only.
- `is_shareable = true` promotion and all moderation_status transitions to the
  gate outcomes happen **only via service role / SECURITY DEFINER functions**.
- `matches`: `select` own (`reader_id = auth.uid()`). **No client insert** — only
  the `serve_entry` SECURITY DEFINER function inserts.
- `reports`: `insert` own (`reporter_id = auth.uid()`); `select` own.
- `blocks`: full CRUD on own (`blocker_id = auth.uid()`).
- `moderation_log`: **no client access** (service role only).

---

## 3. SQL functions (SECURITY DEFINER unless noted)

### `serve_entry() returns entries`  (or the shaped row below)
Called by an authenticated user via `rpc('serve_entry')`. Selects one random
entry where: `is_shareable = true`, `author_id <> auth.uid()`, no existing
`matches(reader_id=auth.uid(), entry_id=e.id)`, author not in
`blocks(blocker_id=auth.uid())`, author not `suspended`, `moderation_status='clean'`.
Inserts a `matches` row and returns the served entry (id, body, created_at,
author_id). Returns NULL row set if the pool is empty for this user (cold start).

### `apply_report(p_entry_id uuid, p_reason text) returns void`
Inserts a `reports` row (reporter = auth.uid()), optimistically sets the entry
`is_shareable=false` and `moderation_status='removed'` so it stops being served,
and removes the reader's `matches` row for it. (Author-suspension on N upheld
reports is done by the review process / a service-role function
`resolve_report`.)

### `resolve_report(p_report_id uuid, p_uphold boolean) returns void`
Service-role only. Marks report upheld/dismissed; if upheld, increments author
`report_strikes`; when strikes >= `UPHELD_REPORTS_TO_SUSPEND`, sets author
`suspended=true`.

### `delete_my_account() returns void`
Purges the caller's poolable entries and personal data (entries, matches where
reader=me, reports by me, blocks by me, profile), then the auth user is deleted
by an edge function using service role. See `docs/deployment.md`.

---

## 4. Edge Functions (Deno/TypeScript)

Base: `https://<project-ref>.functions.supabase.co/<name>`. All require the
user's JWT in `Authorization: Bearer <access_token>`; functions verify it.

### `moderate-and-pool`
Request `POST` JSON:
```json
{ "entry_id": "uuid" }
```
The function loads the entry (service role), confirms caller is the author,
runs the gate, updates the entry + writes `moderation_log`.
Response JSON:
```json
{
  "status": "clean|held_selfharm|held_pii|rejected|rejected_objectionable",
  "is_shareable": true,
  "categories": { "self-harm": 0.01, "sexual": 0.0, "...": 0.0 },
  "message": "human-readable reason (for held/rejected)",
  "crisis": {                      // present ONLY when status == held_selfharm
    "region": "SG",
    "resources": [
      { "name": "Samaritans of Singapore (SOS)", "contact": "1-767",
        "hours": "24h", "note": "verify at build time" }
    ]
  }
}
```
Decision matrix — see `supabase/functions/_shared/moderation.ts`
(`decide(moderationResult, piiResult)`), which is pure and unit-tested.

### `serve-entry`
Thin authenticated wrapper that calls `rpc('serve_entry')` (primary path is the
RPC directly; this exists for parity/future rate-limiting).
Response JSON: `{ "entry": { "id","body","created_at","author_id" } | null }`.

### `delete-account`
Runs `delete_my_account()` RPC then deletes the auth user via admin API.
Response: `{ "ok": true }`.

---

## 5. Moderation decision logic (pure) — `_shared/moderation.ts`

```ts
export type Category =
  | 'sexual' | 'sexual/minors' | 'harassment' | 'harassment/threatening'
  | 'hate' | 'hate/threatening' | 'illicit' | 'illicit/violent'
  | 'self-harm' | 'self-harm/intent' | 'self-harm/instructions'
  | 'violence' | 'violence/graphic';

export interface ModerationResult {
  flagged: boolean;
  categories: Record<string, boolean>;
  category_scores: Record<string, number>;
}
export interface PiiResult { hasPii: boolean; kinds: string[]; }

export type Decision =
  | 'clean' | 'held_selfharm' | 'held_pii'
  | 'rejected' | 'rejected_objectionable';

export function decide(m: ModerationResult, pii: PiiResult): {
  decision: Decision; isShareable: boolean; reason: string;
};
```
Order of checks (first match wins):
1. `sexual/minors` flagged (or score ≥ 0.2) → `rejected` (hard). isShareable=false.
2. `self-harm*` flagged (or self-harm score ≥ 0.5) → `held_selfharm`. isShareable=false.
3. any of `sexual`, `violence/graphic`, `harassment*`, `hate*`, `illicit*`
   flagged OR score ≥ threshold (see file) → `rejected_objectionable`. isShareable=false.
4. `pii.hasPii` → `held_pii`. isShareable=false.
5. else → `clean`. isShareable=true.

Thresholds live in `_shared/moderation.ts` as named constants and are the single
place to tune. Self-harm is checked **before** generic objectionable so it always
routes to crisis, never to a plain reject.

---

## 6. Flutter — packages, structure, contracts

`pubspec.yaml` deps: `supabase_flutter`, `flutter_riverpod`, `go_router`,
`purchases_flutter` (RevenueCat), `google_fonts`, `shared_preferences`,
`url_launcher`, `posthog_flutter` (optional), plus dev `flutter_test`,
`mocktail`, `flutter_lints`.

Directory layout under `lib/`:
```
lib/
  main.dart                 // bootstrap: env, Supabase.initialize, RevenueCat, runApp
  app.dart                  // MaterialApp.router + theme + GoRouter
  core/
    env.dart                // reads --dart-define values; NO secrets
    theme.dart              // AppColors, AppTypography, AppTheme  (see §7)
    result.dart             // sealed Result<T> / Failure
    supabase_client.dart    // SupabaseClient accessor
    providers.dart          // Riverpod providers wiring repos/services
  models/
    entry.dart              // Entry (see fields §1 entries) + fromJson/toJson/copyWith
    profile.dart            // Profile
    served_entry.dart       // ServedEntry (id, body, createdAt, authorId)
    moderation_outcome.dart // ModerationOutcome (status, isShareable, message, crisis?)
    crisis_resource.dart    // CrisisResource (name, contact, hours, note)
  data/
    entries_repository.dart     // abstract + Supabase impl
    moderation_repository.dart  // calls moderate-and-pool edge function
    pool_repository.dart        // serve_entry, report, block
    profile_repository.dart     // profile, age/tos, delete account
    auth_repository.dart        // anonymous + email
  services/
    precheck/on_device_precheck.dart      // abstract PrecheckService
    precheck/precheck_stub.dart           // always-unavailable default
    precheck/android_genai_precheck.dart  // MethodChannel to ML Kit GenAI (availability-gated)
    purchases_service.dart                // RevenueCat wrapper + entitlement
    analytics_service.dart                // PostHog wrapper (no-op if unconfigured)
  widgets/
    paper_scaffold.dart     // paper background + minimal chrome
    hand_button.dart        // hand-drawn line button
    doodles.dart            // CustomPainter spot-illustrations (single-weight line)
    warning_banner.dart     // non-blocking precheck warning
  features/
    onboarding/onboarding_screen.dart   // value prop → age gate → ToS → paywall
    paywall/paywall_screen.dart
    write/write_screen.dart
    journal/journal_screen.dart
    read/read_back_screen.dart
    crisis/crisis_screen.dart
    settings/settings_screen.dart
```

### Repository interfaces (method names other modules rely on)
- `AuthRepository`: `Session? get currentSession`, `Future<void> signInAnonymously()`,
  `Future<void> linkEmail(String email)`, `Stream<AuthState> authStateChanges()`,
  `Future<void> signOut()`.
- `ProfileRepository`: `Future<Profile> ensureProfile()`,
  `Future<void> confirmAge()`, `Future<void> acceptTos(String version)`,
  `Future<Profile> current()`, `Future<void> deleteAccount()`.
- `EntriesRepository`: `Future<Entry> saveDraft({required String body, required bool private})`,
  `Future<List<Entry>> myEntries({String? search})`,
  `Future<void> updateBody(String id, String body)`,
  `Future<void> softDelete(String id)`.
- `ModerationRepository`: `Future<ModerationOutcome> submitForSharing(String entryId)`
  (calls edge function `moderate-and-pool`).
- `PoolRepository`: `Future<ServedEntry?> serveOne()` (rpc serve_entry),
  `Future<void> report(String entryId, String reason)` (rpc apply_report),
  `Future<void> block(String authorId)` (insert blocks).
- `PurchasesService`: `Future<bool> get isEntitled`, `Future<Offerings?> offerings()`,
  `Future<bool> purchase(Package p)`, `Future<bool> restore()`.
- `PrecheckService`: `Future<bool> isAvailable()`,
  `Future<PrecheckResult> classify(String text)` where
  `PrecheckResult { bool tripped; List<String> categories; }`.

### Routes (GoRouter `name`s)
`onboarding` `/`, `paywall` `/paywall`, `write` `/write`, `journal` `/journal`,
`read` `/read`, `crisis` `/crisis`, `settings` `/settings`.
Redirect logic: unauthenticated/anon-not-set → sign in anon; if
`!age_confirmed || tos_accepted_at == null` → `onboarding`; if not entitled →
`paywall`; else allow app routes.

### Entitlement / gating
Paywall is hard: app routes (`write`,`journal`,`read`,`settings`) require
`PurchasesService.isEntitled == true`. Entitlement id: `pro`.

---

## 7. Theme tokens (§7 aesthetic)

Hand-drawn single-weight line illustration; imperfect strokes; disciplined layout.
- `AppColors.paper`   = `#FBF7F0` (warm off-white background)
- `AppColors.ink`     = `#1E1B18` (near-black)
- `AppColors.accent`  = `#C05C3A` (one muted terracotta accent)
- `AppColors.inkSoft` = `#6B655E` (secondary text)
- Typography: `google_fonts` — headings `Fraunces` (softly-rounded serif),
  body/writing `Nunito Sans` (humanist sans). Writing surface line-height 1.6.
- Generous padding (24), rounded organic corners (radius 18–24), minimal chrome.
- Doodles are `CustomPainter`s with slightly jittered control points
  (single stroke width ~2.2, `StrokeCap.round`) to read as hand-drawn.

---

## 8. Config / secrets

- No secrets in the app. Supabase URL + anon key + RevenueCat public SDK key are
  passed via `--dart-define` and read in `core/env.dart`. OpenAI key lives ONLY
  in the Edge Function environment (`OPENAI_API_KEY`), never in the client.
- Env keys (dart-define): `SUPABASE_URL`, `SUPABASE_ANON_KEY`,
  `REVENUECAT_ANDROID_KEY`, `REVENUECAT_IOS_KEY`, `POSTHOG_KEY` (optional),
  `POSTHOG_HOST` (optional), `TOS_URL`, `PRIVACY_URL`, `SUPPORT_EMAIL`,
  `TOS_VERSION`.
- Edge function env: `OPENAI_API_KEY`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`,
  `SUPABASE_SERVICE_ROLE_KEY`.

---

## 9. Crisis resources (Singapore) — verify at build time

Placeholders to be verified against SOS/mindline before store submission
(see `docs/crisis-resources.md`). Do not hardcode without a build-time check note.
- Samaritans of Singapore (SOS) 24h hotline: **1-767** (verify).
- SOS CareText (WhatsApp): **9151 1767** (verify).
- national mindline 1771 / mindline.sg (verify hours & number).
The app renders whatever the edge function returns in the `crisis` payload and
also ships a local fallback copy in `features/crisis/crisis_screen.dart`.
