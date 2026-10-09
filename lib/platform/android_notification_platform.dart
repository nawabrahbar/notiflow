import 'dart:convert';
import 'package:flutter/services.dart';
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
        );
      }).toList();
    } on PlatformException {
      return [];
    }
  }

  @override
  Future<void> syncSchedules({
    required List<ManagedApp> managedApps,
    required List<ScheduleRule> schedules,
    required List<TemporaryOverride> overrides,
  }) async {
    try {
      final payload = jsonEncode({
        'managedApps': managedApps.map((a) => a.toJson()).toList(),
        'schedules': schedules.map((s) => s.toJson()).toList(),
        'overrides': overrides.map((o) => o.toJson()).toList(),
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
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<String?> pickBackupFile() async {
    try {
      final String? content = await _channel.invokeMethod<String>('pickBackupFile');
      return content;
    } on PlatformException {
      return null;
    }
  }
}
