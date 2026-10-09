import 'package:flutter_test/flutter_test.dart';
import 'package:notification_handler/domain/engine/schedule_evaluator.dart';
import 'package:notification_handler/domain/models/managed_app.dart';
import 'package:notification_handler/domain/models/schedule_decision.dart';
import 'package:notification_handler/domain/models/schedule_rule.dart';
import 'package:notification_handler/domain/models/temporary_override.dart';

void main() {
  const evaluator = ScheduleEvaluator();

  final testApp = ManagedApp(
    id: 'app_1',
    packageName: 'com.whatsapp',
    displayName: 'WhatsApp',
    enabled: true,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  group('ScheduleEvaluator - Normal Interval (09:00 -> 18:00 Allow Window)', () {
    final allowRule = ScheduleRule(
      id: 'rule_1',
      appId: testApp.id,
      enabled: true,
      mode: ScheduleMode.allowDuring,
      startTime: const TimeOfDayValue(hour: 9, minute: 0),
      endTime: const TimeOfDayValue(hour: 18, minute: 0),
      daysOfWeek: {1, 2, 3, 4, 5, 6, 7}, // Everyday
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    test('08:59:59 is BLOCKED (outside allow interval)', () {
      final dt = DateTime(2026, 10, 5, 8, 59, 59); // Monday
      final decision = evaluator.evaluate(
        app: testApp,
        schedules: [allowRule],
        currentDateTime: dt,
      );
      expect(decision.decision, NotificationDecisionType.block);
    });

    test('09:00:00 is ALLOWED (exact start boundary)', () {
      final dt = DateTime(2026, 10, 5, 9, 0, 0); // Monday
      final decision = evaluator.evaluate(
        app: testApp,
        schedules: [allowRule],
        currentDateTime: dt,
      );
      expect(decision.decision, NotificationDecisionType.allow);
    });

    test('12:30:00 is ALLOWED (midday inside interval)', () {
      final dt = DateTime(2026, 10, 5, 12, 30, 0);
      final decision = evaluator.evaluate(
        app: testApp,
        schedules: [allowRule],
        currentDateTime: dt,
      );
      expect(decision.decision, NotificationDecisionType.allow);
    });

    test('18:00:00 is ALLOWED (exact end boundary)', () {
      final dt = DateTime(2026, 10, 5, 18, 0, 0);
      final decision = evaluator.evaluate(
        app: testApp,
        schedules: [allowRule],
        currentDateTime: dt,
      );
      expect(decision.decision, NotificationDecisionType.allow);
    });

    test('18:01:00 is BLOCKED (past end boundary)', () {
      final dt = DateTime(2026, 10, 5, 18, 1, 0);
      final decision = evaluator.evaluate(
        app: testApp,
        schedules: [allowRule],
        currentDateTime: dt,
      );
      expect(decision.decision, NotificationDecisionType.block);
    });
  });

  group('ScheduleEvaluator - Overnight Interval (18:00 -> 06:00 Allow Window)', () {
    final overnightRule = ScheduleRule(
      id: 'rule_overnight',
      appId: testApp.id,
      enabled: true,
      mode: ScheduleMode.allowDuring,
      startTime: const TimeOfDayValue(hour: 18, minute: 0),
      endTime: const TimeOfDayValue(hour: 6, minute: 0),
      daysOfWeek: {1, 2, 3, 4, 5, 6, 7}, // Everyday
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    test('17:59:59 is BLOCKED (before overnight starts)', () {
      final dt = DateTime(2026, 10, 5, 17, 59, 59); // Monday
      final decision = evaluator.evaluate(
        app: testApp,
        schedules: [overnightRule],
        currentDateTime: dt,
      );
      expect(decision.decision, NotificationDecisionType.block);
    });

    test('18:00:00 is ALLOWED (overnight start boundary)', () {
      final dt = DateTime(2026, 10, 5, 18, 0, 0);
      final decision = evaluator.evaluate(
        app: testApp,
        schedules: [overnightRule],
        currentDateTime: dt,
      );
      expect(decision.decision, NotificationDecisionType.allow);
    });

    test('23:00:00 is ALLOWED (late evening)', () {
      final dt = DateTime(2026, 10, 5, 23, 0, 0);
      final decision = evaluator.evaluate(
        app: testApp,
        schedules: [overnightRule],
        currentDateTime: dt,
      );
      expect(decision.decision, NotificationDecisionType.allow);
    });

    test('00:00:00 is ALLOWED (midnight transition)', () {
      final dt = DateTime(2026, 10, 6, 0, 0, 0); // Tuesday midnight
      final decision = evaluator.evaluate(
        app: testApp,
        schedules: [overnightRule],
        currentDateTime: dt,
      );
      expect(decision.decision, NotificationDecisionType.allow);
    });

    test('05:59:59 is ALLOWED (early morning before boundary)', () {
      final dt = DateTime(2026, 10, 6, 5, 59, 59);
      final decision = evaluator.evaluate(
        app: testApp,
        schedules: [overnightRule],
        currentDateTime: dt,
      );
      expect(decision.decision, NotificationDecisionType.allow);
    });

    test('06:00:00 is ALLOWED (exact end boundary)', () {
      final dt = DateTime(2026, 10, 6, 6, 0, 0);
      final decision = evaluator.evaluate(
        app: testApp,
        schedules: [overnightRule],
        currentDateTime: dt,
      );
      expect(decision.decision, NotificationDecisionType.allow);
    });

    test('06:01:00 is BLOCKED (past overnight end boundary)', () {
      final dt = DateTime(2026, 10, 6, 6, 1, 0);
      final decision = evaluator.evaluate(
        app: testApp,
        schedules: [overnightRule],
        currentDateTime: dt,
      );
      expect(decision.decision, NotificationDecisionType.block);
    });
  });

  group('ScheduleEvaluator - Day Boundaries and Recurrence', () {
    // Active only on Monday evening (18:00 -> Tuesday 06:00)
    final mondayOnlyOvernight = ScheduleRule(
      id: 'rule_monday',
      appId: testApp.id,
      enabled: true,
      mode: ScheduleMode.allowDuring,
      startTime: const TimeOfDayValue(hour: 18, minute: 0),
      endTime: const TimeOfDayValue(hour: 6, minute: 0),
      daysOfWeek: {DateTime.monday}, // 1
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    test('Monday 20:00 is ALLOWED (Monday active evening)', () {
      final dt = DateTime(2026, 10, 5, 20, 0); // Monday
      final decision = evaluator.evaluate(
        app: testApp,
        schedules: [mondayOnlyOvernight],
        currentDateTime: dt,
      );
      expect(decision.decision, NotificationDecisionType.allow);
    });

    test('Tuesday 04:00 is ALLOWED (Spillover from Monday night)', () {
      final dt = DateTime(2026, 10, 6, 4, 0); // Tuesday morning
      final decision = evaluator.evaluate(
        app: testApp,
        schedules: [mondayOnlyOvernight],
        currentDateTime: dt,
      );
      expect(decision.decision, NotificationDecisionType.allow);
    });

    test('Wednesday 04:00 is BLOCKED (Tuesday night was not scheduled)', () {
      final dt = DateTime(2026, 10, 7, 4, 0); // Wednesday morning
      final decision = evaluator.evaluate(
        app: testApp,
        schedules: [mondayOnlyOvernight],
        currentDateTime: dt,
      );
      expect(decision.decision, NotificationDecisionType.block);
    });
  });

  group('ScheduleEvaluator - Multiple Schedules', () {
    final morningRule = ScheduleRule(
      id: 'rule_morning',
      appId: testApp.id,
      enabled: true,
      mode: ScheduleMode.allowDuring,
      startTime: const TimeOfDayValue(hour: 8, minute: 0),
      endTime: const TimeOfDayValue(hour: 10, minute: 0),
      daysOfWeek: {1, 2, 3, 4, 5},
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    final eveningRule = ScheduleRule(
      id: 'rule_evening',
      appId: testApp.id,
      enabled: true,
      mode: ScheduleMode.allowDuring,
      startTime: const TimeOfDayValue(hour: 18, minute: 0),
      endTime: const TimeOfDayValue(hour: 22, minute: 0),
      daysOfWeek: {1, 2, 3, 4, 5},
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    test('09:00 is ALLOWED (matches morning window)', () {
      final dt = DateTime(2026, 10, 5, 9, 0); // Monday
      final decision = evaluator.evaluate(
        app: testApp,
        schedules: [morningRule, eveningRule],
        currentDateTime: dt,
      );
      expect(decision.decision, NotificationDecisionType.allow);
    });

    test('14:00 is BLOCKED (between windows)', () {
      final dt = DateTime(2026, 10, 5, 14, 0); // Monday
      final decision = evaluator.evaluate(
        app: testApp,
        schedules: [morningRule, eveningRule],
        currentDateTime: dt,
      );
      expect(decision.decision, NotificationDecisionType.block);
    });

    test('19:30 is ALLOWED (matches evening window)', () {
      final dt = DateTime(2026, 10, 5, 19, 30); // Monday
      final decision = evaluator.evaluate(
        app: testApp,
        schedules: [morningRule, eveningRule],
        currentDateTime: dt,
      );
      expect(decision.decision, NotificationDecisionType.allow);
    });
  });

  group('ScheduleEvaluator - Overrides Precedence', () {
    final allowRule = ScheduleRule(
      id: 'rule_allow',
      appId: testApp.id,
      enabled: true,
      mode: ScheduleMode.allowDuring,
      startTime: const TimeOfDayValue(hour: 18, minute: 0),
      endTime: const TimeOfDayValue(hour: 22, minute: 0),
      daysOfWeek: {1, 2, 3, 4, 5, 6, 7},
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    test('Temporary BLOCK override suppresses during an active allow window', () {
      final dt = DateTime(2026, 10, 5, 19, 0); // normally allowed
      final blockOverride = TemporaryOverride(
        id: 'override_block_1',
        appId: testApp.id,
        mode: OverrideMode.block,
        startDateTime: DateTime(2026, 10, 5, 18, 30),
        endDateTime: DateTime(2026, 10, 5, 20, 0),
        createdAt: DateTime(2026, 10, 5, 18, 30),
      );

      final decision = evaluator.evaluate(
        app: testApp,
        schedules: [allowRule],
        override: blockOverride,
        currentDateTime: dt,
      );

      expect(decision.decision, NotificationDecisionType.block);
      expect(decision.overrideId, 'override_block_1');
    });

    test('Temporary ALLOW override allows during normally blocked hours', () {
      final dt = DateTime(2026, 10, 5, 14, 0); // normally blocked
      final allowOverride = TemporaryOverride(
        id: 'override_allow_1',
        appId: testApp.id,
        mode: OverrideMode.allow,
        startDateTime: DateTime(2026, 10, 5, 13, 30),
        endDateTime: DateTime(2026, 10, 5, 14, 30),
        createdAt: DateTime(2026, 10, 5, 13, 30),
      );

      final decision = evaluator.evaluate(
        app: testApp,
        schedules: [allowRule],
        override: allowOverride,
        currentDateTime: dt,
      );

      expect(decision.decision, NotificationDecisionType.allow);
      expect(decision.overrideId, 'override_allow_1');
    });
  });

  group('ScheduleEvaluator - Defaults & Edge Cases', () {
    test('Unmanaged app defaults to ALLOW', () {
      final decision = evaluator.evaluate(
        app: null,
        schedules: [],
        currentDateTime: DateTime(2026, 10, 5, 12, 0),
      );
      expect(decision.decision, NotificationDecisionType.allow);
    });

    test('Disabled app defaults to ALLOW', () {
      final disabledApp = testApp.copyWith(enabled: false);
      final decision = evaluator.evaluate(
        app: disabledApp,
        schedules: [],
        currentDateTime: DateTime(2026, 10, 5, 12, 0),
      );
      expect(decision.decision, NotificationDecisionType.allow);
    });

    test('Managed app with disabled rule defaults to ALLOW', () {
      final disabledRule = ScheduleRule(
        id: 'rule_dis',
        appId: testApp.id,
        enabled: false,
        mode: ScheduleMode.allowDuring,
        startTime: const TimeOfDayValue(hour: 18, minute: 0),
        endTime: const TimeOfDayValue(hour: 22, minute: 0),
        daysOfWeek: {1, 2, 3, 4, 5, 6, 7},
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final decision = evaluator.evaluate(
        app: testApp,
        schedules: [disabledRule],
        currentDateTime: DateTime(2026, 10, 5, 12, 0),
      );
      expect(decision.decision, NotificationDecisionType.allow);
    });
  });
}
