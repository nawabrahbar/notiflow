import '../models/managed_app.dart';
import '../models/schedule_decision.dart';
import '../models/schedule_rule.dart';
import '../models/temporary_override.dart';

/// Pure Dart schedule evaluation engine.
/// Evaluates whether an incoming notification should be allowed or blocked
/// based on managed app status, temporary overrides, and recurring schedule rules.
class ScheduleEvaluator {
  const ScheduleEvaluator();

  /// Evaluates an incoming notification at [currentDateTime].
  ///
  /// Priority:
  /// 1. Unmanaged or disabled app -> ALLOW
  /// 2. Temporary override -> ALLOW or BLOCK (strict precedence)
  /// 3. Recurring schedules -> Evaluated by rule modes and intervals
  /// 4. Default fallback -> ALLOW
  ScheduleDecision evaluate({
    required ManagedApp? app,
    required List<ScheduleRule> schedules,
    TemporaryOverride? override,
    required DateTime currentDateTime,
  }) {
    // 1. Unmanaged or disabled app
    if (app == null) {
      return const ScheduleDecision(
        decision: NotificationDecisionType.allow,
        reason: 'App is unmanaged (default allow)',
      );
    }

    if (!app.enabled) {
      return const ScheduleDecision(
        decision: NotificationDecisionType.allow,
        reason: 'App scheduling is disabled (default allow)',
      );
    }

    // 2. Temporary Override (Takes precedence over normal schedules)
    if (override != null && override.isActiveAt(currentDateTime)) {
      if (override.mode == OverrideMode.allow) {
        return ScheduleDecision(
          decision: NotificationDecisionType.allow,
          reason: 'Temporary allow override active until ${override.endDateTime.toLocal()}',
          overrideId: override.id,
          nextTransitionTime: override.endDateTime,
        );
      } else {
        return ScheduleDecision(
          decision: NotificationDecisionType.block,
          reason: 'Temporary block override active until ${override.endDateTime.toLocal()}',
          overrideId: override.id,
          nextTransitionTime: override.endDateTime,
        );
      }
    }

    // 3. Filter active rules for this app
    final activeRules = schedules
        .where((rule) => rule.appId == app.id && rule.enabled)
        .toList();

    if (activeRules.isEmpty) {
      return const ScheduleDecision(
        decision: NotificationDecisionType.allow,
        reason: 'No active schedules configured (default allow)',
      );
    }

    // Separate allow rules from block rules
    final allowRules = activeRules
        .where((r) =>
            r.mode == ScheduleMode.allowDuring ||
            r.mode == ScheduleMode.allDayAllow)
        .toList();

    final blockRules = activeRules
        .where((r) =>
            r.mode == ScheduleMode.blockDuring ||
            r.mode == ScheduleMode.allDayBlock)
        .toList();

    // Check if any explicit BLOCK rule matches current time
    for (final rule in blockRules) {
      if (_isRuleIntervalMatching(rule, currentDateTime)) {
        return ScheduleDecision(
          decision: NotificationDecisionType.block,
          reason: 'Notification blocked by schedule rule: ${rule.mode.name} (${rule.startTime.format24Hour()} -> ${rule.endTime.format24Hour()})',
          activeRuleId: rule.id,
        );
      }
    }

    // If there are ALLOW rules configured, the notification is ONLY allowed
    // if current time matches at least one active ALLOW rule.
    if (allowRules.isNotEmpty) {
      for (final rule in allowRules) {
        if (_isRuleIntervalMatching(rule, currentDateTime)) {
          return ScheduleDecision(
            decision: NotificationDecisionType.allow,
            reason: 'Notification allowed by schedule rule: ${rule.mode.name} (${rule.startTime.format24Hour()} -> ${rule.endTime.format24Hour()})',
            activeRuleId: rule.id,
          );
        }
      }

      // Outside all allow windows
      return const ScheduleDecision(
        decision: NotificationDecisionType.block,
        reason: 'Notification blocked outside allowed schedule window',
      );
    }

    // Default allow if no matching block rules and no allow rules configured
    return const ScheduleDecision(
      decision: NotificationDecisionType.allow,
      reason: 'No schedule condition triggered (default allow)',
    );
  }

  /// Determines whether [rule] is actively matched at [dt].
  bool _isRuleIntervalMatching(ScheduleRule rule, DateTime dt) {
    final todayWeekday = dt.weekday; // 1 = Monday, 7 = Sunday
    final yesterdayWeekday = todayWeekday == 1 ? 7 : todayWeekday - 1;
    final currentTime = TimeOfDayValue(hour: dt.hour, minute: dt.minute);

    // All-day modes
    if (rule.mode == ScheduleMode.allDayAllow ||
        rule.mode == ScheduleMode.allDayBlock) {
      return rule.daysOfWeek.contains(todayWeekday);
    }

    // Normal (non-overnight) interval: e.g. 09:00 -> 18:00
    if (!rule.isOvernight) {
      if (!rule.daysOfWeek.contains(todayWeekday)) {
        return false;
      }
      return currentTime.isAtOrAfter(rule.startTime) &&
          currentTime.isAtOrBefore(rule.endTime);
    }

    // Overnight interval: e.g. 18:00 -> 06:00
    // Can match from today's evening:
    if (rule.daysOfWeek.contains(todayWeekday) &&
        currentTime.isAtOrAfter(rule.startTime)) {
      return true;
    }

    // Can match from yesterday's evening spanning into today's early morning:
    if (rule.daysOfWeek.contains(yesterdayWeekday) &&
        currentTime.isAtOrBefore(rule.endTime)) {
      return true;
    }

    return false;
  }
}
