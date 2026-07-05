# ProGuard / R8 rules for One Shot (release build has minify + shrinkResources).
#
# Flutter itself ships consumer rules, but we keep explicit rules for the
# plugins used by this app and for our own native GenAI precheck plugin.

# ---- Flutter engine / embedding v2 ----------------------------------------
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# ---- Our native GenAI precheck plugin (reflected via MethodChannel) --------
# Keep so the MethodChannel handler class is never stripped/renamed.
-keep class com.oneshot.journal.GenAiPrecheckPlugin { *; }
-keep class com.oneshot.journal.MainActivity { *; }

# ---- Supabase / GoTrue (supabase_flutter) ---------------------------------
# supabase_flutter is mostly Dart, but keep any Kotlin plugin glue + models.
-keep class io.supabase.** { *; }
-dontwarn io.supabase.**

# ---- RevenueCat (purchases_flutter) ---------------------------------------
-keep class com.revenuecat.purchases.** { *; }
-dontwarn com.revenuecat.purchases.**
# RevenueCat uses the Google Play Billing library.
-keep class com.android.billingclient.** { *; }
-dontwarn com.android.billingclient.**

# ---- PostHog (posthog_flutter) --------------------------------------------
-keep class com.posthog.** { *; }
-dontwarn com.posthog.**

# ---- Kotlin / coroutines / serialization (used transitively) --------------
-keep class kotlin.Metadata { *; }
-keepclassmembers class kotlinx.serialization.** { *; }
-dontwarn kotlinx.serialization.**
-dontwarn kotlin.**

# ---- ML Kit GenAI (OPTIONAL — only if you later add the dependency) --------
# See docs/on_device_precheck.md. Uncomment when you wire in Gemini Nano:
# -keep class com.google.mlkit.genai.** { *; }
# -dontwarn com.google.mlkit.genai.**

# ---- Play Core (Flutter deferred components — NOT used by this app) --------
# Flutter's embedding references com.google.android.play.core.* for deferred
# component / split-install support. This app ships no deferred components and
# does not depend on Play Core, so those classes are absent at R8 time. Tell R8
# not to fail on the missing references (matches Flutter's own missing_rules.txt).
-dontwarn com.google.android.play.core.**

# Keep annotations / generic signatures for reflection-friendly libraries.
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod
