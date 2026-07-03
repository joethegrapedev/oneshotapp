import 'package:posthog_flutter/posthog_flutter.dart';

import '../core/env.dart';

/// Optional onboarding-funnel analytics. No-op when PostHog is not configured,
/// so the app runs identically without it. We only track anonymous funnel
/// events — never journal content.
abstract class AnalyticsService {
  void capture(String event, {Map<String, Object>? properties});
}

class PosthogAnalyticsService implements AnalyticsService {
  const PosthogAnalyticsService();

  @override
  void capture(String event, {Map<String, Object>? properties}) {
    if (!Env.isPosthogConfigured) return;
    // Fire-and-forget; never block UX and never throw into the caller.
    Posthog().capture(eventName: event, properties: properties).catchError(
      (_) {},
    );
  }
}

class NoopAnalyticsService implements AnalyticsService {
  const NoopAnalyticsService();
  @override
  void capture(String event, {Map<String, Object>? properties}) {}
}
