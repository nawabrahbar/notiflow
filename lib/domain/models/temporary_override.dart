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
    final targetMs = targetDateTime.millisecondsSinceEpoch;
    return targetMs >= startDateTime.millisecondsSinceEpoch &&
        targetMs < endDateTime.millisecondsSinceEpoch;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'appId': appId,
      'mode': mode.toJson(),
      'startDateTime': startDateTime.toUtc().toIso8601String(),
      'endDateTime': endDateTime.toUtc().toIso8601String(),
      'createdAt': createdAt.toUtc().toIso8601String(),
      'startMs': startDateTime.millisecondsSinceEpoch,
      'endMs': endDateTime.millisecondsSinceEpoch,
    };
  }

  factory TemporaryOverride.fromJson(Map<String, dynamic> json) {
    DateTime parseDateTime(dynamic rawIso, dynamic rawMs) {
      if (rawMs is num && rawMs > 0) {
        return DateTime.fromMillisecondsSinceEpoch(rawMs.toInt());
      }
      if (rawIso is String && rawIso.isNotEmpty) {
        return DateTime.parse(rawIso).toLocal();
      }
      return DateTime.now();
    }

    return TemporaryOverride(
      id: json['id'] as String,
      appId: json['appId'] as String,
      mode: OverrideMode.fromJson(json['mode'] as String),
      startDateTime: parseDateTime(json['startDateTime'], json['startMs']),
      endDateTime: parseDateTime(json['endDateTime'], json['endMs']),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String).toLocal()
          : DateTime.now(),
    );
  }
}
