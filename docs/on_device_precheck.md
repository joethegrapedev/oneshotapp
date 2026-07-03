# On-device pre-check (ML Kit GenAI / Gemini Nano)

The on-device pre-check is an **optional, advisory, UX-only** feature: it can warn
a user *before* they share that their text might trip the server moderation gate.
It is **never** a security boundary — the authoritative decision is always the
server `moderate-and-pool` edge function (CONTRACTS §4/§5).

## Design principles (must hold)

1. **Advisory only.** It changes nothing about what actually gets shared; it only
   shows a non-blocking warning banner (`lib/widgets/warning_banner.dart`).
2. **Availability-gated.** Gemini Nano exists only on a subset of high-end
   devices and may require a one-time model download. The app **must ship and
   work fully when it is unavailable.**
3. **Fail open (toward the server).** On any error, timeout, missing model, or
   unsupported device: report `isAvailable == false` / `tripped == false` and let
   the server decide. Never block the user on the pre-check.
4. **No secrets, no network.** The whole point is on-device inference; it must not
   send text anywhere. (Server moderation already handles the network path.)

## Current state

The app ships with the pre-check **effectively off**:
- Dart: `lib/services/precheck/android_genai_precheck.dart` talks to MethodChannel
  `oneshot/genai_precheck`; if the native side reports unavailable (or the plugin
  is missing) it silently skips. A `precheck_stub.dart` always-unavailable
  implementation is the default fallback.
- Native: `android/app/.../GenAiPrecheckPlugin.kt` is a **stub** —
  `isAvailable` returns `false`, `classify` returns `{tripped:false,
  categories:[]}`. **No ML Kit dependency is added**, keeping the build minimal
  and always buildable.

## Wiring in the real model (ML Kit GenAI — Gemini Nano Prompt API)

1. **Add the dependency** in `android/app/build.gradle` (kept out on purpose):
   ```groovy
   dependencies {
       implementation("com.google.mlkit:genai-prompt:<latest-version>")
   }
   ```
   Verify the current artifact name/version and device requirements in Google's
   ML Kit GenAI documentation before adding.

2. **Availability probe** — replace `handleIsAvailable` in
   `GenAiPrecheckPlugin.kt`:
   - Query the GenAI/Prompt feature status.
   - If the model is present and ready → `result.success(true)`.
   - If it is missing, still downloading, unsupported on the device, or any check
     throws → `result.success(false)`.
   - Optionally trigger a background feature/model download, but keep returning
     `false` until it is actually ready.

3. **Classification** — replace `handleClassify`:
   - Read `call.argument<String>("text")`.
   - Run the Prompt API asynchronously with a **tight timeout** (e.g. a couple of
     seconds); the UI must not stall.
   - Prompt the model to flag whether the text likely violates the shared-pool
     rules and which categories apply, mapping output to the server taxonomy
     strings (CONTRACTS §5: `sexual`, `self-harm`, `harassment`, `hate`,
     `violence`, `illicit`, ...). Keep it a hint, not a verdict.
   - Return `{"tripped": Boolean, "categories": List<String>}`.
   - On **any** error/timeout → return `{"tripped": false, "categories": []}`.

4. **Threading:** run inference off the main thread and post the
   `result.success(...)` call back on the main looper.

5. **ProGuard:** if you add ML Kit, uncomment the keep rules in
   `android/app/proguard-rules.pro`:
   ```
   -keep class com.google.mlkit.genai.** { *; }
   -dontwarn com.google.mlkit.genai.**
   ```

6. **Register:** already handled — `MainActivity.configureFlutterEngine` calls
   `GenAiPrecheckPlugin.register(flutterEngine)`.

## Testing
- On a device without Gemini Nano: confirm `isAvailable == false` and the app
  never shows the pre-check warning (behaviour unchanged).
- On a supported device: confirm warnings appear for clearly-problematic text but
  that sharing is still gated by the server, and that the warning is dismissible
  and non-blocking.

## iOS follow-on
The same abstraction (`PrecheckService`) will back an iOS implementation using
**Apple Foundation Models** (on-device) once the iOS platform is added. Same
rules: availability-gated, advisory only, fail open. See `docs/ios-followon.md`.
