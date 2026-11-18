import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../domain/models/digest_window.dart';
import '../domain/models/managed_app.dart';
import '../domain/models/schedule_rule.dart';
import '../domain/models/temporary_override.dart';
import 'notification_platform_interface.dart';

/// Android implementation of [NotificationPlatformInterface] communicating via [MethodChannel].
class AndroidNotificationPlatform implements NotificationPlatformInterface {
  static const MethodChannel _channel =
      MethodChannel('com.notificationhandler/bridge');

  @override
  Future<bool> isPlatformSupported() async => true;

  @override
  Future<bool> isNotificationAccessGranted() async {
    try {
      final bool? granted =
          await _channel.invokeMethod<bool>('isNotificationAccessGranted');
      return granted ?? false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<void> openNotificationAccessSettings() async {
    try {
      await _channel.invokeMethod<void>('openNotificationAccessSettings');
    } on PlatformException {
      // Failed to open settings
    }
  }

  @override
  Future<void> openAppDetailsSettings() async {
    try {
      await _channel.invokeMethod<void>('openAppDetailsSettings');
    } on PlatformException {
      // Failed to open app details
    }
  }

  @override
  Future<List<DiscoveredAppInfo>> getInstalledApplications() async {
    try {
      final List<dynamic>? rawList =
          await _channel.invokeMethod<List<dynamic>>('getInstalledApplications');
      if (rawList == null) return [];

      return rawList.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return DiscoveredAppInfo(
          packageName: map['packageName'] as String,
          displayName: map['displayName'] as String,
          iconBytes: map['iconBytes'] as Uint8List?,
          isSystemApp: map['isSystemApp'] as bool? ?? false,
          androidCategory: map['category'] as int? ?? -1,
        );
      }).toList();
    } on PlatformException {
      return [];
    }
  }

  @override
  Future<List<DiscoveredAppInfo>> getInstalledAppsLite() async {
    try {
      final rawList =
          await _channel.invokeMethod<List<dynamic>>('getInstalledAppsLite');
      if (rawList == null) return [];
      return rawList.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return DiscoveredAppInfo(
          packageName: map['packageName'] as String,
          displayName: map['displayName'] as String,
          isSystemApp: map['isSystemApp'] as bool? ?? false,
          androidCategory: map['category'] as int? ?? -1,
        );
      }).toList();
    } on PlatformException {
      return [];
    }
  }

  @override
  Future<Map<String, Uint8List>> getAppIcons(List<String> packageNames) async {
    if (packageNames.isEmpty) return {};
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
          'getAppIcons', {'packageNames': packageNames});
      if (raw == null) return {};
      return {
        for (final e in raw.entries)
          if (e.value is Uint8List) e.key as String: e.value as Uint8List,
      };
    } on PlatformException {
      return {};
    }
  }

  @override
  Future<Map<String, bool>> getInstalledStatus(List<String> packageNames) async {
    if (packageNames.isEmpty) return {};
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
          'getInstalledStatus', {'packageNames': packageNames});
      if (raw == null) return {};
      return {
        for (final e in raw.entries)
          if (e.value is bool) e.key as String: e.value as bool,
      };
    } on PlatformException {
      return {};
    }
  }

  @override
  Future<PackageChanges?> getChangedPackages(int sequenceNumber) async {
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
          'getChangedPackages', {'sequenceNumber': sequenceNumber});
      if (raw == null) return null;
      return PackageChanges(
        sequenceNumber: (raw['sequenceNumber'] as num?)?.toInt() ?? sequenceNumber,
        packageNames: [
          for (final p in (raw['packageNames'] as List<dynamic>? ?? const []))
            p as String,
        ],
      );
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<void> syncSchedules({
    required List<ManagedApp> managedApps,
    required List<ScheduleRule> schedules,
    required List<TemporaryOverride> overrides,
    bool unmanagedAppsUntouched = true,
    bool vipEmergencyBypass = true,
  }) async {
    try {
      final payload = jsonEncode({
        'managedApps': managedApps.map((a) => a.toJson()).toList(),
        'schedules': schedules.map((s) => s.toJson()).toList(),
        'overrides': overrides.map((o) => o.toJson()).toList(),
        'unmanagedAppsUntouched': unmanagedAppsUntouched,
        'vipEmergencyBypass': vipEmergencyBypass,
      });

      await _channel.invokeMethod<void>('syncSchedules', {'payload': payload});
    } on PlatformException {
      // Log failure in debug mode
      // debugPrint('Failed to sync schedules to native layer: $e');
    }
  }

  @override
  Future<String?> exportBackupFile({
    required String fileName,
    required String content,
  }) async {
    try {
      final String? path = await _channel.invokeMethod<String>('exportBackupFile', {
        'fileName': fileName,
        'content': content,
      });
      return path;
    } on Exception {
      return null;
    }
  }

  @override
  Future<String?> pickBackupFile() async {
    try {
      final String? content = await _channel.invokeMethod<String>('pickBackupFile');
      return content;
    } on Exception {
      return null;
    }
  }

  static final Set<VoidCallback> _activityUpdatedListeners = {};
  static final Set<VoidCallback> _openDigestListeners = {};
  static bool _isMethodCallHandlerRegistered = false;

  static void _ensureMethodCallHandler() {
    if (_isMethodCallHandlerRegistered) return;
    _isMethodCallHandlerRegistered = true;
    _channel.setMethodCallHandler((call) async {
      final listeners = switch (call.method) {
        'onActivityUpdated' => _activityUpdatedListeners,
        'openDigest' => _openDigestListeners,
        _ => const <VoidCallback>{},
      };
      for (final l in List.of(listeners)) {
        l();
      }
    });
  }

  /// Registers a listener that is invoked whenever the native Android layer
  /// records or clears an activity log event in real time.
  static void addActivityUpdatedListener(VoidCallback listener) {
    _activityUpdatedListeners.add(listener);
    _ensureMethodCallHandler();
  }

  static void removeActivityUpdatedListener(VoidCallback listener) {
    _activityUpdatedListeners.remove(listener);
  }

  /// Registers a listener invoked when the catch-up notification is tapped
  /// while the app is already running.
  static void addOpenDigestListener(VoidCallback listener) {
    _openDigestListeners.add(listener);
    _ensureMethodCallHandler();
  }

  static void removeOpenDigestListener(VoidCallback listener) {
    _openDigestListeners.remove(listener);
  }

  /// Returns true once if the app was opened from the catch-up notification.
  static Future<bool> consumePendingDigestOpen() async {
    try {
      return await _channel.invokeMethod<bool>('consumePendingDigestOpen') ??
          false;
    } on Exception {
      return false;
    }
  }

  /// Catch-up digest notification settings, or null when unavailable.
  static Future<DigestNotificationSettings?> fetchDigestSettings() async {
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
          'getDigestSettings');
      if (raw == null) return null;
      return DigestNotificationSettings(
        enabled: raw['enabled'] as bool? ?? true,
        permissionGranted: raw['permissionGranted'] as bool? ?? false,
      );
    } on Exception {
      return null;
    }
  }

  static Future<void> setDigestEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod<void>('setDigestEnabled', {
        'enabled': enabled,
      });
    } on Exception {
      // Keep the previous native value.
    }
  }

  /// Asks for notification permission, or opens the app's notification
  /// settings when Android will no longer show the prompt. Returns whether
  /// Notiflow can post notifications now.
  static Future<bool> requestNotificationPermission() async {
    try {
      return await _channel
              .invokeMethod<bool>('requestNotificationPermission') ??
          false;
    } on Exception {
      return false;
    }
  }

  /// Tells Android which launch screen to show next time: 'light', 'dark'
  /// or 'system' (follow the phone).
  static Future<void> setAppThemeMode(String mode) async {
    try {
      await _channel.invokeMethod<void>('setAppThemeMode', {'mode': mode});
    } on Exception {
      // Not available on this platform.
    }
  }

  /// Asks for notification permission once per install or update.
  static Future<void> requestNotificationPermissionOnStartup() async {
    try {
      await _channel.invokeMethod<bool>('requestNotificationPermissionOnStartup');
    } on Exception {
      // Not available on this platform.
    }
  }

  /// Launches an installed application by its [packageName].
  static Future<bool> openApp(String packageName) async {
    try {
      final bool? launched = await _channel.invokeMethod<bool>(
        'openApp',
        {'packageName': packageName},
      );
      return launched ?? false;
    } on Exception {
      return false;
    }
  }

  /// Fetches the triage activity log JSON from the native Android store.
  static Future<List<Map<String, dynamic>>> fetchNativeActivityLog() async {
    try {
      final String? raw = await _channel.invokeMethod<String>('getActivityLog');
      if (raw == null || raw.isEmpty) return [];
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } on Exception {
      return [];
    }
  }

  /// Fetches ended Catch-Up Digest windows (newest first) from the native store.
  static Future<List<DigestWindow>> fetchDigest() async {
    try {
      final String? raw = await _channel.invokeMethod<String>('getDigest');
      if (raw == null || raw.isEmpty) return [];
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => DigestWindow.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on Exception {
      return [];
    }
  }

  /// Marks the given digest windows as reviewed.
  static Future<void> markDigestReviewed(List<int> windowIds) async {
    if (windowIds.isEmpty) return;
    try {
      await _channel.invokeMethod<void>('markDigestReviewed', {'ids': windowIds});
    } on Exception {
      // No-op when running in tests or non-Android platform
    }
  }

  /// Deletes single activity log entries (and their digest copies).
  static Future<void> deleteActivityEvents(List<String> ids) async {
    if (ids.isEmpty) return;
    try {
      await _channel.invokeMethod<void>('deleteActivityEvents', {'ids': ids});
    } on Exception {
      // No-op when running in tests or non-Android platform
    }
  }

  /// Deletes everything the given digest windows silenced.
  static Future<void> deleteDigestWindows(List<int> windowIds) async {
    if (windowIds.isEmpty) return;
    try {
      await _channel.invokeMethod<void>('deleteDigestWindows', {'ids': windowIds});
    } on Exception {
      // No-op when running in tests or non-Android platform
    }
  }

  /// Clears the native Android triage activity log.
  static Future<void> clearNativeActivityLog() async {
    try {
      await _channel.invokeMethod<void>('clearActivityLog');
    } on Exception {
      // No-op when running in tests or non-Android platform
    }
  }
}

class DigestNotificationSettings {
  const DigestNotificationSettings({
    required this.enabled,
    required this.permissionGranted,
  });

  final bool enabled;
  final bool permissionGranted;
}
