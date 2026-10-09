import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/engine/schedule_evaluator.dart';
import '../../domain/models/managed_app.dart';
import '../../domain/models/schedule_decision.dart';
import '../../domain/models/schedule_rule.dart';
import '../../domain/models/temporary_override.dart';
import '../../domain/models/rule_preset.dart';
import '../../platform/notification_platform_interface.dart';
import '../../platform/platform_factory.dart';

/// Central repository managing active applications, schedules, and overrides.
/// Extends [ChangeNotifier] for reactive Flutter UI state updates.
class ScheduleRepository extends ChangeNotifier {
  static const String _keyManagedApps = 'pref_managed_apps';
  static const String _keySchedules = 'pref_schedule_rules';
  static const String _keyOverrides = 'pref_temporary_overrides';
  static const String _keyUnmanagedUntouched = 'pref_unmanaged_untouched';
  static const String _keyVipBypass = 'pref_vip_bypass';
  static const String _keyDefaultScheduleMode = 'pref_default_schedule_mode';

  final NotificationPlatformInterface _platformService;
  final ScheduleEvaluator _evaluator;

  List<ManagedApp> _managedApps = [];
  List<ScheduleRule> _schedules = [];
  Map<String, TemporaryOverride> _overrides = {}; // appId -> override

  bool _unmanagedAppsUntouched = true;
  bool _vipEmergencyBypass = true;
  String _defaultScheduleMode = 'allow';
  bool _isInitialized = false;

  ScheduleRepository({
    NotificationPlatformInterface? platformService,
    this._evaluator = const ScheduleEvaluator(),
  })  : _platformService = platformService ?? PlatformFactory.createPlatformService();

  bool get isInitialized => _isInitialized;
  bool get unmanagedAppsUntouched => _unmanagedAppsUntouched;
  bool get vipEmergencyBypass => _vipEmergencyBypass;
  String get defaultScheduleMode => _defaultScheduleMode;
  List<ManagedApp> get managedApps => List.unmodifiable(_managedApps);
  List<ScheduleRule> get schedules => List.unmodifiable(_schedules);
  List<TemporaryOverride> get overrides => List.unmodifiable(_overrides.values);

  /// Initializes local storage and syncs active configuration with native Android layer.
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();

    final appsJson = prefs.getString(_keyManagedApps);
    if (appsJson != null) {
      final List<dynamic> decoded = jsonDecode(appsJson);
      _managedApps = decoded.map((e) => ManagedApp.fromJson(e as Map<String, dynamic>)).toList();
    }

    final rulesJson = prefs.getString(_keySchedules);
    if (rulesJson != null) {
      final List<dynamic> decoded = jsonDecode(rulesJson);
      _schedules = decoded.map((e) => ScheduleRule.fromJson(e as Map<String, dynamic>)).toList();
    }

    final overridesJson = prefs.getString(_keyOverrides);
    if (overridesJson != null) {
      final List<dynamic> decoded = jsonDecode(overridesJson);
      _overrides = {
        for (var o in decoded.map((e) => TemporaryOverride.fromJson(e as Map<String, dynamic>)))
          o.appId: o
      };
    }

    _unmanagedAppsUntouched = prefs.getBool(_keyUnmanagedUntouched) ?? true;
    _vipEmergencyBypass = prefs.getBool(_keyVipBypass) ?? true;
    _defaultScheduleMode = prefs.getString(_keyDefaultScheduleMode) ?? 'allow';

    _isInitialized = true;
    notifyListeners();

    await _syncToNative();
  }

  /// Updates whether unmanaged apps pass through untouched.
  Future<void> setUnmanagedAppsUntouched(bool value) async {
    _unmanagedAppsUntouched = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyUnmanagedUntouched, value);
    notifyListeners();
  }

  /// Updates emergency VIP bypass setting.
  Future<void> setVipEmergencyBypass(bool value) async {
    _vipEmergencyBypass = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyVipBypass, value);
    notifyListeners();
  }

  /// Updates default schedule mode for newly discovered apps.
  Future<void> setDefaultScheduleMode(String mode) async {
    _defaultScheduleMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDefaultScheduleMode, mode);
    notifyListeners();
  }

  /// Resets all managed apps, rules, and overrides.
  Future<void> resetAllRules() async {
    _managedApps.clear();
    _schedules.clear();
    _overrides.clear();
    await _persist();
  }

  /// Adds a new managed application.
  Future<void> addApp(ManagedApp app) async {
    _managedApps.removeWhere((a) => a.id == app.id || a.packageName == app.packageName);
    _managedApps.add(app);
    await _persist();
  }

  /// Helper to create and add a managed app from package details.
  Future<ManagedApp> addAppFromPackage({
    required String packageName,
    required String displayName,
    Uint8List? iconBytes,
    String? category,
  }) async {
    final now = DateTime.now();
    final app = ManagedApp(
      id: 'app_${packageName}_${now.millisecondsSinceEpoch}',
      packageName: packageName,
      displayName: displayName,
      iconBytes: iconBytes,
      category: category,
      enabled: true,
      createdAt: now,
      updatedAt: now,
    );
    await addApp(app);
    return app;
  }

  /// Removes an app and all its associated schedule rules and overrides.
  Future<void> removeApp(String appId) async {
    _managedApps.removeWhere((a) => a.id == appId);
    _schedules.removeWhere((r) => r.appId == appId);
    _overrides.remove(appId);
    await _persist();
  }

  /// Toggles whether scheduling is enabled for an application.
  Future<void> toggleAppEnabled(String appId, bool enabled) async {
    final index = _managedApps.indexWhere((a) => a.id == appId);
    if (index != -1) {
      _managedApps[index] = _managedApps[index].copyWith(
        enabled: enabled,
        updatedAt: DateTime.now(),
      );
      await _persist();
    }
  }

  /// Alias for toggleAppEnabled.
  Future<void> toggleApp(String appId, bool enabled) => toggleAppEnabled(appId, enabled);

  /// Alias for toggleAppEnabled (UI nomenclature).
  Future<void> toggleAppMonitoring(String appId, bool enabled) => toggleAppEnabled(appId, enabled);

  /// Gets all schedule rules configured for [appId].
  List<ScheduleRule> getRulesForApp(String appId) {
    return _schedules.where((r) => r.appId == appId).toList();
  }

  /// Gets the primary schedule rule configured for [appId], or null.
  ScheduleRule? getRuleForApp(String appId) {
    final rules = getRulesForApp(appId);
    return rules.isNotEmpty ? rules.first : null;
  }

  /// Adds or updates a schedule rule.
  Future<void> saveRule(ScheduleRule rule) async {
    final index = _schedules.indexWhere((r) => r.id == rule.id);
    if (index != -1) {
      _schedules[index] = rule;
    } else {
      _schedules.add(rule);
    }
    await _persist();
  }

  /// Deletes a specific schedule rule by [ruleId].
  /// If the associated app has no remaining rules, removes the app from managedApps.
  Future<void> deleteRule(String ruleId) async {
    final ruleIndex = _schedules.indexWhere((r) => r.id == ruleId);
    String? appId;
    if (ruleIndex != -1) {
      appId = _schedules[ruleIndex].appId;
      _schedules.removeAt(ruleIndex);
    }
    if (appId != null) {
      final hasOtherRules = _schedules.any((r) => r.appId == appId);
      if (!hasOtherRules) {
        _managedApps.removeWhere((a) => a.id == appId);
        _overrides.remove(appId);
      }
    }
    await _persist();
  }

  /// Batch deletes rules and monitoring for the given list of [appIds].
  Future<void> deleteAppsAndRules(List<String> appIds) async {
    final idSet = appIds.toSet();
    _managedApps.removeWhere((a) => idSet.contains(a.id));
    _schedules.removeWhere((r) => idSet.contains(r.appId));
    for (final id in idSet) {
      _overrides.remove(id);
    }
    await _persist();
  }

  /// Toggles whether a specific schedule rule is enabled.
  Future<void> toggleRuleEnabled(String ruleId, bool enabled) async {
    final index = _schedules.indexWhere((r) => r.id == ruleId);
    if (index != -1) {
      _schedules[index] = _schedules[index].copyWith(
        enabled: enabled,
        updatedAt: DateTime.now(),
      );
      await _persist();
    }
  }

  /// Sets a temporary override for an application.
  Future<void> setOverride(TemporaryOverride override) async {
    _overrides[override.appId] = override;
    await _persist();
  }

  /// Sets a temporary mute override for [appId] lasting [duration].
  Future<void> setTemporaryMute({required String appId, required Duration duration}) async {
    final now = DateTime.now();
    final override = TemporaryOverride(
      id: 'override_${now.millisecondsSinceEpoch}',
      appId: appId,
      mode: OverrideMode.block,
      startDateTime: now,
      endDateTime: now.add(duration),
      createdAt: now,
    );
    await setOverride(override);
  }

  /// Sets a temporary allow override for [appId] lasting [duration].
  Future<void> setTemporaryAllow({required String appId, required Duration duration}) async {
    final now = DateTime.now();
    final override = TemporaryOverride(
      id: 'override_${now.millisecondsSinceEpoch}',
      appId: appId,
      mode: OverrideMode.allow,
      startDateTime: now,
      endDateTime: now.add(duration),
      createdAt: now,
    );
    await setOverride(override);
  }

  /// Clears any active temporary override for [appId].
  Future<void> clearOverride(String appId) async {
    if (_overrides.remove(appId) != null) {
      await _persist();
    }
  }

  /// Gets any active temporary override for [appId].
  TemporaryOverride? getOverrideForApp(String appId) {
    final override = _overrides[appId];
    if (override == null) return null;
    if (override.endDateTime.isBefore(DateTime.now())) {
      // Expired
      _overrides.remove(appId);
      return null;
    }
    return override;
  }

  /// Evaluates the current state of an application.
  ScheduleDecision evaluateApp(ManagedApp app, [DateTime? targetDateTime]) {
    final dt = targetDateTime ?? DateTime.now();
    final override = getOverrideForApp(app.id);
    final appRules = getRulesForApp(app.id);
    return _evaluator.evaluate(
      app: app,
      schedules: appRules,
      override: override,
      currentDateTime: dt,
    );
  }

  /// Evaluates an application by its [appId].
  ScheduleDecision evaluateAppById(String appId, [DateTime? targetDateTime]) {
    final app = _managedApps.firstWhere(
      (a) => a.id == appId,
      orElse: () => ManagedApp(
        id: appId,
        packageName: '',
        displayName: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    return evaluateApp(app, targetDateTime);
  }

  /// Calculates counts of currently managed, blocked, and allowed apps.
  ({int total, int blocked, int allowed}) getSummary([DateTime? targetDateTime]) {
    final dt = targetDateTime ?? DateTime.now();
    int blockedCount = 0;
    int allowedCount = 0;

    for (final app in _managedApps) {
      if (!app.enabled) {
        allowedCount++;
        continue;
      }
      final decision = evaluateApp(app, dt);
      if (decision.isBlocked) {
        blockedCount++;
      } else {
        allowedCount++;
      }
    }

    return (total: _managedApps.length, blocked: blockedCount, allowed: allowedCount);
  }

  /// Exports active rules and managed applications as a formatted .notiflow JSON payload.
  String exportRulesJson() {
    final payload = {
      'app': 'Notiflow',
      'version': '1.4.0',
      'format': 'notiflow-backup-v1',
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'managedApps': _managedApps.map((a) => a.toJson()).toList(),
      'schedules': _schedules.map((r) => r.toJson()).toList(),
      'unmanagedAppsUntouched': _unmanagedAppsUntouched,
      'vipEmergencyBypass': _vipEmergencyBypass,
      'defaultScheduleMode': _defaultScheduleMode,
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Exports active rules to a local file and invokes system share sheet.
  Future<String?> exportRulesToFile() async {
    final jsonContent = exportRulesJson();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'notiflow_backup_$timestamp.notiflow';
    return await _platformService.exportBackupFile(
      fileName: fileName,
      content: jsonContent,
    );
  }

  /// Prompts user to pick a backup file and imports it.
  Future<bool> pickRulesFromFile({bool replaceAll = true}) async {
    final fileContent = await _platformService.pickBackupFile();
    if (fileContent != null && fileContent.isNotEmpty) {
      return await importRulesJson(fileContent, replaceAll: replaceAll);
    }
    return false;
  }

  /// Imports and validates a .notiflow JSON string.
  /// Returns true if rules were successfully restored.
  Future<bool> importRulesJson(String rawJson, {bool replaceAll = true}) async {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! Map<String, dynamic>) {
        return false;
      }

      final List<dynamic>? appsList = decoded['managedApps'] as List<dynamic>?;
      final List<dynamic>? schedulesList = decoded['schedules'] as List<dynamic>?;

      if (appsList == null && schedulesList == null) {
        return false;
      }

      final importedApps = appsList != null
          ? appsList.map((e) => ManagedApp.fromJson(e as Map<String, dynamic>)).toList()
          : <ManagedApp>[];

      final importedSchedules = schedulesList != null
          ? schedulesList.map((e) => ScheduleRule.fromJson(e as Map<String, dynamic>)).toList()
          : <ScheduleRule>[];

      if (replaceAll) {
        _managedApps = importedApps;
        _schedules = importedSchedules;
        _overrides.clear();
      } else {
        for (final app in importedApps) {
          if (!_managedApps.any((a) => a.id == app.id || a.packageName == app.packageName)) {
            _managedApps.add(app);
          }
        }
        for (final rule in importedSchedules) {
          if (!_schedules.any((r) => r.id == rule.id)) {
            _schedules.add(rule);
          }
        }
      }

      if (decoded.containsKey('unmanagedAppsUntouched')) {
        _unmanagedAppsUntouched = decoded['unmanagedAppsUntouched'] as bool? ?? true;
      }
      if (decoded.containsKey('vipEmergencyBypass')) {
        _vipEmergencyBypass = decoded['vipEmergencyBypass'] as bool? ?? true;
      }

      await _persist();
      return true;
    } catch (e) {
      debugPrint('Failed to parse and import .notiflow JSON: $e');
      return false;
    }
  }

  /// Applies a curated focus preset.
  Future<void> applyPreset(RulePreset preset, {bool replaceAll = false}) async {
    if (replaceAll) {
      _managedApps = List.from(preset.apps);
      _schedules = List.from(preset.schedules);
      _overrides.clear();
    } else {
      for (final app in preset.apps) {
        final existingIndex = _managedApps.indexWhere((a) => a.packageName == app.packageName);
        if (existingIndex >= 0) {
          _managedApps[existingIndex] = _managedApps[existingIndex].copyWith(enabled: true);
        } else {
          _managedApps.add(app);
        }
      }
      for (final schedule in preset.schedules) {
        if (!_schedules.any((s) => s.id == schedule.id)) {
          _schedules.add(schedule);
        }
      }
    }
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();

    final appsJson = jsonEncode(_managedApps.map((a) => a.toJson()).toList());
    await prefs.setString(_keyManagedApps, appsJson);

    final rulesJson = jsonEncode(_schedules.map((r) => r.toJson()).toList());
    await prefs.setString(_keySchedules, rulesJson);

    final overridesJson = jsonEncode(_overrides.values.map((o) => o.toJson()).toList());
    await prefs.setString(_keyOverrides, overridesJson);

    notifyListeners();
    await _syncToNative();
  }

  Future<void> _syncToNative() async {
    await _platformService.syncSchedules(
      managedApps: _managedApps,
      schedules: _schedules,
      overrides: _overrides.values.toList(),
    );
  }
}
