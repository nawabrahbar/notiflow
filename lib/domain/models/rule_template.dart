import 'schedule_rule.dart';

/// Reusable schedule rule template for quick autofill across apps.
class RuleTemplate {
  final String id;
  final String name;
  final ScheduleMode mode;
  final TimeOfDayValue startTime;
  final TimeOfDayValue endTime;
  final Set<int> daysOfWeek;
  final bool allowVipContacts;
  final bool isPreSeeded;
  final DateTime createdAt;

  const RuleTemplate({
    required this.id,
    required this.name,
    required this.mode,
    required this.startTime,
    required this.endTime,
    required this.daysOfWeek,
    this.allowVipContacts = true,
    this.isPreSeeded = false,
    required this.createdAt,
  });

  /// The single pre-seeded default template: Work Focus Hours (09:00 AM to 05:00 PM, Mon-Fri).
  static final RuleTemplate defaultWorkFocus = RuleTemplate(
    id: 'template_work_focus',
    name: 'Work Focus Hours',
    mode: ScheduleMode.blockDuring,
    startTime: const TimeOfDayValue(hour: 9, minute: 0),
    endTime: const TimeOfDayValue(hour: 17, minute: 0),
    daysOfWeek: const {1, 2, 3, 4, 5},
    allowVipContacts: true,
    isPreSeeded: true,
    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
  );

  /// Helper to check if a schedule configuration matches this template (for deduplication).
  bool matchesConfiguration({
    required ScheduleMode targetMode,
    required TimeOfDayValue targetStartTime,
    required TimeOfDayValue targetEndTime,
    required Set<int> targetDaysOfWeek,
  }) {
    return mode == targetMode &&
        startTime.hour == targetStartTime.hour &&
        startTime.minute == targetStartTime.minute &&
        endTime.hour == targetEndTime.hour &&
        endTime.minute == targetEndTime.minute &&
        daysOfWeek.length == targetDaysOfWeek.length &&
        daysOfWeek.containsAll(targetDaysOfWeek);
  }

  RuleTemplate copyWith({
    String? id,
    String? name,
    ScheduleMode? mode,
    TimeOfDayValue? startTime,
    TimeOfDayValue? endTime,
    Set<int>? daysOfWeek,
    bool? allowVipContacts,
    bool? isPreSeeded,
    DateTime? createdAt,
  }) {
    return RuleTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      mode: mode ?? this.mode,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      allowVipContacts: allowVipContacts ?? this.allowVipContacts,
      isPreSeeded: isPreSeeded ?? this.isPreSeeded,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'mode': mode.toJson(),
      'startTime': startTime.toJson(),
      'endTime': endTime.toJson(),
      'daysOfWeek': daysOfWeek.toList()..sort(),
      'allowVipContacts': allowVipContacts,
      'isPreSeeded': isPreSeeded,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory RuleTemplate.fromJson(Map<String, dynamic> json) {
    return RuleTemplate(
      id: json['id'] as String,
      name: json['name'] as String,
      mode: ScheduleMode.fromJson(json['mode'] as String),
      startTime: TimeOfDayValue.fromJson(json['startTime'] as Map<String, dynamic>),
      endTime: TimeOfDayValue.fromJson(json['endTime'] as Map<String, dynamic>),
      daysOfWeek: (json['daysOfWeek'] as List<dynamic>).map((e) => e as int).toSet(),
      allowVipContacts: json['allowVipContacts'] as bool? ?? true,
      isPreSeeded: json['isPreSeeded'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }
}
