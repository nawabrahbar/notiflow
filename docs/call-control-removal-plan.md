# Call-control limitations and removal plan

**Status:** The call controls have been removed and recognized call-like
notifications are left untouched. Legacy data and repeat-caller logic remain
dormant. Real-device checks and the Play Store listing update remain outstanding.

## Decision

Notiflow must not promise to block, mute or reliably bypass incoming calls when
it cannot deliver that behavior. The intended future change is to remove the
misleading call-control options and claims, and leave recognized call-like
notifications untouched by app rules and global Quick Mute. The existing
repeat-caller implementation remains as a reference for possible future research.

## What we found

On the connected phone, the user observed that regular phone and WhatsApp calls
rang on the first and subsequent attempts under both app rules and global mute.
This is a user observation; we have not independently reproduced every app,
device or call configuration.

The Android notification listener receives notifications after they are posted.
It can request cancellation of a notification, but that is not a reliable way
to stop an underlying phone or VoIP call's ringtone, vibration or call UI.
Therefore an evaluator decision labeled blocked does not prove that the call
was actually silenced.

Previously, the listener detected calls differently from the evaluator: the listener
checks the notification category **or** `android.callType`, while the evaluator
receives and checks only the category. A call recognized only by the extra may
miss the repeat-caller logic. Notifications with no recognized call metadata can
also be processed as ordinary notifications; the code cannot reliably identify
every calling app or every call notification.

Repeat-call matching currently uses package and notification title, with
`unknown` for an empty title. It is in-memory, can mistake notification updates
for separate calls, and cannot reliably establish a caller's identity. It is not
a dependable cross-app, three-minute call-screening implementation.

## Previous implementation map

- **Dashboard:** `lib/presentation/widgets/quick_mute_card.dart` shows
  “Let repeat callers ring through” and changes the repository preference.
- **Settings:** `lib/presentation/screens/settings_screen.dart` shows “Allow
  Priority Phone Calls” with phone/tablet descriptions that promise bypasses.
  These descriptions are inconsistent with the evaluator's actual repeat-call
  behavior.
- **Schedule editor:** `lib/presentation/screens/schedule_editor_screen.dart`
  shows “Urgent Call Escalation” and stores `_allowUrgent` in schedule rules
  and saved templates. The editor is reused for creating and editing rules and
  templates; all modes need consideration.
- **Persistence and backup:** `lib/domain/models/schedule_rule.dart` and
  `lib/domain/models/rule_template.dart` serialize `allowVipContacts`.
  `lib/data/repositories/schedule_repository.dart` stores and imports/exports
  `vipEmergencyBypass`, copies the rule flag into templates and bulk-applied
  schedules, and syncs it to the native layer. Platform interfaces and
  `lib/platform/android_notification_platform.dart` carry that value.
- **Android:** `NotificationHandlerListenerService.kt` detects call-like
  notifications and passes their category to `NativeScheduleStore`.
  `NativeScheduleStore.kt` maintains the in-memory repeat-call map and applies
  bypasses for global mute and certain recurring rules. Per-app temporary
  overrides are evaluated earlier and do not use that bypass. Blocked call-like
  notifications are sent to cancellation, not a call-screening API.
- **Existing tests:** `android/app/src/test/kotlin/com/notificationhandler/
  notification_handler/NativeScheduleEvaluatorTest.kt` tests synthetic evaluator
  decisions; it does not verify actual ringtone or vibration. Widget and
  repository tests in `test/presentation/new_screens_test.dart` and
  `test/data/schedule_repository_test.dart` cover the controls and saved fields.
- **Claims:** Review `README.md`, `APP_FEATURES.md`, `docs/privacy.md`,
  `docs/android-notification-flow.md`, `docs/catch-up-digest.md`, and
  `docs/apply-rules.md`, including historical release notes and presets. Review
  the Play Store description separately; changing repository docs does not
  update the published listing.

## Implementation and verification checklist

1. Remove the Dashboard, Settings and schedule-editor controls and their
   associated claims. Make Quick Mute and rule descriptions clear that incoming
   calls are not guaranteed to be controlled. Keep the rest of the notification
   scheduling and History UI unchanged.
2. Before evaluating or recording an **identified incoming call notification**,
   leave it untouched: no cancellation, snoozing, digest hold or repeat-caller
   state updates. Apply this regardless of app rules, global mute, temporary
   overrides or History-only mode. Preserve ordinary notification handling.
   Define detection conservatively and test real metadata: unknown or
   app-specific calls cannot be guaranteed to be identifiable from notification
   metadata alone. Do not claim universal protection until verified.
3. Keep legacy `allowVipContacts` and `vipEmergencyBypass` data readable and
   preserved across import, export, editing and bulk application, but make it
   inert while call control is unavailable. Avoid silently resetting saved
   values when an existing rule or template is edited. Retain dormant code only
   if it is unreachable from live notification handling; label it clearly as
   unsupported rather than allowing it to influence calls.
4. Update directly related documentation and user-facing descriptions to
   distinguish notification filtering from call control. Do not claim all apps
   or all calls are covered based solely on notification metadata.
5. Add focused tests for recognized incoming calls under global mute, per-app
   rules and overrides, including category-only and `android.callType`-only
   notifications, and ordinary notifications from the same app. Test all
   schedule-editor modes and legacy backup round-trips. On actual devices,
   check regular calls and each target VoIP app, including sound, vibration,
   full-screen UI, notification updates and missed calls. Record unsupported
   cases rather than assuming success from unit tests.

## Possible future research

Android 10+ offers `CallScreeningService.CallResponse.Builder.setSilenceCall`
for eligible calls without rejecting them. It requires the user-selected call
screening role, which can replace another screening app; API behavior, contact
coverage, vibration and OEM behavior require verification. It is not a
universal VoIP-call API. Any future prototype should be optional, privacy-aware,
tested on real devices, and accurately disclose its limits before release.

References: [Android call screening](https://developer.android.com/reference/android/telecom/CallScreeningService)
and [silence-call response](https://developer.android.com/reference/android/telecom/CallScreeningService.CallResponse.Builder#setSilenceCall(boolean)).
