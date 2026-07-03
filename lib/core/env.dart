/// Environment configuration read from `--dart-define` values.
///
/// NO SECRETS live here. The Supabase anon key and RevenueCat *public* SDK key
/// are safe to ship in the client. The OpenAI key is never referenced by the
/// app — it lives only in the Supabase Edge Function environment.
class Env {
  const Env._();

  static const String supabaseUrl =
      String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  static const String revenueCatAndroidKey =
      String.fromEnvironment('REVENUECAT_ANDROID_KEY', defaultValue: '');
  static const String revenueCatIosKey =
      String.fromEnvironment('REVENUECAT_IOS_KEY', defaultValue: '');

  static const String posthogKey =
      String.fromEnvironment('POSTHOG_KEY', defaultValue: '');
  static const String posthogHost = String.fromEnvironment(
    'POSTHOG_HOST',
    defaultValue: 'https://us.i.posthog.com',
  );

  static const String tosUrl = String.fromEnvironment(
    'TOS_URL',
    defaultValue: 'https://example.com/terms',
  );
  static const String privacyUrl = String.fromEnvironment(
    'PRIVACY_URL',
    defaultValue: 'https://example.com/privacy',
  );
  static const String supportEmail = String.fromEnvironment(
    'SUPPORT_EMAIL',
    defaultValue: 'support@example.com',
  );
  static const String tosVersion =
      String.fromEnvironment('TOS_VERSION', defaultValue: '2026-07-01');

  /// The RevenueCat entitlement identifier that unlocks the app.
  static const String entitlementId = 'pro';

  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
  static bool get isPosthogConfigured => posthogKey.isNotEmpty;
}
