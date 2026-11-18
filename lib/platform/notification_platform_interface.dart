import 'dart:typed_data';
import '../domain/models/managed_app.dart';
import '../domain/models/schedule_rule.dart';
import '../domain/models/temporary_override.dart';

/// Platform-neutral contract for interacting with native notification capabilities.
abstract class NotificationPlatformInterface {
  /// Whether the current platform technically supports third-party notification scheduling.
  /// True on Android, False on iOS.
  Future<bool> isPlatformSupported();

  /// Checks whether the user has granted system-level Notification Access.
  Future<bool> isNotificationAccessGranted();

  /// Directs the user to the system settings screen to enable Notification Access.
  Future<void> openNotificationAccessSettings();

  /// Directs the user to the application's App Info settings screen to allow restricted settings (Android 13+).
  Future<void> openAppDetailsSettings();

  /// Discovers installed launcher applications on the device, with icons (slow).
  Future<List<DiscoveredAppInfo>> getInstalledApplications();

  /// Installed launcher applications without icons (fast). Icons come from [getAppIcons].
  Future<List<DiscoveredAppInfo>> getInstalledAppsLite();

  /// Launcher icons for just [packageNames]; packages without an icon are omitted.
  Future<Map<String, Uint8List>> getAppIcons(List<String> packageNames);

  /// Whether each package is installed. An empty map means "unknown".
  Future<Map<String, bool>> getInstalledStatus(List<String> packageNames);

  /// Packages installed, updated or removed since [sequenceNumber], or null when
  /// the platform cannot tell.
  Future<PackageChanges?> getChangedPackages(int sequenceNumber);

  /// Synchronizes active managed apps, schedule rules, and temporary overrides
  /// to the native background persistence layer.
  Future<void> syncSchedules({
    required List<ManagedApp> managedApps,
    required List<ScheduleRule> schedules,
    required List<TemporaryOverride> overrides,
    bool unmanagedAppsUntouched = true,
    bool vipEmergencyBypass = true,
  });

  /// Exports a .notiflow backup file to local device storage and invokes share sheet.
  /// Returns the path of the saved file if successful.
  Future<String?> exportBackupFile({
    required String fileName,
    required String content,
  }) async => null;

  /// Prompts user to pick a .notiflow backup file and returns its content.
  Future<String?> pickBackupFile() async => null;
}

/// Represents an application discovered on the device.
class DiscoveredAppInfo {
  final String packageName;
  final String displayName;
  final Uint8List? iconBytes;
  final bool isSystemApp;

  const DiscoveredAppInfo({
    required this.packageName,
    required this.displayName,
    this.iconBytes,
    this.isSystemApp = false,
  });
}

/// Packages changed since a sequence number, plus the new sequence number to use next time.
class PackageChanges {
  final int sequenceNumber;
  final List<String> packageNames;

  const PackageChanges({
    required this.sequenceNumber,
    this.packageNames = const [],
  });
}
