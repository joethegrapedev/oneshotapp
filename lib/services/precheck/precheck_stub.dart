import 'on_device_precheck.dart';

/// Default pre-check used when no on-device model is wired or available.
/// Always reports "unavailable" so the UX silently skips the advisory step.
/// This is what runs on a device with no on-device model — no crash, no gate.
class NoopPrecheckService implements PrecheckService {
  const NoopPrecheckService();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<PrecheckResult> classify(String text) async => PrecheckResult.clear;
}
