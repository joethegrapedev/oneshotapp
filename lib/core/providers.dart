import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_repository.dart';
import '../data/entries_repository.dart';
import '../data/moderation_repository.dart';
import '../data/pool_repository.dart';
import '../data/profile_repository.dart';
import '../services/analytics_service.dart';
import '../services/precheck/android_genai_precheck.dart';
import '../services/precheck/on_device_precheck.dart';
import '../services/precheck/precheck_stub.dart';
import '../services/dev_purchases_service.dart';
import '../services/purchases_service.dart';
import 'app_session.dart';
import 'env.dart';
import 'supabase_client.dart';

/// The raw Supabase client. Overridable in tests.
final supabaseClientProvider = Provider<SupabaseClient>((ref) => supabase);

// ---- Repositories ---------------------------------------------------------

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => SupabaseAuthRepository(ref.watch(supabaseClientProvider)),
);

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => SupabaseProfileRepository(ref.watch(supabaseClientProvider)),
);

final entriesRepositoryProvider = Provider<EntriesRepository>(
  (ref) => SupabaseEntriesRepository(ref.watch(supabaseClientProvider)),
);

final moderationRepositoryProvider = Provider<ModerationRepository>(
  (ref) => SupabaseModerationRepository(ref.watch(supabaseClientProvider)),
);

final poolRepositoryProvider = Provider<PoolRepository>(
  (ref) => SupabasePoolRepository(ref.watch(supabaseClientProvider)),
);

// ---- Services -------------------------------------------------------------

final purchasesServiceProvider = Provider<PurchasesService>((ref) {
  // DEV-ONLY paywall bypass: only ever active in a non-release build with the
  // git-ignored --dart-define=DEV_FORCE_ENTITLED=true. Release builds always
  // use the real RevenueCat service.
  if (!kReleaseMode && Env.devForceEntitled) {
    return DevEntitledPurchasesService();
  }
  return RevenueCatPurchasesService();
});

final analyticsServiceProvider = Provider<AnalyticsService>(
  (ref) =>
      Env.isPosthogConfigured
          ? const PosthogAnalyticsService()
          : const NoopAnalyticsService(),
);

/// Picks the on-device pre-check for the platform, degrading to a no-op.
final precheckServiceProvider = Provider<PrecheckService>((ref) {
  try {
    if (Platform.isAndroid) return AndroidGenAiPrecheckService();
  } catch (_) {
    // Platform not available (e.g. tests) — fall through to no-op.
  }
  return const NoopPrecheckService();
});

// ---- Session / gating -----------------------------------------------------

final appSessionProvider = Provider<AppSession>((ref) {
  final session = AppSession(
    auth: ref.watch(authRepositoryProvider),
    profiles: ref.watch(profileRepositoryProvider),
    purchases: ref.watch(purchasesServiceProvider),
  );
  ref.onDispose(session.dispose);
  return session;
});
