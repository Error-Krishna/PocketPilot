import 'package:flutter/services.dart';

/// Bridges to native Android battery-optimization exemption controls.
/// A foreground service (see SmsForegroundService.kt) is the correct,
/// Google-sanctioned way to keep SMS capture alive when the app is
/// closed, but aggressive OEM battery managers can still kill it. This
/// exemption is the extra layer that makes that maximally unlikely.
class BatteryOptimizationService {
  static const MethodChannel _channel =
      MethodChannel('com.udhyogsaathi.pocketpilot/sms_service');

  static Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      final result =
          await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations');
      return result ?? false;
    } catch (_) {
      // Non-Android platforms, or the call failing for any reason —
      // treat as "already fine" rather than nagging the user needlessly.
      return true;
    }
  }

  static Future<void> requestExemption() async {
    try {
      await _channel.invokeMethod('requestIgnoreBatteryOptimizations');
    } catch (_) {
      // Non-fatal — user can still navigate to battery settings manually.
    }
  }
}
