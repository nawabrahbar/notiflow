/// Groups Activity log events into conversation cards.
///
/// [events] must be newest first. Consecutive events from the same app, the
/// same person or chat, and the same status (silenced or allowed) join one
/// card while each is within [maxGap] of the next. Any other event in between,
/// a status change, or a longer gap starts a new card.
///
/// Each returned map is the newest event of its card plus `groupCount` and
/// `groupEvents` (all events of the card, newest first).
List<Map<String, dynamic>> groupActivityEvents(
  List<Map<String, dynamic>> events, {
  Duration maxGap = const Duration(minutes: 30),
}) {
  final cards = <Map<String, dynamic>>[];
  List<Map<String, dynamic>>? current;
  String? currentKey;

  void close(List<Map<String, dynamic>>? group) {
    if (group == null) return;
    cards.add({
      ...group.first,
      'groupCount': group.length,
      'groupEvents': List<Map<String, dynamic>>.unmodifiable(group),
    });
  }

  for (final event in events) {
    final key = _conversationKey(event);
    final previous = current?.last;
    final withinGap = previous != null &&
        (_timestampMs(previous) - _timestampMs(event)).abs() <=
            maxGap.inMilliseconds;
    if (current != null && key == currentKey && withinGap) {
      current.add(event);
    } else {
      close(current);
      current = [event];
      currentKey = key;
    }
  }
  close(current);
  return cards;
}

String _conversationKey(Map<String, dynamic> event) {
  final conversation = (event['conversationKey'] as String? ?? '').trim();
  final title = (event['notifTitle'] as String? ?? '').trim();
  final who = conversation.isNotEmpty ? 'c:$conversation' : 't:$title';
  return '${event['packageName']}|${event['isBlocked'] == true}|'
      '${event['isHistoryOnly'] == true}|$who';
}

int _timestampMs(Map<String, dynamic> event) =>
    (event['timestampMs'] as num?)?.toInt() ?? 0;
