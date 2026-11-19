# History-only notification tracking

**Agreed:** 19 Nov 2026. **Status:** implemented; debug build installed and launched on the connected phone.

## Purpose

Let users record notifications from selected apps without setting up app-specific
blocking rules. Recording is opt-in and starts when enabled; it cannot recover
notifications received before that.

User-facing explanation:

> Save this app's notification history without setting up rules. Quick Mute still applies.

## Agreed interface

- Activity filters: **All, Digest, History, Silenced, Allowed**, in that order.
- History-only entries show a **History** badge in All, alongside their actual
  Allowed/Silenced status. Source and delivery outcome are different properties.
- The History filter shows notifications captured through history-only tracking.
- A floating **Manage apps** button appears only while History is selected.
  Match the Rules floating-button styling and smooth scroll-driven collapse and
  expansion on phone and tablet.
- Manage apps allows selecting apps to record, stopping recording, and adding
  more apps. Keep history-only apps out of the Rules list unless rules are added.
- In Add Apps, tapping Add offers **Set up rules** or **Record history only**.
  History-only apps show **History on** and a Manage action.
- History-only apps can be upgraded to scheduling without losing notification
  history or duplicating the app.
- Phone filters scroll horizontally; tablet keeps its responsive layout.
- The Add app choice and History management sheets match the existing app sheets:
  Newsreader headings, Plus Jakarta Sans text, theme-specific surfaces and icon
  accents, rounded bordered options, and a 560 dp maximum width on tablets.
  Content scrolls when the available height is limited.

## Capture, filtering and lifecycle

- Global Quick Mute still applies. History-only is not an exemption from it.
- One notification is stored once. A history-only notification silenced by Quick
  Mute can appear in All, History and Silenced without duplicate database rows.
- Capture source is stored on the event, not inferred from the app's current
  settings. Earlier History badges and filter membership survive stopping
  recording or adding rules later.
- Stopping recording preserves existing entries. Deleting notification history
  is a separate, explicit action.
- Reuse local notification storage, existing content/duplicate safeguards and
  30-day retention. Existing notification history is not retroactively labelled
  History.
- Configuration must survive restarts and backup/restore. Notification content
  remains on-device and is not included in configuration backups.

## Implementation safeguards

- Keep an explicit history-only app setting, separate from a paused scheduling
  app. Do not silently change existing paused apps into history-only apps.
- Preserve existing app schedules, temporary overrides and notification capture.
- Preserve the capture source when existing notification rows are updated.
- Add a non-destructive database migration with a default of non-History for
  existing events.
- Cover native evaluation/storage, repository persistence, mode transitions and
  responsive UI with focused tests.

## Implemented flows

| Action | Configuration effect | Existing notifications |
| --- | --- | --- |
| Add Apps > Add > Record history only | Opt in; no scheduling rules created | Unchanged; no retroactive capture |
| History > Manage apps > check an app | Same opt-in, using the existing app picker | Unchanged |
| Uncheck / Stop recording | Remove the History-only configuration | Kept with their History badges |
| Manage > Add rules > Save | Reuse the app ID, add a schedule, show the app in Rules | Kept with their original capture source |
| Cancel the schedule editor | No promotion or schedule changes | Unchanged |
| Bulk Apply rules | Reuse the app and promote it to scheduling | Unchanged |
| Undo the last bulk-applied rule | Restore the previous History-only mode if no other schedules remain | Unchanged |
| Manage > Delete recorded history > confirm | Keep recording enabled | Delete only this app's History-source events, including Digest entries |

Existing scheduling apps show **Using rules** in the History manager rather
than recording checkboxes. Paused scheduling apps are not converted or enabled.
Tracked apps missing from the installed-apps list remain available in the
manager; imported dormant entries stay inactive until installation.

After stopping, the ordinary global notification policy still applies. For
example, Quick Mute can still silence and record an otherwise unmanaged app;
those later records are not History-source events. Notification access must be
granted for any capture.

## Code and storage details

- `lib/domain/models/managed_app.dart`: explicit `isHistoryOnly`, defaulting to
  false for old configurations. The flag is included in configuration backups.
- `lib/data/repositories/schedule_repository.dart`: History-only lifecycle,
  separate Rules/History collections, native sync, promotion on schedule save,
  and bulk undo restoration. Import merges remap matching packages to their
  existing app ID; imported schedules take precedence over a contradictory
  History-only flag without activating dormant apps.
- `android/app/src/main/kotlin/com/notificationhandler/notification_handler/NativeScheduleStore.kt`:
  the evaluator allows History-only apps after processing temporary/global
  overrides, while marking them eligible for recording. Capture snapshots the
  History-only source independently of the allowed/silenced decision.
- `android/app/src/main/kotlin/com/notificationhandler/notification_handler/NotiflowDatabase.kt`:
  database version **3** adds `history_only INTEGER NOT NULL DEFAULT 0` with
  `ALTER TABLE`, preserving existing records. Both Activity and Digest JSON
  expose `isHistoryOnly`. Deduplicated window updates retain the original row's
  source. Per-app History deletion uses existing event/window cleanup.
- `AndroidNotificationBridge.kt` and `android_notification_platform.dart`:
  `deleteHistoryForApp` validates the package and propagates deletion errors;
  the picker shows an error toast rather than reporting false success.
- `lib/presentation/screens/add_apps_screen.dart`: mode chooser, History manager,
  checkboxes, rule promotion, stop and confirmed deletion; reuses installed-apps
  caching, category/search filtering and bounded icon loading. App actions are
  guarded against repeated taps while in progress.
- `lib/presentation/screens/activity_screen.dart`: ordered filters, stored-source
  badges on cards and the inspector, and a History-only Manage apps FAB. History
  lists have bottom clearance so the FAB does not cover the last card.
- `lib/presentation/widgets/animated_fab_label.dart`: shared Rules/History label
  animation: 250 ms size/fade, right-anchored FABs, immediate reduced-motion
  transitions. Downward scrolling collapses the label; upward scrolling expands
  it, not just returning to the top.
- `lib/domain/engine/activity_grouping.dart`: different capture sources never
  collapse into a single misleading conversation badge.

## Verification

- Full Flutter suite: **158 passed**. Focused cases cover persistence,
  backup/import, source-aware grouping, promotion/cancellation, bulk undo,
  overlapping filters, recording checkboxes, stop versus deletion, visible
  deletion errors, phone/tablet layouts, navigation and intermediate FAB widths.
- Native JVM suite: **28 passed**, including History-only allow/record eligibility
  and Quick Mute precedence.
- Android database suite on the connected phone: **9 passed**, including the
  version-2 migration, preserved source during deduplication and scoped deletion
  from Activity/Digest without deleting another app's history or ordinary records.
- `flutter analyze --no-pub lib test`: **87 existing issues**, no new analyzer
  errors. `git diff --check` passes.
- Debug APK built, installed with replacement (no data reset), and launched.
  The process remained running with no startup Flutter/AndroidRuntime errors.
- Real incoming-notification interactions and subjective scrolling performance
  were not manually verified in this pass. No screenshots were taken.
