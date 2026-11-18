import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:notification_handler/data/repositories/schedule_repository.dart';
import 'package:notification_handler/domain/models/managed_app.dart';
import 'package:notification_handler/domain/models/rule_template.dart';
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
  Future<List<DiscoveredAppInfo>> getInstalledAppsLite() async => [];

  @override
  Future<Map<String, Uint8List>> getAppIcons(List<String> packageNames) async => {};

  @override
  Future<Map<String, bool>> getInstalledStatus(List<String> packageNames) async => {};

  @override
  Future<PackageChanges?> getChangedPackages(int sequenceNumber) async => null;

  bool lastUnmanagedAppsUntouched = true;
  bool lastVipEmergencyBypass = true;

  @override
  Future<void> syncSchedules({
    required List<ManagedApp> managedApps,
    required List<ScheduleRule> schedules,
    required List<TemporaryOverride> overrides,
    bool unmanagedAppsUntouched = true,
    bool vipEmergencyBypass = true,
  }) async {
    syncCalled = true;
    lastSyncedApps = managedApps;
    lastSyncedRules = schedules;
    lastUnmanagedAppsUntouched = unmanagedAppsUntouched;
    lastVipEmergencyBypass = vipEmergencyBypass;
  }

  String? lastExportedFileName;
  String? lastExportedContent;
  String? mockPickedFileContent;

  @override
  Future<String?> exportBackupFile({
    required String fileName,
    required String content,
  }) async {
    lastExportedFileName = fileName;
    lastExportedContent = content;
    return fileName;
  }

  @override
  Future<String?> pickBackupFile() async => mockPickedFileContent;
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

  test('Global overrides (global_mute and global_allow) apply to all managed apps', () async {
    final app = ManagedApp(
      id: 'app_1',
      packageName: 'com.example.app',
      displayName: 'Example App',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await repository.addApp(app);

    await repository.setTemporaryMute(
      appId: 'global_mute',
      duration: const Duration(minutes: 15),
    );
    expect(repository.evaluateApp(app).isBlocked, true);

    await repository.setTemporaryAllow(
      appId: 'global_allow',
      duration: const Duration(minutes: 15),
    );
    expect(repository.evaluateApp(app).isAllowed, true);
    expect(repository.overrides.length, 1);

    await repository.clearOverride('global_allow');
    expect(repository.overrides.isEmpty, true);
  });

  test('Exported .notiflow backup file is accepted and restored by pickRulesFromFile', () async {
    final app = ManagedApp(
      id: 'app_export_1',
      packageName: 'com.slack',
      displayName: 'Slack',
      createdAt: DateTime(2026, 10, 5, 10, 0),
      updatedAt: DateTime(2026, 10, 5, 10, 0),
    );
    await repository.addApp(app);
    await repository.saveRule(ScheduleRule(
      id: 'rule_export_1',
      appId: app.id,
      name: 'Work Focus',
      mode: ScheduleMode.blockDuring,
      startTime: const TimeOfDayValue(hour: 9, minute: 0),
      endTime: const TimeOfDayValue(hour: 17, minute: 0),
      daysOfWeek: {1, 2, 3, 4, 5},
      createdAt: DateTime(2026, 10, 5, 10, 0),
      updatedAt: DateTime(2026, 10, 5, 10, 0),
    ));
    await repository.setDefaultScheduleMode('block');

    final exportedFileName = await repository.exportRulesToFile();
    expect(exportedFileName, isNotNull);
    expect(exportedFileName!.endsWith('.notiflow'), true);
    expect(mockPlatform.lastExportedContent, isNotNull);

    // Clear repository and restore from the exported .notiflow file content
    await repository.resetAllRules();
    await repository.setDefaultScheduleMode('allow');
    expect(repository.managedApps, isEmpty);
    expect(repository.schedules, isEmpty);

    mockPlatform.mockPickedFileContent = mockPlatform.lastExportedContent;
    final imported = await repository.pickRulesFromFile();
    expect(imported, true);
    expect(repository.managedApps.length, 1);
    expect(repository.managedApps.first.packageName, 'com.slack');
    expect(repository.schedules.length, 1);
    expect(repository.schedules.first.name, 'Work Focus');
    expect(repository.defaultScheduleMode, 'block');
  });

  test('Triage preferences sync to native platform service', () async {
    await repository.setUnmanagedAppsUntouched(false);
    expect(mockPlatform.lastUnmanagedAppsUntouched, false);

    await repository.setVipEmergencyBypass(false);
    expect(mockPlatform.lastVipEmergencyBypass, false);
  });

  test('importRulesJson rejects malformed JSON with out-of-range hours or daysOfWeek', () async {
    const badHourJson = '''
    {
      "managedApps": [],
      "schedules": [
        {
          "id": "bad_rule",
          "appId": "app_1",
          "mode": "blockDuring",
          "startTime": {"hour": 99, "minute": 0},
          "endTime": {"hour": 17, "minute": 0},
          "daysOfWeek": [1, 2, 3],
          "createdAt": "2026-10-05T10:00:00.000",
          "updatedAt": "2026-10-05T10:00:00.000"
        }
      ]
    }
    ''';
    expect(await repository.importRulesJson(badHourJson), false);

    const badDaysJson = '''
    {
      "managedApps": [],
      "schedules": [
        {
          "id": "bad_rule_2",
          "appId": "app_1",
          "mode": "blockDuring",
          "startTime": {"hour": 9, "minute": 0},
          "endTime": {"hour": 17, "minute": 0},
          "daysOfWeek": [0, 8],
          "createdAt": "2026-10-05T10:00:00.000",
          "updatedAt": "2026-10-05T10:00:00.000"
        }
      ]
    }
    ''';
    expect(await repository.importRulesJson(badDaysJson), false);
  });

  test('Legacy "Work Focus Hours" default is renamed; a custom default name is kept', () async {
    final legacy = RuleTemplate.defaultWorkFocus.copyWith(name: 'Work Focus Hours');
    SharedPreferences.setMockInitialValues({
      'pref_rule_templates': jsonEncode([legacy.toJson()]),
    });
    final migrated = ScheduleRepository(platformService: mockPlatform);
    await migrated.initialize();
    expect(migrated.ruleTemplates.single.name, 'Focus Hours');

    final custom = RuleTemplate.defaultWorkFocus.copyWith(name: 'Office');
    SharedPreferences.setMockInitialValues({
      'pref_rule_templates': jsonEncode([custom.toJson()]),
    });
    final kept = ScheduleRepository(platformService: mockPlatform);
    await kept.initialize();
    expect(kept.ruleTemplates.single.name, 'Office');
  });

  test('updateRuleTemplate edits a saved rule but never the default', () async {
    final now = DateTime.now();
    final template = RuleTemplate(
      id: 'template_custom',
      name: 'Night',
      mode: ScheduleMode.blockDuring,
      startTime: const TimeOfDayValue(hour: 22, minute: 0),
      endTime: const TimeOfDayValue(hour: 6, minute: 0),
      daysOfWeek: const {1, 2, 3},
      createdAt: now,
    );
    await repository.saveRuleTemplate(template);

    final edited = template.copyWith(
      name: '  Late Night  ',
      mode: ScheduleMode.allowDuring,
      startTime: const TimeOfDayValue(hour: 23, minute: 30),
      daysOfWeek: const {6, 7},
      allowVipContacts: false,
    );
    expect(await repository.updateRuleTemplate(edited), isTrue);
    final saved = repository.ruleTemplates.firstWhere((t) => t.id == template.id);
    expect(saved.name, 'Late Night');
    expect(saved.mode, ScheduleMode.allowDuring);
    expect(saved.startTime.hour, 23);
    expect(saved.startTime.minute, 30);
    expect(saved.daysOfWeek, {6, 7});
    expect(saved.allowVipContacts, isFalse);

    expect(await repository.updateRuleTemplate(edited.copyWith(name: '  ')), isFalse);
    expect(
      await repository.updateRuleTemplate(
        RuleTemplate.defaultWorkFocus.copyWith(daysOfWeek: const {7}),
      ),
      isFalse,
    );
    expect(repository.ruleTemplates.first.daysOfWeek, {1, 2, 3, 4, 5});

    final asDefault = edited.copyWith(
      mode: RuleTemplate.defaultWorkFocus.mode,
      startTime: RuleTemplate.defaultWorkFocus.startTime,
      endTime: RuleTemplate.defaultWorkFocus.endTime,
      daysOfWeek: RuleTemplate.defaultWorkFocus.daysOfWeek,
    );
    expect(repository.findDuplicateTemplate(asDefault)?.id, RuleTemplate.defaultWorkFocus.id);
    expect(repository.findDuplicateTemplate(saved), isNull);
  });
}
