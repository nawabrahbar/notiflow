import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/engine/schedule_evaluator.dart';
import '../../domain/models/managed_app.dart';
import '../../domain/models/schedule_decision.dart';
import '../../domain/models/schedule_rule.dart';
import '../../domain/models/temporary_override.dart';
import '../../domain/models/rule_preset.dart';
import '../../domain/models/rule_template.dart';
import '../../platform/android_notification_platform.dart';
import '../../platform/notification_platform_interface.dart';
import '../../platform/platform_factory.dart';

/// Central repository managing active applications, schedules, saved templates, and overrides.
/// Extends [ChangeNotifier] for reactive Flutter UI state updates.
class ScheduleRepository extends ChangeNotifier {
  static const String _keyManagedApps = 'pref_managed_apps';
  static const String _keySchedules = 'pref_schedule_rules';
  static const String _keyRuleTemplates = 'pref_rule_templates';
  static const String _keyOverrides = 'pref_temporary_overrides';
  static const String _keyUnmanagedUntouched = 'pref_unmanaged_untouched';
  static const String _keyVipBypass = 'pref_vip_bypass';
  static const String _keyDefaultScheduleMode = 'pref_default_schedule_mode';
  static const String _keyUse24HourFormat = 'pref_use_24_hour_format';

  final NotificationPlatformInterface _platformService;
  final ScheduleEvaluator _evaluator;

  List<ManagedApp> _managedApps = [];
  List<ScheduleRule> _schedules = [];
  List<RuleTemplate> _ruleTemplates = [];
  Map<String, TemporaryOverride> _overrides = {}; // appId -> override

  bool _unmanagedAppsUntouched = true;
  bool _vipEmergencyBypass = true;
  String _defaultScheduleMode = 'allow';
  bool _use24HourFormat = false;
  bool _isInitialized = false;

  ScheduleRepository({
    NotificationPlatformInterface? platformService,
    this._evaluator = const ScheduleEvaluator(),
  })  : _platformService = platformService ?? PlatformFactory.createPlatformService();

  bool get isInitialized => _isInitialized;
  bool get unmanagedAppsUntouched => _unmanagedAppsUntouched;
  bool get vipEmergencyBypass => _vipEmergencyBypass;
  String get defaultScheduleMode => _defaultScheduleMode;
  bool get use24HourFormat => _use24HourFormat;
  List<ManagedApp> get managedApps =>
      List.unmodifiable(_managedApps.where((a) => !a.isDormantVault));
  List<ManagedApp> get allManagedApps => List.unmodifiable(_managedApps);
  List<ManagedApp> get dormantVaultApps =>
      List.unmodifiable(_managedApps.where((a) => a.isDormantVault));
  List<ScheduleRule> get schedules => List.unmodifiable(_schedules);
  List<RuleTemplate> get ruleTemplates => List.unmodifiable(_ruleTemplates);
  List<RuleTemplate> get savedTemplates => ruleTemplates;

  /// Formats a [TimeOfDayValue] adhering to the user's 12h or 24h preference.
  String formatTime(TimeOfDayValue time) {
    return _use24HourFormat ? time.format24Hour() : time.format12Hour();
  }

  /// Formats raw hour and minute adhering to the user's 12h or 24h preference.
  String formatTimeOfDay(int hour, int minute) {
    return formatTime(TimeOfDayValue(hour: hour, minute: minute));
  }

  List<TemporaryOverride> get overrides {
    final now = DateTime.now();
    _overrides.removeWhere((_, o) => !o.endDateTime.isAfter(now));
    return List.unmodifiable(_overrides.values);
  }

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

    final templatesJson = prefs.getString(_keyRuleTemplates);
    if (templatesJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(templatesJson);
        _ruleTemplates = decoded
            .map((e) => RuleTemplate.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } catch (e) {
        debugPrint('Failed to decode saved rule templates: $e');
        _ruleTemplates = [RuleTemplate.defaultWorkFocus];
      }
    }

    // Ensure the pre-seeded default template (Work Focus Hours 9am-5pm Mon-Fri) is always present
    if (_ruleTemplates.isEmpty ||
        !_ruleTemplates.any((t) => t.id == RuleTemplate.defaultWorkFocus.id)) {
      _ruleTemplates.insert(0, RuleTemplate.defaultWorkFocus);
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
    _use24HourFormat = prefs.getBool(_keyUse24HourFormat) ?? false;

    await checkAndActivateDormantApps(notify: false);

    _isInitialized = true;
    notifyListeners();

    await _syncToNative();
  }

  /// Updates whether 24-hour time format is used across the app.
  Future<void> setUse24HourFormat(bool value) async {
    _use24HourFormat = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyUse24HourFormat, value);
    notifyListeners();
  }

  /// Updates whether unmanaged apps pass through untouched.
  Future<void> setUnmanagedAppsUntouched(bool value) async {
    _unmanagedAppsUntouched = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyUnmanagedUntouched, value);
    notifyListeners();
    await _syncToNative();
  }

  /// Updates emergency VIP bypass setting.
  Future<void> setVipEmergencyBypass(bool value) async {
    _vipEmergencyBypass = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyVipBypass, value);
    notifyListeners();
    await _syncToNative();
  }

  /// Updates default schedule mode for newly discovered apps.
  Future<void> setDefaultScheduleMode(String mode) async {
    _defaultScheduleMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDefaultScheduleMode, mode);
    notifyListeners();
  }

  /// Resets all managed apps, rules, overrides, and native activity logs.
  Future<void> resetAllRules() async {
    _managedApps.clear();
    _schedules.clear();
    _overrides.clear();
    _ruleTemplates = [RuleTemplate.defaultWorkFocus];
    await AndroidNotificationPlatform.clearNativeActivityLog();
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

  /// Adds or updates a schedule rule, and automatically evaluates caching it as a saved template.
  Future<void> saveRule(ScheduleRule rule, {bool autoSaveTemplate = true}) async {
    final index = _schedules.indexWhere((r) => r.id == rule.id);
    if (index != -1) {
      _schedules[index] = rule;
    } else {
      _schedules.add(rule);
    }

    if (autoSaveTemplate) {
      _maybeCacheRuleAsTemplate(rule);
    }

    await _persist();
  }

  /// Saves a new rule template with deduplication.
  /// If a template with matching mode, start time, end time, and days already exists,
  /// returns the existing template. Otherwise adds and persists the new template.
  Future<RuleTemplate> saveRuleTemplate(RuleTemplate template) async {
    final existingIndex = _ruleTemplates.indexWhere((t) =>
        t.id == template.id ||
        t.matchesConfiguration(
          targetMode: template.mode,
          targetStartTime: template.startTime,
          targetEndTime: template.endTime,
          targetDaysOfWeek: template.daysOfWeek,
        ));

    if (existingIndex != -1) {
      return _ruleTemplates[existingIndex];
    }

    _ruleTemplates.add(template);
    await _persist();
    return template;
  }

  /// Helper to cache a custom schedule rule into saved templates if not already present.
  bool _maybeCacheRuleAsTemplate(ScheduleRule rule) {
    final isDuplicate = _ruleTemplates.any((t) => t.matchesConfiguration(
          targetMode: rule.mode,
          targetStartTime: rule.startTime,
          targetEndTime: rule.endTime,
          targetDaysOfWeek: rule.daysOfWeek,
        ));

    if (isDuplicate) {
      return false;
    }

    final String name = (rule.name != null && rule.name!.trim().isNotEmpty)
        ? rule.name!.trim()
        : '${rule.startTime.format12Hour()} - ${rule.endTime.format12Hour()}';

    final newTemplate = RuleTemplate(
      id: 'template_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      mode: rule.mode,
      startTime: rule.startTime,
      endTime: rule.endTime,
      daysOfWeek: rule.daysOfWeek,
      allowVipContacts: rule.allowVipContacts,
      createdAt: DateTime.now(),
    );

    _ruleTemplates.add(newTemplate);
    return true;
  }

  /// Deletes a custom rule template by [templateId] (cannot delete pre-seeded default).
  Future<void> deleteRuleTemplate(String templateId) async {
    if (templateId == RuleTemplate.defaultWorkFocus.id) return;
    _ruleTemplates.removeWhere((t) => t.id == templateId);
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

  static const Set<String> _globalOverrideKeys = {
    'global',
    'global_mute',
    'global_allow',
  };

  /// Sets a temporary override for an application (or globally).
  Future<void> setOverride(TemporaryOverride override) async {
    if (_globalOverrideKeys.contains(override.appId)) {
      for (final key in _globalOverrideKeys) {
        _overrides.remove(key);
      }
    }
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
    bool removed = _overrides.remove(appId) != null;
    if (_globalOverrideKeys.contains(appId)) {
      for (final key in _globalOverrideKeys) {
        if (_overrides.remove(key) != null) removed = true;
      }
    }
    if (removed) {
      await _persist();
    }
  }

  /// Gets any active temporary override for [appId] (checking per-app first, then global).
  TemporaryOverride? getActiveOverride(String appId) {
    final now = DateTime.now();

    final appOv = _overrides[appId];
    if (appOv != null && appOv.isActiveAt(now)) {
      return appOv;
    }

    final globalMute = _overrides['global_mute'];
    if (globalMute != null && globalMute.isActiveAt(now)) {
      return globalMute;
    }

    final globalAllow = _overrides['global_allow'];
    if (globalAllow != null && globalAllow.isActiveAt(now)) {
      return globalAllow;
    }

    final globalGeneric = _overrides['global'];
    if (globalGeneric != null && globalGeneric.isActiveAt(now)) {
      return globalGeneric;
    }

    return null;
  }

  /// Alias for getActiveOverride with optional targetDateTime support.
  TemporaryOverride? getOverrideForApp(String appId, [DateTime? targetDateTime]) {
    return getActiveOverride(appId);
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

  /// Evaluates the decision for [app] at [dateTime].
  ScheduleDecision evaluateApp(ManagedApp app, [DateTime? dateTime]) {
    final dt = dateTime ?? DateTime.now();
    final override = getActiveOverride(app.id);
    return _evaluator.evaluate(
      app: app,
      schedules: _schedules,
      override: override,
      currentDateTime: dt,
    );
  }

  /// Helper to calculate current active focus metrics.
  ({int total, int blocked, int allowed}) getMetrics([DateTime? dateTime]) {
    final dt = dateTime ?? DateTime.now();
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

  /// Alias for getMetrics.
  ({int total, int blocked, int allowed}) getSummary([DateTime? targetDateTime]) {
    return getMetrics(targetDateTime);
  }

  /// Exports active rules, templates, and managed applications as a formatted .notiflow JSON payload.
  String exportRulesJson() {
    final payload = {
      'app': 'Notiflow',
      'version': '1.6.0',
      'format': 'notiflow-backup-v1',
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'managedApps': _managedApps.map((a) => a.toJson()).toList(),
      'schedules': _schedules.map((r) => r.toJson()).toList(),
      'ruleTemplates': _ruleTemplates.map((t) => t.toJson()).toList(),
      'unmanagedAppsUntouched': _unmanagedAppsUntouched,
      'vipEmergencyBypass': _vipEmergencyBypass,
      'defaultScheduleMode': _defaultScheduleMode,
      'use24HourFormat': _use24HourFormat,
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Exports active rules to a user-selected .notiflow file on device storage.
  /// Returns the saved file name/path, or null if the user canceled the save dialog.
  Future<String?> exportRulesToFile() async {
    final jsonContent = exportRulesJson();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'notiflow_backup_$timestamp.notiflow';
    return await _platformService.exportBackupFile(
      fileName: fileName,
      content: jsonContent,
    );
  }

  /// Checks if any dormant vault apps have now been installed on the device,
  /// and automatically activates them and brings them to the Rules page!
  Future<int> checkAndActivateDormantApps({bool notify = true}) async {
    try {
      final dormant = _managedApps.where((a) => a.isDormantVault).toList();
      if (dormant.isEmpty) return 0;

      final installed = await _platformService.getInstalledApplications();
      final installedMap = {for (final a in installed) a.packageName: a};

      int activatedCount = 0;
      for (int i = 0; i < _managedApps.length; i++) {
        final app = _managedApps[i];
        if (app.isDormantVault && installedMap.containsKey(app.packageName)) {
          final discovered = installedMap[app.packageName]!;
          _managedApps[i] = app.copyWith(
            isDormantVault: false,
            displayName: discovered.displayName.isNotEmpty
                ? discovered.displayName
                : app.displayName,
            iconBytes: discovered.iconBytes ?? app.iconBytes,
          );
          activatedCount++;
        }
      }

      if (activatedCount > 0) {
        await _persist();
        if (notify) notifyListeners();
      }
      return activatedCount;
    } catch (_) {
      return 0;
    }
  }

  /// Reads raw string content from a picked .notiflow backup file.
  Future<String?> pickBackupRawContent() async {
    return await _platformService.pickBackupFile();
  }

  /// Inspects a raw .notiflow JSON payload and returns the list of uninstalled apps
  Future<List<ManagedApp>> detectUninstalledAppsInBackup(String rawJson) async {
    try {
      final sanitized = rawJson.trim().replaceFirst(RegExp(r'^\uFEFF'), '');
      final decoded = jsonDecode(sanitized);
      if (decoded is! Map<String, dynamic>) return [];
      final List<dynamic>? appsList = decoded['managedApps'] as List<dynamic>?;
      if (appsList == null) return [];

      final importedApps = appsList
          .map((e) => ManagedApp.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      final installed = await _platformService.getInstalledApplications();
      final installedPkgs = installed.map((a) => a.packageName).toSet();

      return importedApps
          .where((a) => !installedPkgs.contains(a.packageName))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Prompts user to pick a backup file and imports it.
  /// Returns `true` if imported, `false` if the selected file was invalid,
  /// or `null` if the user canceled the file picker.
  Future<bool?> pickRulesFromFile({
    bool replaceAll = true,
    bool vaultUninstalled = true,
    bool excludeUninstalled = false,
  }) async {
    final fileContent = await _platformService.pickBackupFile();
    if (fileContent == null) {
      return null;
    }
    if (fileContent.trim().isEmpty) {
      return false;
    }
    return await importRulesJson(
      fileContent,
      replaceAll: replaceAll,
      vaultUninstalled: vaultUninstalled,
      excludeUninstalled: excludeUninstalled,
    );
  }

  /// Imports and validates a .notiflow JSON string.
  /// Restores apps, schedules, and ruleTemplates seamlessly with backward compatibility.
  Future<bool> importRulesJson(
    String rawJson, {
    bool replaceAll = true,
    bool vaultUninstalled = true,
    bool excludeUninstalled = false,
  }) async {
    try {
      final sanitized = rawJson.trim().replaceFirst(RegExp(r'^\uFEFF'), '');
      final decoded = jsonDecode(sanitized);
      if (decoded is! Map<String, dynamic>) {
        return false;
      }

      final List<dynamic>? appsList = decoded['managedApps'] as List<dynamic>?;
      final List<dynamic>? schedulesList = decoded['schedules'] as List<dynamic>?;
      final List<dynamic>? templatesList = decoded['ruleTemplates'] as List<dynamic>?;

      if (appsList == null && schedulesList == null && templatesList == null) {
        return false;
      }

      final importedApps = appsList != null
          ? appsList.map((e) => ManagedApp.fromJson(Map<String, dynamic>.from(e as Map))).toList()
          : <ManagedApp>[];

      final importedSchedules = schedulesList != null
          ? schedulesList.map((e) => ScheduleRule.fromJson(Map<String, dynamic>.from(e as Map))).toList()
          : <ScheduleRule>[];

      final importedTemplates = templatesList != null
          ? templatesList.map((e) => RuleTemplate.fromJson(Map<String, dynamic>.from(e as Map))).toList()
          : <RuleTemplate>[];

      // Handle uninstalled apps:
      final installed = await _platformService.getInstalledApplications();
      final installedPkgs = installed.map((a) => a.packageName).toSet();

      if (excludeUninstalled) {
        // Exclude uninstalled apps and their rules completely
        importedApps.removeWhere((a) => !installedPkgs.contains(a.packageName));
        final remainingAppIds = importedApps.map((a) => a.id).toSet();
        importedSchedules.removeWhere((r) => !remainingAppIds.contains(r.appId));
      } else if (vaultUninstalled) {
        // Keep in vault & auto-apply when installed: mark isDormantVault: true so they are not shown on Rules page
        for (int i = 0; i < importedApps.length; i++) {
          final a = importedApps[i];
          if (!installedPkgs.contains(a.packageName)) {
            importedApps[i] = a.copyWith(isDormantVault: true);
          }
        }
      }

      if (replaceAll) {
        _managedApps = importedApps;
        _schedules = importedSchedules;
        if (importedTemplates.isNotEmpty) {
          _ruleTemplates = importedTemplates;
        }
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
        for (final tmpl in importedTemplates) {
          if (!_ruleTemplates.any((t) =>
              t.id == tmpl.id ||
              t.matchesConfiguration(
                targetMode: tmpl.mode,
                targetStartTime: tmpl.startTime,
                targetEndTime: tmpl.endTime,
                targetDaysOfWeek: tmpl.daysOfWeek,
              ))) {
            _ruleTemplates.add(tmpl);
          }
        }
      }

      // Always ensure the default pre-seeded template exists
      if (_ruleTemplates.isEmpty ||
          !_ruleTemplates.any((t) => t.id == RuleTemplate.defaultWorkFocus.id)) {
        _ruleTemplates.insert(0, RuleTemplate.defaultWorkFocus);
      }

      if (decoded.containsKey('unmanagedAppsUntouched')) {
        _unmanagedAppsUntouched = decoded['unmanagedAppsUntouched'] as bool? ?? true;
      }
      if (decoded.containsKey('vipEmergencyBypass')) {
        _vipEmergencyBypass = decoded['vipEmergencyBypass'] as bool? ?? true;
      }
      if (decoded.containsKey('defaultScheduleMode')) {
        final mode = decoded['defaultScheduleMode'] as String?;
        if (mode == 'allow' || mode == 'block') {
          _defaultScheduleMode = mode!;
        }
      }
      if (decoded.containsKey('use24HourFormat')) {
        _use24HourFormat = decoded['use24HourFormat'] as bool? ?? false;
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

    final templatesJson = jsonEncode(_ruleTemplates.map((t) => t.toJson()).toList());
    await prefs.setString(_keyRuleTemplates, templatesJson);

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
