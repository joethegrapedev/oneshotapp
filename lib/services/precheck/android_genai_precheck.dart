import 'package:flutter/services.dart';

import 'on_device_precheck.dart';

/// Android on-device pre-check backed by ML Kit GenAI (Gemini Nano) via a
/// platform MethodChannel. Availability-gated: on devices without the on-device
/// model the native side returns `available == false` and we skip silently.
///
/// The native implementation lives under
/// `android/app/src/main/.../GenAiPrecheckPlugin` (see docs/on_device_precheck.md).
/// This is optional and advisory only — it is never a security boundary and the
/// app ships and works fully when it is unavailable.
class AndroidGenAiPrecheckService implements PrecheckService {
  AndroidGenAiPrecheckService();

  static const MethodChannel _channel =
      MethodChannel('oneshot/genai_precheck');

  bool? _availableCache;

  @override
  Future<bool> isAvailable() async {
    if (_availableCache != null) return _availableCache!;
    try {
      final available =
          await _channel.invokeMethod<bool>('isAvailable') ?? false;
      _availableCache = available;
      return available;
    } on PlatformException {
      _availableCache = false;
      return false;
    } on MissingPluginException {
      // Native plugin not registered on this build/platform.
      _availableCache = false;
      return false;
    }
  }

  @override
  Future<PrecheckResult> classify(String text) async {
    if (!await isAvailable()) return PrecheckResult.clear;
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'classify',
        {'text': text},
      );
      if (result == null) return PrecheckResult.clear;
      final tripped = result['tripped'] as bool? ?? false;
      final categories = (result['categories'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[];
      return PrecheckResult(tripped: tripped, categories: categories);
    } on PlatformException {
      // Any native failure degrades to "no warning" — advisory only.
      return PrecheckResult.clear;
    } on MissingPluginException {
      return PrecheckResult.clear;
    }
  }
}
