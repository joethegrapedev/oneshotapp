import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/env.dart';
import 'core/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Env.isSupabaseConfigured) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );
  } else {
    // Fail loudly in debug; in release the app can't function without backend.
    debugPrint(
      'WARNING: Supabase is not configured. Pass --dart-define=SUPABASE_URL '
      'and --dart-define=SUPABASE_ANON_KEY. See README.',
    );
  }

  final container = ProviderContainer();

  // Bring up session gates before the first frame so the router routes cleanly.
  if (Env.isSupabaseConfigured) {
    try {
      await container.read(appSessionProvider).bootstrap();
    } catch (e) {
      debugPrint('Bootstrap failed: $e');
    }
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const OneShotApp(),
    ),
  );
}
