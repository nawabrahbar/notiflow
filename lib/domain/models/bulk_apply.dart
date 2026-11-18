import 'dart:typed_data';

import 'managed_app.dart';
import 'rule_template.dart';
import 'schedule_rule.dart';

/// An installed app picked in the Apply Rules wizard. It may or may not be
/// managed yet; unmanaged apps are added when the rules are applied.
class BulkApplyTarget {
  final String packageName;
  final String displayName;
  final Uint8List? iconBytes;

  const BulkApplyTarget({
    required this.packageName,
    required this.displayName,
    this.iconBytes,
  });
}

/// What one bulk apply did to one app.
class BulkApplyAppResult {
  final ManagedApp app;

  /// True when the app wasn't managed before and was added by this batch.
  final bool appAdded;

  /// Schedules created by this batch.
  final List<ScheduleRule> addedRules;

  /// Saved rules skipped because the app already had the same schedule.
  final List<RuleTemplate> skipped;

  const BulkApplyAppResult({
    required this.app,
    required this.appAdded,
    required this.addedRules,
    required this.skipped,
  });
}

/// Outcome of applying several saved rules to several apps in one go.
class BulkApplyResult {
  final List<BulkApplyAppResult> apps;

  const BulkApplyResult(this.apps);

  int get addedCount => apps.fold(0, (sum, a) => sum + a.addedRules.length);

  int get skippedCount => apps.fold(0, (sum, a) => sum + a.skipped.length);
}

/// True when [rules] already contain a schedule with the same mode, times and
/// days as [template].
bool templateAlreadyApplied(RuleTemplate template, Iterable<ScheduleRule> rules) {
  return rules.any((r) => template.matchesConfiguration(
        targetMode: r.mode,
        targetStartTime: r.startTime,
        targetEndTime: r.endTime,
        targetDaysOfWeek: r.daysOfWeek,
      ));
}
