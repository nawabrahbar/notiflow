/// Defines whether the scheduled interval allows or blocks notifications.
enum ScheduleMode {
  allowDuring,
  blockDuring,
  allDayAllow,
  allDayBlock;

  String toJson() => name;
  static ScheduleMode fromJson(String value) =>
      ScheduleMode.values.firstWhere((e) => e.name == value,
          orElse: () => ScheduleMode.allowDuring);
}

/// Represents an immutable 24-hour time of day (hour 0-23, minute 0-59).
class TimeOfDayValue implements Comparable<TimeOfDayValue> {
  final int hour;
  final int minute;

  const TimeOfDayValue({required this.hour, required this.minute})
      : assert(hour >= 0 && hour < 24, 'Hour must be between 0 and 23'),
        assert(minute >= 0 && minute < 60, 'Minute must be between 0 and 59');

  int get totalMinutes => hour * 60 + minute;

  /// Returns true if this time is strictly before [other].
  bool isBefore(TimeOfDayValue other) => totalMinutes < other.totalMinutes;

  /// Returns true if this time is strictly after [other].
  bool isAfter(TimeOfDayValue other) => totalMinutes > other.totalMinutes;

  /// Returns true if this time is at or after [other].
  bool isAtOrAfter(TimeOfDayValue other) => totalMinutes >= other.totalMinutes;

  /// Returns true if this time is at or before [other].
  bool isAtOrBefore(TimeOfDayValue other) => totalMinutes <= other.totalMinutes;

  String format24Hour() {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String format12Hour() {
    final period = hour >= 12 ? 'PM' : 'AM';
    final h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m $period';
  }

  Map<String, dynamic> toJson() => {'hour': hour, 'minute': minute};

  factory TimeOfDayValue.fromJson(Map<String, dynamic> json) {
    return TimeOfDayValue(
      hour: json['hour'] as int,
      minute: json['minute'] as int,
    );
  }

  @override
  int compareTo(TimeOfDayValue other) => totalMinutes.compareTo(other.totalMinutes);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeOfDayValue &&
          runtimeType == other.runtimeType &&
          hour == other.hour &&
          minute == other.minute;

  @override
  int get hashCode => hour.hashCode ^ minute.hashCode;

  @override
  String toString() => format24Hour();
}

/// A schedule rule associated with an application.
class ScheduleRule {
  final String id;
  final String appId;
  final bool enabled;
  final ScheduleMode mode;
  final TimeOfDayValue startTime;
  final TimeOfDayValue endTime;

  /// Days of the week when this schedule is active:
  /// 1 = Monday, 2 = Tuesday, ..., 7 = Sunday (matches DateTime.weekday).
  final Set<int> daysOfWeek;

  final DateTime createdAt;
  final DateTime updatedAt;
  final bool allowVipContacts;

  const ScheduleRule({
    required this.id,
    required this.appId,
    this.enabled = true,
    this.mode = ScheduleMode.allowDuring,
    required this.startTime,
    required this.endTime,
    required this.daysOfWeek,
    required this.createdAt,
    required this.updatedAt,
    this.allowVipContacts = true,
  });

  /// Returns true if the time interval spans across midnight (e.g. 18:00 to 06:00).
  bool get isOvernight => startTime.isAfter(endTime);

  ScheduleRule copyWith({
    String? id,
    String? appId,
    bool? enabled,
    ScheduleMode? mode,
    TimeOfDayValue? startTime,
    TimeOfDayValue? endTime,
    Set<int>? daysOfWeek,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? allowVipContacts,
  }) {
    return ScheduleRule(
      id: id ?? this.id,
      appId: appId ?? this.appId,
      enabled: enabled ?? this.enabled,
      mode: mode ?? this.mode,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      allowVipContacts: allowVipContacts ?? this.allowVipContacts,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'appId': appId,
      'enabled': enabled,
      'mode': mode.toJson(),
      'startTime': startTime.toJson(),
      'endTime': endTime.toJson(),
      'daysOfWeek': daysOfWeek.toList()..sort(),
      'isOvernight': isOvernight,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'allowVipContacts': allowVipContacts,
    };
  }

  factory ScheduleRule.fromJson(Map<String, dynamic> json) {
    return ScheduleRule(
      id: json['id'] as String,
      appId: json['appId'] as String,
      enabled: json['enabled'] as bool? ?? true,
      mode: ScheduleMode.fromJson(json['mode'] as String),
      startTime: TimeOfDayValue.fromJson(json['startTime'] as Map<String, dynamic>),
      endTime: TimeOfDayValue.fromJson(json['endTime'] as Map<String, dynamic>),
      daysOfWeek: (json['daysOfWeek'] as List<dynamic>).map((e) => e as int).toSet(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      allowVipContacts: json['allowVipContacts'] as bool? ?? true,
    );
  }
}
