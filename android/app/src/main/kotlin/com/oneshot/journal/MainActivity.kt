package com.oneshot.journal

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * The single Flutter host Activity (Android embedding v2).
 *
 * Beyond the default FlutterActivity behaviour, we register the on-device
 * GenAI precheck MethodChannel plugin so the Dart side
 * (`lib/services/precheck/android_genai_precheck.dart`, channel
 * `oneshot/genai_precheck`) has a native handler to talk to.
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Wire up the advisory on-device precheck channel.
        GenAiPrecheckPlugin.register(flutterEngine)
    }
}
