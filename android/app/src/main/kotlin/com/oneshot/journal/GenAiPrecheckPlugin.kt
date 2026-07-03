package com.oneshot.journal

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * GenAiPrecheckPlugin — native handler for the MethodChannel
 * `oneshot/genai_precheck`, consumed by
 * `lib/services/precheck/android_genai_precheck.dart`.
 *
 * ============================================================================
 * WHAT THIS IS
 * ============================================================================
 * An OPTIONAL, ADVISORY, on-device pre-check that can warn a user *before* they
 * share an entry that their text might trip the server moderation gate. It is a
 * UX nicety only.
 *
 * IT IS NOT A SECURITY BOUNDARY. The authoritative decision is always made
 * server-side by the `moderate-and-pool` edge function (see CONTRACTS §4/§5).
 * Nothing here can promote an entry into the shared pool, and a device that
 * lies or fails here changes nothing about what actually gets shared. If in any
 * doubt this code MUST fail "open" toward the server — i.e. report
 * `isAvailable == false` / `tripped == false` and let the server decide.
 *
 * ============================================================================
 * CURRENT STATE: STUB (availability-gated OFF by default)
 * ============================================================================
 * To keep the build light and always buildable we DO NOT depend on ML Kit
 * GenAI here. `isAvailable` returns false, so the Dart layer skips the
 * pre-check entirely and the app behaves exactly as if no on-device model
 * existed. `classify` returns a benign "not tripped" result as a defensive
 * default in case it is ever called directly.
 *
 * ============================================================================
 * HOW TO WIRE IN THE REAL MODEL (ML Kit GenAI — Gemini Nano Prompt API)
 * ============================================================================
 * Full walkthrough in docs/on_device_precheck.md. In brief:
 *
 *  1. Add the dependency in android/app/build.gradle, e.g.
 *         implementation("com.google.mlkit:genai-prompt:<version>")
 *     (kept out of this repo intentionally so the build stays minimal).
 *
 *  2. In `handleIsAvailable`, query real on-device availability. Gemini Nano is
 *     only present on a subset of high-end devices and the feature may need a
 *     one-time model download. You MUST check availability/feature status and
 *     return false whenever the model is missing, still downloading, or the
 *     API throws. NEVER assume it is present.
 *
 *  3. In `handleClassify`, run the Prompt API asynchronously with a tight
 *     timeout, map the model output to our category strings, and return
 *     {tripped, categories}. On ANY error or timeout, return the benign
 *     "not tripped" result — advisory only, degrade silently.
 *
 *  4. Keep everything off the main thread; MethodChannel results may be posted
 *     back from a background callback (post to the main looper before calling
 *     result.success(...)).
 *
 * The category strings should mirror the server taxonomy in CONTRACTS §5
 * (e.g. "self-harm", "sexual", "harassment", "hate", "violence", ...), but
 * remember these are only hints for the warning banner.
 */
class GenAiPrecheckPlugin private constructor() : MethodChannel.MethodCallHandler {

    companion object {
        private const val CHANNEL = "oneshot/genai_precheck"

        /** Attach the handler to the engine's binary messenger. */
        fun register(flutterEngine: FlutterEngine) {
            val channel = MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                CHANNEL,
            )
            channel.setMethodCallHandler(GenAiPrecheckPlugin())
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> handleIsAvailable(result)
            "classify" -> handleClassify(call, result)
            else -> result.notImplemented()
        }
    }

    /**
     * STUB: no on-device model is wired in, so we report unavailable. The Dart
     * layer treats false as "skip the pre-check" and the app works normally.
     *
     * When wiring ML Kit GenAI, replace this with a real availability probe and
     * return false on any missing model / pending download / thrown exception.
     */
    private fun handleIsAvailable(result: MethodChannel.Result) {
        result.success(false)
    }

    /**
     * STUB: returns a benign, non-tripped result. Because `isAvailable` is
     * false the Dart side normally never calls this, but we answer defensively
     * so a direct call can never produce a false-positive warning.
     *
     * Real implementation: run the Prompt API on `call.argument<String>("text")`,
     * with a timeout, map to categories, and always degrade to this benign
     * result on error/timeout.
     */
    private fun handleClassify(call: MethodCall, result: MethodChannel.Result) {
        // val text = call.argument<String>("text") ?: ""  // used by real impl
        result.success(
            mapOf(
                "tripped" to false,
                "categories" to emptyList<String>(),
            ),
        )
    }
}
