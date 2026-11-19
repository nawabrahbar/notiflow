import 'package:flutter_test/flutter_test.dart';
import 'package:notification_handler/domain/engine/activity_grouping.dart';

Map<String, dynamic> e(int minute, String title,
        {String pkg = 'com.whatsapp', bool blocked = true, String conv = ''}) =>
    {
      'packageName': pkg,
      'notifTitle': title,
      'conversationKey': conv,
      'isBlocked': blocked,
      'timestampMs': minute * 60000,
    };

void main() {
  test('groups consecutive messages from one person and splits on change', () {
    final cards = groupActivityEvents([
      e(100, 'Sunil'),
      e(90, 'Sunil'),
      e(80, 'Sunil'),
      e(75, 'Ravi'), // someone else in between
      e(70, 'Sunil'),
      e(30, 'Sunil'), // more than 30 minutes earlier
      e(29, 'Sunil', blocked: false), // status changed
      e(28, 'Sunil', pkg: 'com.slack'), // another app
    ]);
    expect(cards.map((c) => c['groupCount']), [3, 1, 1, 1, 1, 1]);
    expect(cards.first['timestampMs'], 100 * 60000);
    expect((cards.first['groupEvents'] as List).length, 3);
  });

  test('conversation key groups a chat even when the sender title changes', () {
    final cards = groupActivityEvents([
      e(10, 'Ravi', conv: 'family'),
      e(9, 'Sunil', conv: 'family'),
    ]);
    expect(cards.single['groupCount'], 2);
  });

  test('capture source changes start a new card without relabelling old events', () {
    final cards = groupActivityEvents([
      {...e(10, 'Sunil'), 'isHistoryOnly': false},
      {...e(9, 'Sunil'), 'isHistoryOnly': true},
      {...e(8, 'Sunil'), 'isHistoryOnly': true},
    ]);
    expect(cards.map((c) => c['groupCount']), [1, 2]);
    expect(cards.map((c) => c['isHistoryOnly']), [false, true]);
  });
}
