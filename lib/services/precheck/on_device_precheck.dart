/// Result of an optional, advisory on-device moderation pre-check.
/// This decides NOTHING — it only warns the user before they share. The
/// authoritative gate is the server edge function.
class PrecheckResult {
  const PrecheckResult({required this.tripped, this.categories = const []});
  final bool tripped;
  final List<String> categories;

  static const PrecheckResult clear = PrecheckResult(tripped: false);
}

/// Optional per-platform on-device classifier. Implementations MUST degrade
/// gracefully: if no on-device model is available, `isAvailable()` returns
/// false and callers skip the pre-check silently. Never a security boundary.
abstract class PrecheckService {
  Future<bool> isAvailable();
  Future<PrecheckResult> classify(String text);
}
