import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/app_session.dart';
import 'core/providers.dart';
import 'core/theme.dart';
import 'features/crisis/crisis_screen.dart';
import 'features/journal/journal_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/paywall/paywall_screen.dart';
import 'features/read/read_back_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/write/write_screen.dart';

class OneShotApp extends ConsumerStatefulWidget {
  const OneShotApp({super.key});

  @override
  ConsumerState<OneShotApp> createState() => _OneShotAppState();
}

class _OneShotAppState extends ConsumerState<OneShotApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final session = ref.read(appSessionProvider);
    _router = _buildRouter(session);
  }

  GoRouter _buildRouter(AppSession session) {
    return GoRouter(
      initialLocation: '/journal',
      refreshListenable: session,
      redirect: (context, state) {
        final loc = state.matchedLocation;
        // Crisis screen is always reachable (safety), even mid-onboarding.
        if (loc == '/crisis') return null;

        if (!session.signedIn) return '/';
        if (!session.onboarded) return loc == '/' ? null : '/';
        if (!session.entitled) return loc == '/paywall' ? null : '/paywall';

        // Fully gated in: keep users out of onboarding/paywall.
        if (loc == '/' || loc == '/paywall') return '/journal';
        return null;
      },
      routes: [
        GoRoute(
          path: '/',
          name: 'onboarding',
          builder: (_, __) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/paywall',
          name: 'paywall',
          builder: (_, __) => const PaywallScreen(),
        ),
        GoRoute(
          path: '/journal',
          name: 'journal',
          builder: (_, __) => const JournalScreen(),
        ),
        GoRoute(
          path: '/write',
          name: 'write',
          builder: (_, __) => const WriteScreen(),
        ),
        GoRoute(
          path: '/read',
          name: 'read',
          builder: (_, __) => const ReadBackScreen(),
        ),
        GoRoute(
          path: '/crisis',
          name: 'crisis',
          builder: (_, __) => const CrisisScreen(),
        ),
        GoRoute(
          path: '/settings',
          name: 'settings',
          builder: (_, __) => const SettingsScreen(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'One Shot',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: _router,
    );
  }
}
