import 'package:flutter/material.dart';
import 'managed_app.dart';
import 'schedule_rule.dart';

/// Represents a curated focus & notification preset.
class RulePreset {
  final String id;
  final String title;
  final String description;
  final List<String> badges;
  final IconData icon;
  final List<ManagedApp> apps;
  final List<ScheduleRule> schedules;

  const RulePreset({
    required this.id,
    required this.title,
    required this.description,
    required this.badges,
    required this.icon,
    required this.apps,
    required this.schedules,
  });

  static List<RulePreset> get curatedPresets {
    final now = DateTime.now();
    return [
      RulePreset(
        id: 'deep_work',
        title: 'Deep Work Protocol',
        description: 'Blocks distracting workplace pings during core focus hours.',
        icon: Icons.bolt_rounded,
        badges: ['SLACK: HELD', 'TEAMS: HELD', 'GMAIL: BATCH', '09:00 — 17:00'],
        apps: [
          ManagedApp(
            id: 'app_slack',
            packageName: 'com.slack',
            displayName: 'Slack',
            category: 'Productivity',
            createdAt: now,
            updatedAt: now,
          ),
          ManagedApp(
            id: 'app_teams',
            packageName: 'com.microsoft.teams',
            displayName: 'Microsoft Teams',
            category: 'Productivity',
            createdAt: now,
            updatedAt: now,
          ),
          ManagedApp(
            id: 'app_gmail',
            packageName: 'com.google.android.gm',
            displayName: 'Gmail',
            category: 'Productivity',
            createdAt: now,
            updatedAt: now,
          ),
        ],
        schedules: [
          ScheduleRule(
            id: 'rule_deep_work_slack',
            appId: 'app_slack',
            mode: ScheduleMode.blockDuring,
            startTime: const TimeOfDayValue(hour: 9, minute: 0),
            endTime: const TimeOfDayValue(hour: 17, minute: 0),
            daysOfWeek: {1, 2, 3, 4, 5},
            createdAt: now,
            updatedAt: now,
          ),
          ScheduleRule(
            id: 'rule_deep_work_teams',
            appId: 'app_teams',
            mode: ScheduleMode.blockDuring,
            startTime: const TimeOfDayValue(hour: 9, minute: 0),
            endTime: const TimeOfDayValue(hour: 17, minute: 0),
            daysOfWeek: {1, 2, 3, 4, 5},
            createdAt: now,
            updatedAt: now,
          ),
          ScheduleRule(
            id: 'rule_deep_work_gmail',
            appId: 'app_gmail',
            mode: ScheduleMode.blockDuring,
            startTime: const TimeOfDayValue(hour: 9, minute: 0),
            endTime: const TimeOfDayValue(hour: 17, minute: 0),
            daysOfWeek: {1, 2, 3, 4, 5},
            createdAt: now,
            updatedAt: now,
          ),
        ],
      ),
      RulePreset(
        id: 'mindful_evening',
        title: 'Mindful Evening',
        description: 'Silences all social algorithms, reels, and newsfeeds before sleep.',
        icon: Icons.bedtime_rounded,
        badges: ['INSTAGRAM: HELD', 'X: HELD', 'YOUTUBE: HELD', '20:00 — 08:00'],
        apps: [
          ManagedApp(
            id: 'app_instagram',
            packageName: 'com.instagram.android',
            displayName: 'Instagram',
            category: 'Social',
            createdAt: now,
            updatedAt: now,
          ),
          ManagedApp(
            id: 'app_twitter',
            packageName: 'com.twitter.android',
            displayName: 'X (Twitter)',
            category: 'Social',
            createdAt: now,
            updatedAt: now,
          ),
          ManagedApp(
            id: 'app_youtube',
            packageName: 'com.google.android.youtube',
            displayName: 'YouTube',
            category: 'Social',
            createdAt: now,
            updatedAt: now,
          ),
        ],
        schedules: [
          ScheduleRule(
            id: 'rule_evening_insta',
            appId: 'app_instagram',
            mode: ScheduleMode.blockDuring,
            startTime: const TimeOfDayValue(hour: 20, minute: 0),
            endTime: const TimeOfDayValue(hour: 8, minute: 0),
            daysOfWeek: {1, 2, 3, 4, 5, 6, 7},
            createdAt: now,
            updatedAt: now,
          ),
          ScheduleRule(
            id: 'rule_evening_x',
            appId: 'app_twitter',
            mode: ScheduleMode.blockDuring,
            startTime: const TimeOfDayValue(hour: 20, minute: 0),
            endTime: const TimeOfDayValue(hour: 8, minute: 0),
            daysOfWeek: {1, 2, 3, 4, 5, 6, 7},
            createdAt: now,
            updatedAt: now,
          ),
          ScheduleRule(
            id: 'rule_evening_yt',
            appId: 'app_youtube',
            mode: ScheduleMode.blockDuring,
            startTime: const TimeOfDayValue(hour: 20, minute: 0),
            endTime: const TimeOfDayValue(hour: 8, minute: 0),
            daysOfWeek: {1, 2, 3, 4, 5, 6, 7},
            createdAt: now,
            updatedAt: now,
          ),
        ],
      ),
      RulePreset(
        id: 'minimalist',
        title: 'Minimalist Default',
        description: 'Allows VIP phone calls and direct SMS. Queues all other apps into quiet focus.',
        icon: Icons.shield_outlined,
        badges: ['CALLS: PASS', 'SMS: PASS', 'WHATSAPP: HELD', '24/7 SHIELD'],
        apps: [
          ManagedApp(
            id: 'app_whatsapp',
            packageName: 'com.whatsapp',
            displayName: 'WhatsApp',
            category: 'Messaging',
            createdAt: now,
            updatedAt: now,
          ),
        ],
        schedules: [
          ScheduleRule(
            id: 'rule_minimalist_whatsapp',
            appId: 'app_whatsapp',
            mode: ScheduleMode.blockDuring,
            startTime: const TimeOfDayValue(hour: 8, minute: 0),
            endTime: const TimeOfDayValue(hour: 20, minute: 0),
            daysOfWeek: {1, 2, 3, 4, 5, 6, 7},
            createdAt: now,
            updatedAt: now,
          ),
        ],
      ),
    ];
  }
}
