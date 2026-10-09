import 'package:flutter_test/flutter_test.dart';
import 'package:notification_handler/data/repositories/schedule_repository.dart';
import 'package:notification_handler/domain/models/managed_app.dart';
import 'package:notification_handler/domain/models/schedule_rule.dart';
import 'package:notification_handler/domain/models/temporary_override.dart';
import 'package:notification_handler/platform/notification_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockPlatformService implements NotificationPlatformInterface {
  bool syncCalled = false;
  List<ManagedApp> lastSyncedApps = [];
  List<ScheduleRule> lastSyncedRules = [];

  @override
  Future<bool> isPlatformSupported() async => true;

  @override
  Future<bool> isNotificationAccessGranted() async => true;

  @override
  Future<void> openNotificationAccessSettings() async {}

  @override
  Future<void> openAppDetailsSettings() async {}

  @override
  Future<List<DiscoveredAppInfo>> getInstalledApplications() async => [];

  @override
  Future<void> syncSchedules({
    required List<ManagedApp> managedApps,
    required List<ScheduleRule> schedules,
    required List<TemporaryOverride> overrides,
  }) async {
    syncCalled = true;
    lastSyncedApps = managedApps;
    lastSyncedRules = schedules;
  }

  @override
  Future<String?> exportBackupFile({
    required String fileName,
    required String content,
  }) async => '/mock/path/$fileName';

  @override
  Future<String?> pickBackupFile() async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockPlatformService mockPlatform;
  late ScheduleRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    mockPlatform = MockPlatformService();
    repository = ScheduleRepository(platformService: mockPlatform);
    await repository.initialize();
  });

  test('Add app persists and notifies native layer', () async {
    final app = ManagedApp(
      id: 'app_1',
      packageName: 'com.example.app',
      displayName: 'Example App',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await repository.addApp(app);

    expect(repository.managedApps.length, 1);
    expect(repository.managedApps.first.packageName, 'com.example.app');
    expect(mockPlatform.syncCalled, true);
    expect(mockPlatform.lastSyncedApps.length, 1);
  });

  test('Save and delete schedule rules', () async {
    final rule = ScheduleRule(
      id: 'rule_1',
      appId: 'app_1',
      mode: ScheduleMode.allowDuring,
      startTime: const TimeOfDayValue(hour: 9, minute: 0),
      endTime: const TimeOfDayValue(hour: 17, minute: 0),
      daysOfWeek: {1, 2, 3, 4, 5},
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await repository.saveRule(rule);
    expect(repository.schedules.length, 1);

    await repository.deleteRule(rule.id);
    expect(repository.schedules.length, 0);
  });

  test('Temporary overrides take precedence in evaluateApp', () async {
    final app = ManagedApp(
      id: 'app_1',
      packageName: 'com.example.app',
      displayName: 'Example App',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await repository.addApp(app);

    // Rule: Allow 18:00 - 22:00
    final rule = ScheduleRule(
      id: 'rule_1',
      appId: app.id,
      mode: ScheduleMode.allowDuring,
      startTime: const TimeOfDayValue(hour: 18, minute: 0),
      endTime: const TimeOfDayValue(hour: 22, minute: 0),
      daysOfWeek: {1, 2, 3, 4, 5, 6, 7},
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await repository.saveRule(rule);

    // At 14:00 (normally blocked)
    final dt = DateTime(2026, 10, 5, 14, 0);
    expect(repository.evaluateApp(app, dt).isBlocked, true);

    // Add allow override
    await repository.setOverride(TemporaryOverride(
      id: 'ov_1',
      appId: app.id,
      mode: OverrideMode.allow,
      startDateTime: DateTime(2026, 10, 5, 13, 0),
      endDateTime: DateTime(2026, 10, 5, 15, 0),
      createdAt: DateTime(2026, 10, 5, 13, 0),
    ));

    expect(repository.evaluateApp(app, dt).isAllowed, true);
  });

  test('Triage preferences toggles and persistence', () async {
    expect(repository.unmanagedAppsUntouched, true);
    expect(repository.vipEmergencyBypass, true);
    expect(repository.defaultScheduleMode, 'allow');

    await repository.setUnmanagedAppsUntouched(false);
    expect(repository.unmanagedAppsUntouched, false);

    await repository.setVipEmergencyBypass(false);
    expect(repository.vipEmergencyBypass, false);

    await repository.setDefaultScheduleMode('block');
    expect(repository.defaultScheduleMode, 'block');
  });

  test('Reset all rules clears apps, schedules, and overrides and syncs native layer', () async {
    final app = ManagedApp(
      id: 'app_1',
      packageName: 'com.example.app',
      displayName: 'Example App',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await repository.addApp(app);
    await repository.saveRule(ScheduleRule(
      id: 'rule_1',
      appId: app.id,
      mode: ScheduleMode.allowDuring,
      startTime: const TimeOfDayValue(hour: 9, minute: 0),
      endTime: const TimeOfDayValue(hour: 17, minute: 0),
      daysOfWeek: {1, 2, 3, 4, 5},
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));

    expect(repository.managedApps.length, 1);
    expect(repository.schedules.length, 1);

    await repository.resetAllRules();

    expect(repository.managedApps.length, 0);
    expect(repository.schedules.length, 0);
    expect(repository.overrides.length, 0);
    expect(mockPlatform.syncCalled, true);
    expect(mockPlatform.lastSyncedApps.isEmpty, true);
  });
}
