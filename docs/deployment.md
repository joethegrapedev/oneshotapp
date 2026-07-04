# Deployment guide — One Shot

End-to-end steps to build and ship One Shot to the Google Play Store (Singapore,
18+). Android is the launch platform; iOS is a documented follow-on
(`docs/ios-followon.md`).

- **applicationId:** `com.oneshot.journal`
- **App name:** One Shot
- **compileSdk / targetSdk:** 36 · **minSdk:** 26
- **Output:** Android App Bundle (`.aab`) via `flutter build appbundle`

---

## 1. Prerequisites

Accounts / services:
- **Google Play Console** developer account (with the app created).
- **Supabase** project (hosting, Postgres, auth, edge functions).
- **OpenAI** account + API key (moderation endpoint) — used **only** in the edge
  function environment, never in the app.
- **RevenueCat** account (subscription entitlements + Google Play integration).

Local tooling:
- **Flutter SDK 3.24+** (Dart 3) — `flutter --version`.
- **Android SDK** with platform 36 + build-tools; JDK **17**.
- **Supabase CLI** — `supabase --version`.
- **Node.js** (for the Supabase function tests in `supabase/tests`).
- **Deno** is bundled with the Supabase CLI for edge functions.

---

## 2. Backend (Supabase)

```bash
# From the repo root.
supabase login
supabase link --project-ref <your-project-ref>

# Apply the database schema + RLS + functions (supabase/migrations).
supabase db push

# Set edge-function secrets (server-only; NEVER in the app).
supabase secrets set OPENAI_API_KEY=sk-...
# SUPABASE_URL / SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY are provided to
# functions by the platform; set them explicitly only for local `supabase serve`.

# Deploy the edge functions (see CONTRACTS §4).
supabase functions deploy moderate-and-pool
supabase functions deploy serve-entry
supabase functions deploy delete-account
```

**Enable anonymous auth:** in the Supabase dashboard → Authentication →
Providers, enable **Anonymous sign-ins** (the app signs in anonymously by
default and lets users optionally link an email). Configure email auth if you
want email linking.

Verify RLS is active and the SECURITY DEFINER functions
(`serve_entry`, `apply_report`, `resolve_report`, `delete_my_account`) exist —
these enforce the security model (clients can never set `is_shareable` or read
the pool directly; see CONTRACTS §2/§3).

---

## 3. RevenueCat + Google Play products

1. In the **Google Play Console**, create subscription products for the app
   (`com.oneshot.journal`), e.g.:
   - `oneshot_pro_weekly` — ~**S$6.98 / week** (tunable default)
   - `oneshot_pro_yearly` — ~**S$54.98 / year** (tunable default)
2. In **RevenueCat**:
   - Create an **entitlement** with identifier **`pro`** (matches
     `Env.entitlementId`).
   - Create **offerings** containing a **weekly** and a **yearly** package,
     attached to the Play products above.
   - Connect the Google Play service credentials.
   - Copy the **public Android SDK key** (`goog_...`) for the app build.
3. Prices above are defaults — tune in Play/RevenueCat; the app reads live
   offerings, so no code change is needed to adjust price.

---

## 4. Configure the Flutter build (dart-define)

No secrets are compiled into the app. All config comes from `--dart-define`
(read in `lib/core/env.dart`). Keys:

| Key | Required | Notes |
|---|---|---|
| `SUPABASE_URL` | yes | Project URL |
| `SUPABASE_ANON_KEY` | yes | Public anon key (safe to ship) |
| `REVENUECAT_ANDROID_KEY` | yes (Android) | Public SDK key `goog_...` |
| `REVENUECAT_IOS_KEY` | later (iOS) | Public SDK key `appl_...` |
| `POSTHOG_KEY` | optional | Analytics; no-op if empty |
| `POSTHOG_HOST` | optional | Default `https://us.i.posthog.com` |
| `TOS_URL` | yes | Hosted Terms URL (`LEGAL/terms-of-use.md`) |
| `PRIVACY_URL` | yes | Hosted Privacy URL (`LEGAL/privacy-policy.md`) |
| `SUPPORT_EMAIL` | yes | Support/contact address |
| `TOS_VERSION` | yes | Must match the version in the Terms (e.g. `2026-07-01`) |

Tip: keep these in a git-ignored `--dart-define-from-file` JSON (e.g.
`dart_defines/prod.json`) and pass `--dart-define-from-file=dart_defines/prod.json`.

Example (inline form):

```bash
flutter build appbundle --release \
  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJ... \
  --dart-define=REVENUECAT_ANDROID_KEY=goog_... \
  --dart-define=POSTHOG_KEY= \
  --dart-define=TOS_URL=https://oneshot-legal.vercel.app/terms \
  --dart-define=PRIVACY_URL=https://oneshot-legal.vercel.app/privacy \
  --dart-define=SUPPORT_EMAIL=support@oneshot.app \
  --dart-define=TOS_VERSION=2026-07-01
```

---

## 5. Signing — Play App Signing + upload key

We use **Play App Signing**: you sign uploads with an **upload key**; Google
holds and manages the actual **app signing key**.

1. Generate an upload keystore once:
   ```bash
   keytool -genkey -v -keystore upload-keystore.jks \
     -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. Create `android/key.properties` (git-ignored — see
   `android/key.properties.example`):
   ```properties
   storeFile=/absolute/path/to/upload-keystore.jks
   storePassword=********
   keyAlias=upload
   keyPassword=********
   ```
3. `android/app/build.gradle` reads `key.properties` if present and uses it for
   the `release` signing config. **If it is absent, the release build falls back
   to debug signing so the project still assembles** — but Play will reject a
   debug-signed bundle, so supply `key.properties` for real releases.
4. On first upload, opt into Play App Signing and let Google generate/manage the
   app signing key; your upload key is only used to authenticate uploads.

`android/local.properties` (SDK/Flutter paths) is machine-specific and
git-ignored — Flutter generates it; see `android/local.properties.example`.

---

## 6. Build the release bundle

```bash
flutter pub get
flutter analyze
flutter test
flutter build appbundle --release --dart-define=...   # (see §4)
# Output: build/app/outputs/bundle/release/app-release.aab
```

Upload `app-release.aab` to the Play Console (internal testing → closed →
production). Complete the Play listing:
- **Data Safety** form — see `docs/data-safety.md`.
- **Content rating (IARC)** questionnaire — see `docs/content-rating.md`.
- **Target audience / 18+** and UGC declarations.
- Link the hosted **Terms** and **Privacy** URLs.

---

## 7. Pre-submission checklist

- [ ] `supabase db push` applied; RLS + SECURITY DEFINER functions verified.
- [ ] Edge functions deployed; `OPENAI_API_KEY` secret set; anonymous auth on.
- [ ] RevenueCat entitlement `pro` + weekly/yearly offerings live; Play products
      active.
- [ ] All dart-define keys set for the release build (§4).
- [ ] `key.properties` present; bundle signed with the upload key.
- [ ] **Crisis resources re-verified** (`docs/crisis-resources.md`).
- [ ] Terms/Privacy hosted and versions match `TOS_VERSION`.
- [ ] Data Safety + content rating forms completed and consistent with the app.
