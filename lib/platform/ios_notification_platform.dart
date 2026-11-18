import 'dart:typed_data';
import '../domain/models/managed_app.dart';
import '../domain/models/schedule_rule.dart';
import '../domain/models/temporary_override.dart';
import 'notification_platform_interface.dart';

/// iOS implementation of [NotificationPlatformInterface].
///
/// In strict accordance with platform privacy architecture, Apple does not
/// provide public APIs for intercepting or canceling arbitrary third-party
/// app notifications. This implementation honestly reports unsupported status.
class IosNotificationPlatform implements NotificationPlatformInterface {
  @override
  Future<bool> isPlatformSupported() async => false;

  @override
  Future<bool> isNotificationAccessGranted() async => false;

  @override
  Future<void> openNotificationAccessSettings() async {
    // No-op on iOS
  }

  @override
  Future<void> openAppDetailsSettings() async {
    // No-op on iOS
  }

  @override
  Future<List<DiscoveredAppInfo>> getInstalledApplications() async => [];

  @override
  Future<List<DiscoveredAppInfo>> getInstalledAppsLite() async => [];

  @override
  Future<Map<String, Uint8List>> getAppIcons(List<String> packageNames) async =>
      {};

  @override
  Future<Map<String, bool>> getInstalledStatus(List<String> packageNames) async =>
      {};

  @override
  Future<PackageChanges?> getChangedPackages(int sequenceNumber) async => null;

  @override
  Future<void> syncSchedules({
    required List<ManagedApp> managedApps,
    required List<ScheduleRule> schedules,
    required List<TemporaryOverride> overrides,
    bool unmanagedAppsUntouched = true,
    bool vipEmergencyBypass = true,
  }) async {
    // No-op on iOS
  }

  @override
  Future<String?> exportBackupFile({
    required String fileName,
    required String content,
  }) async => null;

  @override
  Future<String?> pickBackupFile() async => null;
}
