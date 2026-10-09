enum NotificationDecisionType {
  allow,
  block;

  bool get isAllowed => this == NotificationDecisionType.allow;
  bool get isBlocked => this == NotificationDecisionType.block;
}

/// The result of evaluating a notification against an application's schedules.
class ScheduleDecision {
  final NotificationDecisionType decision;
  final String reason;
  final String? activeRuleId;
  final String? overrideId;
  final DateTime? nextTransitionTime;

  const ScheduleDecision({
    required this.decision,
    required this.reason,
    this.activeRuleId,
    this.overrideId,
    this.nextTransitionTime,
  });

  bool get isAllowed => decision == NotificationDecisionType.allow;
  bool get isBlocked => decision == NotificationDecisionType.block;

  @override
  String toString() =>
      'ScheduleDecision($decision, reason: "$reason", rule: $activeRuleId, override: $overrideId)';
}
