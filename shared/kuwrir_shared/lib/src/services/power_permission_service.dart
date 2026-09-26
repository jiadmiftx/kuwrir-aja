import 'package:flutter/services.dart';

/// Wraps the `cocourir/power` platform channel each app's MainActivity.kt
/// implements natively (Android only) — Battery-optimization exemption and
/// the Android 14+ full-screen-intent permission both have real OS APIs to
/// check/request; OEM "autostart"/"protected app" allow-listing (MIUI,
/// ColorOS, Vivo, EMUI, etc.) has none, so [openAutostartSettings] is
/// best-effort and always reports success once it lands somewhere useful —
/// there's no way to verify the user actually toggled it.
///
/// All methods no-op safely (return `true`/permissive defaults) on iOS or
/// any platform without a MainActivity handler, so call sites don't need to
/// guard by platform themselves.
class PowerPermissionService {
  static const _channel = MethodChannel('cocourir/power');

  static Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      return await _channel.invokeMethod<bool>(
            'isIgnoringBatteryOptimizations',
          ) ??
          true;
    } catch (_) {
      return true;
    }
  }

  /// Opens the system dialog that lets the user exempt this app from
  /// battery optimization directly — no need to navigate Settings manually.
  static Future<void> requestIgnoreBatteryOptimizations() async {
    try {
      await _channel.invokeMethod('requestIgnoreBatteryOptimizations');
    } catch (_) {}
  }

  /// Android 14+ only; always `true` on older Android/iOS since the
  /// permission model didn't exist before API 34.
  static Future<bool> canUseFullScreenIntent() async {
    try {
      return await _channel.invokeMethod<bool>('canUseFullScreenIntent') ??
          true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> requestFullScreenIntentPermission() async {
    try {
      await _channel.invokeMethod('requestFullScreenIntentPermission');
    } catch (_) {}
  }

  /// Best-effort: tries a known settings screen for the device's
  /// manufacturer, falling back to this app's own App Info page so the user
  /// can navigate to battery/autostart settings manually either way.
  static Future<void> openAutostartSettings() async {
    try {
      await _channel.invokeMethod('openAutostartSettings');
    } catch (_) {}
  }
}
