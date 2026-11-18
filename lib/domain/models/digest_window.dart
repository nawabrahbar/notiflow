/// One finished rule window and the unique notifications it silenced.
class DigestWindow {
  final int id;
  final String packageName;
  final String appName;
  final String? ruleName;
  final DateTime start;
  final DateTime end;
  final bool reviewed;
  final bool isPriority;
  final List<Map<String, dynamic>> events;

  const DigestWindow({
    required this.id,
    required this.packageName,
    required this.appName,
    this.ruleName,
    required this.start,
    required this.end,
    required this.reviewed,
    required this.isPriority,
    required this.events,
  });

  int get count => events.length;

  String get displayName => appName.isNotEmpty ? appName : packageName;

  DigestWindow copyWith({bool? reviewed}) => DigestWindow(
        id: id,
        packageName: packageName,
        appName: appName,
        ruleName: ruleName,
        start: start,
        end: end,
        reviewed: reviewed ?? this.reviewed,
        isPriority: isPriority,
        events: events,
      );

  factory DigestWindow.fromJson(Map<String, dynamic> json) {
    final rawEvents = json['events'] as List<dynamic>? ?? const [];
    return DigestWindow(
      id: (json['id'] as num).toInt(),
      packageName: json['packageName'] as String? ?? '',
      appName: json['appName'] as String? ?? '',
      ruleName: json['ruleName'] as String?,
      start: DateTime.fromMillisecondsSinceEpoch((json['startMs'] as num).toInt()),
      end: DateTime.fromMillisecondsSinceEpoch((json['endMs'] as num).toInt()),
      reviewed: json['reviewed'] as bool? ?? false,
      isPriority: json['isPriority'] as bool? ?? false,
      events: rawEvents.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
    );
  }

  /// Priority (messaging) windows first, then newest first.
  static List<DigestWindow> sorted(List<DigestWindow> windows) {
    final list = [...windows];
    list.sort((a, b) {
      if (a.isPriority != b.isPriority) return a.isPriority ? -1 : 1;
      return b.end.compareTo(a.end);
    });
    return list;
  }
}
