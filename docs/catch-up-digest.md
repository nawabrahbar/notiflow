# Catch-Up Digest & Dashboard — Feature Specification

**Status:** Planned (design agreed, not implemented)
**Platform:** Android only (iOS cannot intercept other apps' notifications — see `ios-platform-limitations.md`)
**Last discussed:** 17 Nov 2026

This document records every decision taken while designing the Catch-Up Digest and the new Dashboard tab, so that nothing is forgotten when implementation starts. Items marked **Decided** were agreed with the product owner. Items marked **Proposed** are implementation suggestions that may still change. Items marked **Verify** must be tested on a real device before relying on them.

---

## 1. Problem

When Notiflow silences an app during a rule window, the user has to open the Activity tab and scan individual entries to find out what they missed. The goal is to make catching up effortless: when a rule ends, the missed notifications become available again and the user is told about it once.

---

## 2. Core behaviour: one digest per rule window

**Decided**

- A digest is tied to a **rule window**, not to a global "focus session".
- When a rule window ends, everything that was suppressed **during that window only** is released and summarised.
- Example: WhatsApp has two rules, 9 AM–5 PM and 7 PM–9 PM.
  - At 5 PM the user is told about what was suppressed between 9 AM and 5 PM.
  - At 9 PM the user is told about what was suppressed between 7 PM and 9 PM only.

### Edge cases (all **Decided**)

| Case | Behaviour |
|---|---|
| Overlapping rules for the same app (e.g. 9–5 and 4–6) | One digest when the app actually stops being silenced (6 PM). |
| Several rules (same or different apps) ending at the same time | Combined into one Notiflow notification, grouped by app. |
| Rule that crosses midnight (e.g. 10 PM–7 AM) | Digest at the end time (7 AM next day). |
| Temporary pause (e.g. "Pause for 1 hour") | Treated as a rule window; digest when the pause ends. |
| Permanent mute (no end time) | No digest. Notifications remain visible in the Activity tab only. |
| Nothing suppressed in a window | No digest and no notification (never send empty digests). |
| Only one notification suppressed | A digest is still sent (even a single item counts). |

---

## 3. Delivery: snooze the originals + one short Notiflow notification

**Decided**

### 3.1 Original notifications come back via Android snooze

- Instead of cancelling a notification during a rule window, Notiflow **snoozes** it (`NotificationListenerService.snoozeNotification(key, durationMs)`) until the window's end time.
- At the end time Android re-posts the **original notification from the original app** (WhatsApp, Slack, Gmail, etc.) with its own icon, content and tap action, so tapping it opens the exact chat/email. This works for **any app**, not only WhatsApp.
- If the source app removes its own notification during the window (e.g. the message was read on another device), it does not come back. This is desirable.
- Returned originals should come back **silently**; only the Notiflow notification (3.2) makes a sound.

**Exceptions (Decided)**

- Ongoing / foreground notifications (media players, navigation, uploads) cannot usefully be snoozed; they keep today's cancel behaviour.
- Permanent mute keeps today's cancel behaviour (there is no end time to snooze to).

**Verify on device (OnePlus CPH2573 and at least one other Android version)**

- Whether returned originals re-alert (sound/vibration). Android normally lets the source app's channel decide. If they cannot be kept silent, decide again between accepting the alerts or another approach.
- Whether snoozed notifications survive a phone restart. If they are lost, the Digest list in the app (section 5) is still complete, because every item is also stored in the database.
- Re-snoozing works reliably when a rule's end time changes (see 3.4).
- Behaviour when 20+ notifications return at once.

### 3.2 One short Notiflow notification per rule end

- When a rule window ends and at least one notification was suppressed, Notiflow posts **one short notification** saying the schedule has ended and how many notifications are now available.
- Wording (keep it short), single app:
  - Title: **WhatsApp quiet hours ended**
  - Body: **12 notifications are back**
- Several rules ending together → one combined notification:
  - Title: **Quiet hours ended**
  - Body: **WhatsApp 12 · Slack 4**
- Content after unlock: **app names and counts only** (no sender names or message text).
- Lock screen: total only, e.g. "Quiet hours ended · 16 notifications" (uses a public version of the notification).
- Tapping it opens Notiflow on the **Digest** view of the Activity tab.
- This is the only sound the user hears for the release.

### 3.3 Notification permission

**Decided:** add `POST_NOTIFICATIONS` (Android 13+).

- **New installs:** ask when the user opens the app for the first time.
- **Existing Play Store users:** ask on the first app open after updating to the version that ships this feature.
- Ask only if the permission is not already granted, and only once per install/update. Android allows the prompt to be shown at most twice before it stops appearing, so Notiflow must not nag.
- If the user declines: snooze/release and the in-app Dashboard card and Digest view keep working; only the Notiflow notification is skipped. Turning on the Settings toggle (section 7) asks again, or opens system settings if Android no longer shows the prompt.
- Android 12 and older: no prompt needed (permission is granted at install).

### 3.4 Editing or deleting a rule while notifications are snoozed

**Decided**

- **Rule edited and its end time changes:** re-snooze that app's held notifications to the new end time, and move the Notiflow notification to the new end time.
- **Rule edited so the window has already ended:** release the held notifications immediately and send the digest.
- **Rule deleted:** release that app's held notifications immediately (and send the digest if anything was held).
- **App removed from Notiflow, or its rules turned off:** treated like a deleted rule — release immediately.
- **Rule extended after its Notiflow notification was already posted (or skipped):** the old window is left as is. Newly silenced notifications go into a new window that starts where the old one ended, and get their own Notiflow notification.

---

## 4. Storage: local SQLite database

**Decided**

- Use a local on-device **SQLite** database written by the Kotlin side with Android's built-in SQLite and read by Flutter through the platform channel (see section 10).
- **Retention: 30 days**, pruned automatically.
- The Activity log moves from the 150-event `SharedPreferences` list into the same database, removing the 150-event cap. Activity and Digest share one source of truth.

**Proposed record fields** (~1 KB per row; 300/day × 30 days ≈ 9 MB worst case)

- id, package name, app name, title, text (truncated), post time
- notification key / conversation key (for de-duplication)
- rule id + window instance id (window start/end)
- action (silenced / allowed / snoozed / released)
- reviewed flag, digest id

**Privacy (Proposed, aligned with `privacy.md`)**

- Stored in private app storage only.
- Excluded from Android cloud backup.
- Wiped by "Reset All Rules & Log".
- Not included in the `.notiflow` backup file (that stays rules-only).
- `privacy.md` and the Play Store data-safety answers must be updated when this ships.

### Accurate counts (Decided)

- Apps such as WhatsApp re-post/update the same notification as new messages arrive. Counts must be based on unique notifications/conversations, not raw events, so numbers are not inflated.

### Reviewed state (Decided)

- Opening the digest or dismissing the Notiflow notification marks those items as reviewed.
- Only windows that have ended can be marked reviewed. Opening a window while its rule is still running leaves it unreviewed, so the end-of-rule notification still covers everything silenced in it.
- The Dashboard "review now" card counts only unreviewed items.
- The next digest includes only new items.

### Which apps (Decided)

- All managed apps are included. No per-app include/exclude setting (keep it simple).

### Priority (Decided)

- Inside the digest, conversation/messaging apps are listed before promotional/other apps.

---

## 5. Scheduling & battery

**Decided**

- Primary mechanism is snooze, so Android itself releases the originals; no alarm is needed for that.
- The Notiflow notification uses an **inexact alarm** (may arrive a few minutes late) — no `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM` permission (Android 14 denies it by default and Play policy restricts it).
- An alarm is scheduled **only after the first notification in a window is suppressed** — no suppressed notifications means no alarm, so no battery use.
- Pending digests are rescheduled after a phone restart (`BOOT_COMPLETED` receiver).
- Ask for "battery: unrestricted" **only** if device testing shows digests being missed (OnePlus is aggressive with background apps).

---

## 6. Opening the exact chat

**Decided**

- Solved by snooze: the returned original notification keeps its own tap action.
- The Notiflow notification and items tapped in the in-app Digest open the source app's home screen (the original "open this chat" link is a live system token that cannot be saved to the database).

---

## 7. New Dashboard tab

**Decided**

- New bottom navigation on phone: **Dashboard | Rules | Activity | Settings** (revised; originally Dashboard | Rules | Apps | Activity with a header gear for Settings). Add Apps opens as its own page from the Rules tab.
- The app opens on the **Dashboard** tab at launch.
- The top-right profile icon is removed, because a profile icon implies user accounts, which Notiflow does not have.
- Tablet: the left navigation rail shows the same four tabs (Dashboard | Rules | Activity | Settings).
- Built from the current home page styling — same theme, fonts (Tangerine header, existing body fonts) and colours. The product owner may suggest design changes later; no separate design-reference image yet.

### Dashboard contents, top to bottom (Decided)

1. Greeting card (moved from the current home page).
2. Intercepted and Permitted cards (moved, same format, grid and alignment).
3. Quick pause buttons (moved, same format, grid and alignment).
4. Digest overview, e.g. "8 silenced notifications — review now" (unreviewed count; tapping opens the Activity Digest view).

**Decided:** no status line such as "WhatsApp quiet until 5:00 PM" (it does not scale when many apps are scheduled).

### Rules tab

- Keeps the managed app list and rules management (the current home page minus the items moved to the Dashboard).

### Activity tab

- Gains a **Digest** filter alongside **All** and **Silenced**, listing past digests grouped by app with the reviewed state.

### Settings

- **Decided:** a "Catch-up digest" group with an on/off toggle for the Notiflow end-of-rule notification (default: on).
- **Decided:** digests arrive **only when a rule ends**. There is no "deliver at a chosen time" option.

All new UI must support light and dark mode on phone and tablet.

---

## 8. Implementation phases

Work is split into two phases. Phase 1 is in-app only and needs no new permissions, so it can ship and be tested on its own. Phase 2 changes how notifications are silenced and adds the Notiflow notification. Each phase ends with tests, docs, and a device check before moving on.

### Phase 1 — Storage, Dashboard tab and in-app Digest

**Goal:** the user can see what each finished rule window silenced, grouped by app, from a new Dashboard tab and an Activity Digest view. Notification behaviour on the phone is unchanged (still cancelled during rules, exactly as today).

**Status:** 1.1–1.5 implemented; automated checks and migration verified on the connected phone. A real notification through an ending rule still needs an end-to-end device check. Notes on how it was built:
- The database is written natively in Kotlin (`NotiflowDatabase.kt`, `SQLiteOpenHelper`) because the listener service records events while Flutter is not running; Flutter reads it over the method channel.
- A window is "the continuous period the app is silenced", found by scanning the schedule minute by minute. So overlapping rules, and a pause that falls inside a rule, form one window. A pause on its own forms its own window. Permanent mute (silenced for more than 8 days) has no window.
- Kotlin unit tests cover the window calculation. Android instrumentation tests exercise SQLite de-duplication, pruning, migration and reviewed-state persistence in a separate test database.

#### 1.1 Local database

- Create the on-device SQLite database (see section 10 for how it is written).
- Tables (proposed):
  - `notification_events` — one row per notification seen for a managed app: id, package name, app name, title, text (truncated), post time, notification key, conversation key, action (silenced / allowed / snoozed / released), rule id, window id, reviewed flag.
  - `rule_windows` — one row per rule window instance: window id, package name, rule id, start time, end time, status (active / ended / released), digest posted flag.
- Indexes on post time, package name and window id.
- Automatic 30-day pruning (run when the app opens and once a day from the listener service).
- One-time migration: copy the existing 150-event Activity log from `SharedPreferences` into the database, then remove the old key.
- "Reset All Rules & Log" in Settings wipes the database.
- Cloud backup already disabled (`allowBackup="false"` in `AndroidManifest.xml`); confirm `data_extraction_rules.xml` also excludes the database.

#### 1.2 Recording rule windows

- When the listener silences a notification, work out which rule window it belongs to, including:
  - overlapping rules for the same app (merged into one window that ends when the app stops being silenced);
  - rules that cross midnight;
  - temporary pauses (a pause is its own window);
  - permanent mute (no window; events are stored but never form a digest).
- De-duplicate: an update to the same notification key, or a new message in the same conversation, updates the existing row instead of adding a new one, so counts are accurate.
- A window is marked "ended" when its end time passes. In Phase 1 this is detected when the app opens or the listener next runs (no alarms yet).

#### 1.3 Activity tab

- Read the Activity list from the database instead of `SharedPreferences` (no 150-event cap; 30 days of history).
- Add a **Digest** filter next to **All** and **Silenced**:
  - one card per ended window: app icon, app name, window time range (date + time in the existing format), unique notification count;
  - expanding a card shows its notifications (bold title, regular text, same sizes as today's records);
  - messaging/conversation apps listed before promotional/other apps;
  - unreviewed windows visually marked; opening a card marks it reviewed once its rule has ended;
  - tapping a notification opens the source app's home screen.
- Empty state when there is nothing to catch up on.

#### 1.4 New Dashboard tab

- New `DashboardScreen` tab; the current home page becomes the **Rules** tab.
- Move, in the same format, grid and alignment as today:
  1. greeting card;
  2. Intercepted and Permitted cards;
  3. quick pause buttons.
- Add below them the **digest overview** card: "N silenced notifications — review now" (unreviewed count only; hidden or shown as "All caught up" when zero). Tapping opens Activity → Digest.
- No "WhatsApp quiet until…" status line.
- Same theme, fonts and colours as the current app; light and dark mode on phone and tablet.

#### 1.5 Navigation

- Phone bottom bar and tablet rail: **Dashboard | Rules | Activity | Settings** (revised after Phase 2; Add Apps opens from Rules).
- The app opens on the Dashboard tab.
- Remove the top-right profile icon.
- Update any code that switches tabs by index (e.g. "Add app" shortcuts, onboarding finish).

#### 1.6 Tests, docs and device check

- Unit tests: window calculation (overlap, midnight, pause, permanent mute), de-duplication, 30-day pruning, migration from `SharedPreferences`, reviewed state.
- Widget tests: Dashboard layout, Digest filter, navigation order — light/dark, phone/tablet.
- Update `README.md`, `APP_FEATURES.md`, `privacy.md` (new storage and retention), `architecture.md`.
- Install on the phone and check the Activity history survives the migration.

**Phase 1 is done when:** the Dashboard is the start tab, Activity shows a complete 30-day history with a working Digest filter, counts match unique notifications, and all tests pass.

### Phase 2 — Snooze, end-of-rule notification and permission

**Goal:** when a rule ends, the original notifications come back by themselves and Notiflow posts one short "quiet hours ended" notification.

**Status:** 2.1–2.6 implemented; Kotlin unit tests and widget tests pass. Device checks (2.7) still pending. Notes on how it was built:
- Silenced notifications are snoozed until one minute after the window's last silenced minute. Cancel is kept for permanent mute, eligible foreground notifications, and Android below 8.0. Recognized call notifications are now left untouched.
- Held notifications are tracked in their own table, `held_notifications` (key, package, window, release time), so a returning original is recognised even if its event was de-duplicated. Database version 2 also adds a `delivery` column to `notification_events` (snoozed / released / removed). The event `action` stays "silenced"; delivery is tracked separately instead of the proposed action values.
- Decisions are evaluated at the current time, not the notification's original post time, because a returning snoozed notification can keep its old post time.
- After a rule change the bridge re-checks held notifications: still silenced with a new end → re-snoozed; no longer silenced or window over → released by re-snoozing for 1 second; permanent mute → cancelled.
- The digest is posted by the listener 15 seconds after originals start returning; an inexact `setWindow` alarm (10-minute window) is the backup. Windows ending within 3 minutes of each other share one notification (held back at most 10 minutes).
- `digest_posted`: 0 pending, 1 shown, 2 skipped (toggle off or no permission). Skipped windows are never posted later; they remain in the in-app Digest.
- After a reboot or app update, `DigestBootReceiver` posts any due digest and re-schedules the alarm. When the listener reconnects, held notifications that are no longer snoozed or active are marked removed.

#### 2.1 Snooze instead of cancel

- During a rule window or temporary pause, snooze the notification until the window's end time instead of cancelling it.
- Keep cancelling for: permanent mute, and ongoing/foreground notifications (media, navigation, uploads).
- Record each snoozed notification in the database as "snoozed"; mark it "released" when it comes back (stored in the `delivery` column, see Status).
- When a released notification comes back, the listener must let it through (the rule has ended) and must not log it as a new event.
- If the source app removes the notification during the window, mark it removed; it still appears in the in-app Digest.

#### 2.2 Rule changes while notifications are snoozed

- End time changed: re-snooze held notifications to the new end time and move the Notiflow notification.
- Window already over after the edit: release immediately and send the digest.
- Rule deleted, app removed from Notiflow, or rules turned off for that app: release immediately.

#### 2.3 Notiflow end-of-rule notification

- Notification channel "Catch-up digest" (one sound; returned originals come back quietly where Android allows it).
- Single app: title "WhatsApp quiet hours ended", body "12 notifications are back".
- Several windows ending together: title "Quiet hours ended", body "WhatsApp 12 · Slack 4".
- Lock screen shows the total only (public version).
- App names and counts only — no sender names or message text.
- Never posted for an empty window; posted even for a single notification.
- Tapping opens Notiflow on Activity → Digest; tapping or dismissing marks those windows reviewed.
- Respects the Settings toggle.

#### 2.4 Scheduling and restarts

- Inexact alarm scheduled only when the first notification of a window is silenced (no alarm when nothing is silenced).
- Windows ending within the same few minutes are combined into one notification.
- `BOOT_COMPLETED` receiver re-schedules pending digest alarms and re-checks held notifications after a restart.
- No exact-alarm permission; ask for "battery unrestricted" only if testing shows missed digests.

#### 2.5 Notification permission

- Add `POST_NOTIFICATIONS` to `AndroidManifest.xml`.
- Ask on the first open after install, and on the first open after updating to this version, if not already granted (Android 13+).
- Ask once only; the Settings toggle re-asks or opens system notification settings.

#### 2.6 Settings

- New "Catch-up digest" group with the on/off toggle (default on) and the permission state.

#### 2.7 Tests, docs and device check

- Unit/Kotlin tests: snooze vs cancel decision, re-snooze on edit, release on delete, combining windows, alarm only when needed.
- Widget tests: Settings toggle and permission prompt flow, light/dark, phone/tablet.
- Device tests on OnePlus CPH2573: originals return at the right time and open the right chat, whether they come back silently, behaviour after a restart, 20+ notifications returning at once, battery behaviour over a day.
- Update `README.md`, `APP_FEATURES.md`, `privacy.md`, `android-notification-flow.md`, Play Store data-safety notes.

**Phase 2 is done when:** a rule ending brings back the original notifications and exactly one Notiflow notification, rule edits and deletions behave as in 2.2, and all device checks pass.

#### 2.8 Device test findings (OnePlus CPH2573, Android 16)

Scenarios seen while testing on the phone, what happened, and the outcome.

| # | Scenario | What happened | Outcome |
|---|---|---|---|
| 1 | Rule ends normally (e.g. WhatsApp rule ending 22:49) | Held originals came back about 1 minute after the end (`delivery = released`) | Works as designed |
| 2 | Timing of the Notiflow notification | Rule ending 22:57 → notification at 22:58:15 (end + 1 minute release + 15 s settle) | Works as designed |
| 3 | Message arrives during the rule's last minute (23:00:34 for a rule ending 23:00) | Still silenced, because rules work in whole minutes; held and returned at 23:01 | Works as designed |
| 4 | Window opened in Activity → Digest **while the rule was still running** | Opening the card marked the window reviewed, so no end-of-rule notification was posted | **Fixed:** only ended windows can be marked reviewed (Activity screen and database both enforce it) |
| 5 | Rule **end time extended after** its notification was already posted (22:57 → 23:00) | New silenced items joined the old, already-notified window, so no new notification | **Fixed:** a window whose notification was handled is never reused or extended; a new window starts where the old one ended and gets its own notification |
| 6 | Notiflow swiped away from Recents before the rule ended | The notification listener kept running (process stayed alive); the missing notification was caused by scenario 5, not by the swipe | Works; keep checking on other phones with aggressive battery savers |
| 7 | Tapping the Notiflow notification | Opened Activity → Digest and marked those windows reviewed | Works as designed |
| 8 | `POST_NOTIFICATIONS` permission | Asked once on first open after the update; granted | Works as designed |
| 9 | "Catch-up digest" channel on OnePlus | Default importance, but OnePlus turns banners off for new channels, so the notification appears in the shade without a pop-up | Device setting; the user can enable banners in system notification settings |

Still to check on the device: behaviour after a restart, 20+ notifications returning at once, whether returned originals alert again, and battery use over a day.

## 9. Decision — swipe to delete (v1.6.1)

**Decided with the product owner:**

- Swiping a card from left to right in the Activity log (All / Silenced / Allowed, phone and tablet) deletes it. A grouped card deletes every message in it. The details sheet has a matching "Delete" button.
- Deleting a message from the log **also removes it from its digest**. The digest card's count drops, and a card with nothing left disappears.
- The **Digest tab supports swipe-to-delete** too: swiping a digest card left to right deletes every message that window silenced, from both the digest and the log.
- The swipe background is a soft light red (`lightErrorContainer` `#FFDAD6` with dark-red text; dark mode `#5C2A26` with light-pink text) to match the theme's muted palette.
- No confirm dialog. The card goes at once and an info `AppToast` with "Undo" shows for 4 seconds. The native delete runs only when the toast closes without Undo (timeout, ×, or replaced); starting another delete replaces the previous toast, which commits it.

**Implementation notes:**

- Kotlin `NotiflowDatabase.deleteEvents(ids)` deletes the rows and any group-summary row of the same app within ±5 s that no longer has a real message next to it (otherwise the hidden summary would show up in the log).
- `deleteWindowEvents(windowIds)` deletes all of a window's events but keeps the `rule_windows` row, so a rule that is still running keeps using it.
- Both run `DigestNotifier.onReviewed`, which removes the end-of-rule notification if nothing it listed is left, and fire `onActivityUpdated`.
- Channel methods: `deleteActivityEvents` (`ids`: event id strings) and `deleteDigestWindows` (`ids`: window ids).
- The Activity screen keeps swiped ids in hidden sets until the reload after the delete, so a background refresh during the Undo period can't bring them back.

## 10. Decision — how the database is written

The listener that records notifications runs in Kotlin, even when the Flutter part of the app is closed. The `sqflite` package only works from Dart while the app is open, so it cannot record notifications in the background.

**Decided:** keep the agreed SQLite database, but have the Kotlin side write to it using Android's built-in SQLite, and let the Dart screens read it through the existing platform channel (as the Activity log does today). The database, 30-day retention and every other decision stay the same; only the `sqflite` package itself would not be needed.

**Status:** confirmed by the product owner (17 Nov 2026).
