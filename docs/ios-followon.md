# iOS follow-on plan

iOS is **not built now**. One Shot launches on Android first; the codebase is
Flutter so the same `lib/` runs on iOS once the platform is added. This document
captures the plan (per CONTRACTS §12 intent) so the follow-on is a config +
platform-glue exercise, not a rewrite.

> **Do not build iOS as part of the Android launch.** This is a forward-looking
> checklist.

## 1. Add the iOS platform
- `flutter create --platforms=ios .` to generate `ios/` (Runner project, plists,
  build config). Keep `lib/` unchanged.
- Bundle id: mirror Android → e.g. `com.oneshot.journal`.
- Deployment target: pick a modern minimum (align with plugin requirements and
  Foundation Models availability).

## 2. On-device pre-check → Apple Foundation Models
- Add an iOS `PrecheckService` implementation behind the existing abstraction
  (`lib/services/precheck/on_device_precheck.dart`), analogous to
  `android_genai_precheck.dart`, backed by a Swift MethodChannel that calls
  **Apple Foundation Models** (on-device).
- Same rules as Android (see `docs/on_device_precheck.md`): **availability-gated,
  advisory only, fail open**. The app must work with it unavailable.

## 3. Subscriptions: RevenueCat → StoreKit (automatic)
- RevenueCat handles StoreKit automatically; provide the **iOS public SDK key**
  via `--dart-define=REVENUECAT_IOS_KEY=appl_...` (already read in
  `lib/core/env.dart`).
- Create the matching App Store Connect subscription products and attach them to
  the existing `pro` entitlement / offerings (weekly + yearly).

## 4. App Store review readiness (UGC — Guideline 1.2)
Apple **Guideline 1.2** requires apps with user-generated content to have:
- a method to **filter objectionable content** — satisfied by the server
  moderation gate (CONTRACTS §4/§5);
- a mechanism to **report** offensive content — satisfied by `apply_report`;
- the ability to **block abusive users** — satisfied by the `blocks` table /
  `PoolRepository.block`;
- **published Terms (EULA)** that prohibit objectionable content and abusive
  behaviour — `LEGAL/terms-of-use.md`;
- **act on reports within 24h** (remove content + eject the user) — our
  optimistic removal on report + suspension after upheld reports supports this;
  ensure an operational review SLA.

## 5. Age rating & privacy
- Set **18+** age rating in App Store Connect (matches the in-app age gate).
- Complete **privacy nutrition labels** consistent with `docs/data-safety.md` and
  `LEGAL/privacy-policy.md` (email if linked, journal text, reports/blocks;
  OpenAI = processing, not sold/trained; no location/contacts).
- Provide required privacy manifest(s) for the app and any SDKs that need them.

## 6. Demo account for review
- Provide Apple reviewers a **demo account** (or working anonymous flow) plus
  notes on how to reach share/report/block, since the app is anonymous and paid.
- Ensure the reviewer can exercise moderation, report, and block end-to-end.

## 7. Build & submit
- Reuse the same `--dart-define` keys (add `REVENUECAT_IOS_KEY`).
- `flutter build ipa --release --dart-define=...`, upload via Xcode/Transporter.

## Not changing
- Backend (Supabase), moderation edge functions, RLS, and the `lib/` app logic
  are shared and unchanged. iOS is additive platform glue + store config.
