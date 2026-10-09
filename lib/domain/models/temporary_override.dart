/// Defines the action of a temporary override.
enum OverrideMode {
  allow,
  block;

  String toJson() => name;
  static OverrideMode fromJson(String value) =>
      OverrideMode.values.firstWhere((e) => e.name == value,
          orElse: () => OverrideMode.allow);
}

/// A time-limited manual override for an application that takes precedence
/// over recurring schedules.
class TemporaryOverride {
  final String id;
  final String appId;
  final OverrideMode mode;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final DateTime createdAt;

  const TemporaryOverride({
    required this.id,
    required this.appId,
    required this.mode,
    required this.startDateTime,
    required this.endDateTime,
    required this.createdAt,
  });

  /// Checks if this override is currently active.
  bool get isActive => isActiveAt(DateTime.now());

  /// Remaining minutes of this override.
  int get remainingMinutes {
    final diff = endDateTime.difference(DateTime.now()).inMinutes;
    return diff > 0 ? diff : 0;
  }

  /// Total duration in minutes of this override.
  int get durationMinutes => endDateTime.difference(startDateTime).inMinutes;

  /// String type representation for UI chips.
  String get type => mode == OverrideMode.block ? 'mute_all' : 'allow_all';

  /// Checks if this override is currently active at [targetDateTime].
  bool isActiveAt(DateTime targetDateTime) {
    return (targetDateTime.isAfter(startDateTime) ||
            targetDateTime.isAtSameMomentAs(startDateTime)) &&
        targetDateTime.isBefore(endDateTime);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'appId': appId,
      'mode': mode.toJson(),
      'startDateTime': startDateTime.toIso8601String(),
      'endDateTime': endDateTime.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory TemporaryOverride.fromJson(Map<String, dynamic> json) {
    return TemporaryOverride(
      id: json['id'] as String,
      appId: json['appId'] as String,
      mode: OverrideMode.fromJson(json['mode'] as String),
      startDateTime: DateTime.parse(json['startDateTime'] as String),
      endDateTime: DateTime.parse(json['endDateTime'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
