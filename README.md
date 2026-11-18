# Notiflow — Privacy-First Notification Scheduler & Focus Shield

> **Quiet focus, on your schedule. 100% On-Device · Zero Telemetry · Zero Internet Permission.**

[![Build & Release Android APK](https://github.com/nawabrahbar/notiflow/actions/workflows/build-apk.yml/badge.svg)](https://github.com/nawabrahbar/notiflow/actions/workflows/build-apk.yml)
[![Latest Release](https://img.shields.io/github/v/release/nawabrahbar/notiflow?color=F59E0B&label=Latest%20Release)](https://github.com/nawabrahbar/notiflow/releases/latest)
[![Download APK](https://img.shields.io/badge/Download-Latest%20APK-F59E0B?logo=android&logoColor=black)](https://github.com/nawabrahbar/notiflow/releases/latest/download/notiflow-latest.apk)

**Notiflow** is an offline, privacy-first Android application built with Flutter and a native Kotlin `NotificationListenerService` engine. It gives you deterministic, schedule-based control over when specific apps are allowed to notify you—silencing distractions during deep work or sleep while recording muted notifications locally so you never miss important details.

---

## 📦 Download & Releases (Android APK)

Every push to `main` is automatically built and published by GitHub Actions. You can download and install the `.apk` directly on your Android phone:

| Resource | Direct Link | Description |
| :--- | :--- | :--- |
| **📲 Direct APK Download (Latest)** | **[Download `notiflow-latest.apk`](https://github.com/nawabrahbar/notiflow/releases/latest/download/notiflow-latest.apk)** | One-tap direct download of the newest Release `.apk` for phone install |
| **🏪 Play Store Bundle (`.aab`)** | **[Download `notiflow-latest.aab`](https://github.com/nawabrahbar/notiflow/releases/latest/download/notiflow-latest.aab)** | Signed Android App Bundle (`.aab`) ready for Google Play Console upload |
| **🏷️ Latest Release Page** | **[View Latest Release](https://github.com/nawabrahbar/notiflow/releases/latest)** | Release notes, versioned `.apk`, and versioned `.aab` |
| **🗂️ All Releases Archive** | **[Browse All Releases](https://github.com/nawabrahbar/notiflow/releases)** | Complete history of all published Notiflow builds |
| **⚙️ GitHub Actions Builds** | **[View CI/CD Workflow Runs](https://github.com/nawabrahbar/notiflow/actions/workflows/build-apk.yml)** | Live build logs and PR workflow artifacts |

---

## ✨ Key Features

### 1. Precision App-Specific Scheduling
- **Per-App Focus Rules**: Configure custom notification schedules for any installed application (WhatsApp, Slack, Teams, Gmail, Instagram, etc.).
- **Dual Interception Modes**:
  - **BLOCK Mode (`blockDuring` / `allDayBlock`)**: Silence notifications during the specified time window and allow them outside it.
  - **ALLOW Mode (`allowDuring` / `allDayAllow`)**: Only allow notifications during the specified window and silence them at all other times.
- **Overnight Schedule Math**: Seamlessly handles schedules that cross midnight (e.g., `20:00` to `08:00` the next morning) with day-of-week awareness.
- **7-Day Recurrence & Quick Presets**: Select individual days (`M` `T` `W` `T` `F` `S` `S`) or one-tap presets (*Everyday*, *Weekdays*, *Weekends*) with custom rule names.
- **Apply Rules to Many Apps**: The floating *Apply rules* button on the Rules tab applies one or more saved rules to many apps in one go (phone: Rules → Apps → Review steps; tablet: side by side). Duplicates are skipped, and a result sheet lets you undo a single rule, a whole app or the entire batch. See [`docs/apply-rules.md`](docs/apply-rules.md).

### 2. Notification Activity Log & Local Vault
- **Managed App Notification Capture**: Notifications from home-page apps are recorded locally whether silenced, allowed, or paused. Silenced alerts are suppressed from the status bar; allowed and paused alerts pass through normally. Each record includes:
  - **Original Installed App Icon & Display Name** (with the stored icon as fallback if the app is no longer installed)
  - **Notification Title / Sender** (e.g., contact name, group chat title, or email subject)
  - **Full Message Body** (supports multi-line `EXTRA_BIG_TEXT` and inbox-style lines)
  - **Channel / Subtext** (e.g., conversation or account name)
  - **Exact Timestamp** and **Triage Rule Reason** (e.g., `Blocked by ‘Work Focus’ rule (09:00 - 17:00)` or `Silenced by Global Mute override`)
- **Conversation Cards**: Back-to-back messages from the same app and person (same status, within 30 minutes of each other) are grouped into one expandable card. Duplicate group summaries and your own replies are not logged.
- **Real-Time Feed & Filters**: Live-updating stream with **All**, **Silenced**, **Allowed** and **Digest** filter chips, pull-to-refresh, and focus metrics (*Intercepted*, *Focus Gain*, *0% Leak Rate*).
- **30-Day On-Device History**: Events live in a private SQLite database (`notiflow.db`) and are pruned automatically after 30 days.
- **Catch-Up Digest (in-app)**: When a rule window ends, the **Digest** filter shows one card per app and window with the number of unique notifications it silenced. Messaging apps come first, new windows are marked until opened, and the **Dashboard** shows "N silenced notifications — Review now".
- **Interactive Notification Inspector**: Tap any recorded notification card to open a bottom sheet with full selectable message text (`SelectableText` for copying OTPs/messages) and a one-tap **Open App** button.

### 3. Quick Mute · All apps & Per-App Overrides
- **Quick Mute · All apps**: mute every app for **15m**, **30m** or **1h** from the Dashboard. A live "All apps muted · N min left" card offers **+15m** and **End now**, and **Let repeat callers ring through** lets a 2nd call within 3 min ring.
- **Per-App Instant Mute Pills**: Temporarily mute any individual app for **15m**, **30m**, **1h**, or **Today 24h** from the App Details screen without altering recurring schedules.

### 4. Rules Backup & Portability (`.notiflow`)
- **Export `.notiflow` Backup File**: Serialize all managed apps, schedules, and preferences into a `.notiflow` file (`notiflow_backup_<timestamp>.notiflow`) and save it directly to your chosen folder on device storage via Android's native Storage Access Framework (`Intent.ACTION_CREATE_DOCUMENT`).
- **1-Tap Import from Storage**: Settings → Import opens the system file picker directly (`Intent.ACTION_OPEN_DOCUMENT`) and restores the selected `.notiflow` file in place, then shows an **Import complete** bottom sheet listing imported apps, apps waiting for install, skipped apps and saved rules.

### 5. 100% On-Device Privacy, Semantic Feedback & Zero Telemetry
- **Zero Network Access**: `android.permission.INTERNET` is completely omitted from [`AndroidManifest.xml`](android/app/src/main/AndroidManifest.xml). It is physically impossible for the app to transmit data off your device.
- **Privacy Policy**: View the official Play Store Privacy Policy at **[nawabrahbar.github.io/notiflow/privacy-policy.html](https://nawabrahbar.github.io/notiflow/privacy-policy.html)** (or [`PRIVACY_POLICY.md`](PRIVACY_POLICY.md)).
- **Unmanaged Apps Untouched**: Apps you haven't added to Notiflow pass through the OS untouched.
- **Semantic State Toasts & Obsidian Signal Design**: High-contrast Dark (`#09090B`) and Crisp Light (`#F9F9FB`) themes with Signal Amber (`#F59E0B`) accents, semantic toast notifications (**Success Sage** `#CCD5AE`, **Info Soft Blue** `#D3E3EE`, **Warning Orange** `#F59E0B`, **Error Red** `#EF4444`), custom 60/120fps animated vector emblems, and dynamic time-of-day greetings.

### 🔔 Catch-Up Digest Phase 2
- During a rule window or pause, silenced notifications are snoozed instead of cancelled. When the rule ends they come back by themselves and Notiflow posts one short "quiet hours ended" notification (app names and counts only). Tapping it opens Activity → Digest.
- Rule edits re-snooze or release held notifications; permanent mute and ongoing notifications are still cancelled.
- Asks for `POST_NOTIFICATIONS` once on Android 13+, with a **Catch-up Digest** toggle in Settings. See [`docs/catch-up-digest.md`](docs/catch-up-digest.md) for the full spec.

---

## 🧭 App Screens & Architecture

Notiflow is organized into **11 screens** across a clean 4-layer architecture (`domain`, `data`, `platform`, `presentation`):

| # | Screen | File | Description |
| :--- | :--- | :--- | :--- |
| 1 | **Startup Routing** | [`lib/main.dart`](lib/main.dart) | Android shows the app icon while initializing, then opens Onboarding, Permission, or the main shell (no Flutter splash) |
| 2 | **Onboarding Screen** | [`lib/presentation/screens/onboarding_screen.dart`](lib/presentation/screens/onboarding_screen.dart) | 3-step onboarding with direct 1-tap notification access setup |
| 3 | **Permission Center** | [`lib/presentation/screens/permission_screen.dart`](lib/presentation/screens/permission_screen.dart) | Quick 2-step permission recovery with auto-return & OEM battery tips |
| 4 | **Import Rules** | [`lib/presentation/screens/import_rules_screen.dart`](lib/presentation/screens/import_rules_screen.dart) | Onboarding step 3 backup import; Settings → Import opens the system file picker directly |
| 5 | **Navigation Shell** | [`lib/presentation/screens/main_navigation_shell.dart`](lib/presentation/screens/main_navigation_shell.dart) | Phone bottom navigation and tablet rail with *Dashboard*, *Rules*, *Activity* and *Settings*; Add Apps opens from the Rules tab |
| 6 | **Dashboard (Rules)** | [`lib/presentation/screens/dashboard_screen.dart`](lib/presentation/screens/dashboard_screen.dart) | Time-based greeting, triage counters, global overrides, managed apps, *Apply rules* button |
| 6a | **Apply Rules** | [`lib/presentation/screens/bulk_apply_screen.dart`](lib/presentation/screens/bulk_apply_screen.dart) | Bulk-apply saved rules to many apps; result sheet with undo in [`bulk_apply_result_sheet.dart`](lib/presentation/widgets/bulk_apply_result_sheet.dart) |
| 7 | **Add Apps Screen** | [`lib/presentation/screens/add_apps_screen.dart`](lib/presentation/screens/add_apps_screen.dart) | Installed app discovery, search, and category filters (*Messaging*, *Social*, etc.) |
| 8 | **App Details Screen** | [`lib/presentation/screens/app_details_screen.dart`](lib/presentation/screens/app_details_screen.dart) | Quick mute pills, multiple schedule rules list, and + Add Schedule button |
| 9 | **Schedule Editor** | [`lib/presentation/screens/schedule_editor_screen.dart`](lib/presentation/screens/schedule_editor_screen.dart) | Quick Load Template dropdown with deduplication, BLOCK/ALLOW mode, time pickers, overnight badge, and day pills |
| 10 | **Activity Log** | [`lib/presentation/screens/activity_screen.dart`](lib/presentation/screens/activity_screen.dart) | Silenced and allowed notifications from managed apps, including paused apps, with full details and app launcher sheet |
| 11 | **Settings Screen** | [`lib/presentation/screens/settings_screen.dart`](lib/presentation/screens/settings_screen.dart) | Service health, on-device privacy audit, `.notiflow` backup/restore, reset |

### Native Android Engine (`android/app/src/main/kotlin/...`)
- **[`NotificationHandlerListenerService.kt`](android/app/src/main/kotlin/com/notificationhandler/notification_handler/NotificationHandlerListenerService.kt)**: System-bound `NotificationListenerService` that intercepts posted notifications, extracts notification title/message/channel extras, records triage events, and cancels muted notifications in `< 5ms`.
- **[`NativeScheduleStore.kt`](android/app/src/main/kotlin/com/notificationhandler/notification_handler/NativeScheduleStore.kt)**: Pure Kotlin schedule evaluator (`NativeScheduleEvaluator`) and persistent store (`SharedPreferences` for schedules, SQLite `notiflow.db` via `NotiflowDatabase.kt` for 30-day activity history and digest windows) that runs independently even when the Flutter UI is closed.
- **[`AndroidNotificationBridge.kt`](android/app/src/main/kotlin/com/notificationhandler/notification_handler/AndroidNotificationBridge.kt)**: MethodChannel bridge (`com.notificationhandler/bridge`) connecting Flutter with Android package discovery, direct Notification Access deep-linking (`ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS`) with automatic foreground return, `.notiflow` file import/export, app launching, and real-time activity updates.

---

## 📋 Changelog & Recent Updates

- **v1.6.1 (`+11`) — Shared Installed-Apps Cache, Faster Activity Log & Uninstalled-App Handling**:
  - **Shared installed-apps cache**: one app-wide list loads in the background after the dashboard appears; icons are fetched on demand and only changed packages refresh on resume.
  - **Faster Activity log**: entries show immediately; log and digest load in parallel off the Android main thread.
  - **Add Apps**: icons load in screen-sized batches (phone and tablet); frosted bottom search bar with edge fade.
  - **Uninstalled apps**: Rules cards and Activity entries grey out with an "Uninstalled" label; the rule stays until deleted.
  - **Swipe to delete**: swipe an Activity log or Digest card from left to right to delete it, with Undo; deleted messages leave both the log and the digest.
  - **New toasts**: one shared `AppToast` (`lib/presentation/widgets/app_toast.dart`) replaces every SnackBar. It is a rounded card with a type icon, message, × (or Undo) and a countdown bar. It slides in from the left, slides out to the right after 3 s (4 s with Undo, at once on ×), and floats above everything, including the phone nav bar, dialogs and sheets.
  - **Quick Mute · All apps**: replaces the old Quick Session Overrides on the Dashboard (phone and tablet). It mutes every app for 15m, 30m or 1h, then shows a live "All apps muted · N min left" card with +15m and End now. Repeat callers (a 2nd call within 3 min) now ring through during these mutes when "Let repeat callers ring through" is on.
  - **Import summary sheet**: after a successful `.notiflow` import (Settings or onboarding), an **Import complete** bottom sheet replaces the success toast. Collapsible sections (all expanded at first) show Imported apps with rule counts, apps Waiting for install (vaulted; each has a × to remove it from the vault after a confirmation dialog), Skipped apps (excluded) and Saved rules, with View Rules and Done buttons. `ScheduleRepository.importRulesWithReport` returns the `ImportReport` behind it.
  - **Rules page Add App button**: the *"+ Add App"* text button in the MANAGED APPS header is now a floating **Add app** button above *Apply rules* (shrinks on scroll, hidden in multi-select and when no apps are managed).
  - **Apply rules to many apps**: new floating *Apply rules* button on the Rules tab (shrinks while scrolling, hidden in multi-select). It opens a wizard (`BulkApplyScreen`) to pick saved rules (or create a new one with **New rule**, which is saved and selected) and apps, with review counts (*"X new schedules · Y already applied"*), then a **Rules applied** sheet with per-rule ×, per-app undo and Undo all. Pre-existing schedules and apps are never removed. `ScheduleRepository.applyTemplatesToApps` / `removeBulkAppliedRules` back it. Spec: [`docs/apply-rules.md`](docs/apply-rules.md).
- **v1.6.0 (`+10`) — Botanical Sanctuary Redesign, Rule Templates, Tablet Expansion & Native Hardening**:
  - **Botanical Sanctuary & Nocturne Redesign**: Warm Canvas (`#FEF8F6`) / Deep Forest (`#101412`), Terracotta (`#7D562D` / `#FCBC76`), and Sage Green (`#5A6242` / `#BECCA3`) with elegant Newsreader display serifs and Plus Jakarta Sans body typography.
  - **Seamless Canvas Flow**: Completely eliminated header bottom borders and dividers across all screens for a unified, tranquil surface.
  - **Urgent Repeated Call Bypass (< 3 Minutes) Native Fix**: Fixed incoming call interception in native Kotlin (`NotificationHandlerListenerService.kt` & `NativeScheduleStore.kt`). Ringing calls are no longer skipped as ongoing foreground events; a 1st call during quiet hours is silenced while arming a 3-minute window, and a 2nd call from the same caller within 180 seconds immediately rings through.
  - **Material You Dynamic Themed App Icon**: Added monochrome adaptive launcher icon layer (`<monochrome>`), enabling Android 13+ device home screens and app drawers to dynamically theme Notiflow in light or dark mode following system appearance.
  - **Light / Dark App Icon**: The launcher icon and launch screen use the light design (`assets/icon/app_icon_light.png`) in light mode and the dark design (`assets/icon/app_icon.png`) in dark mode, via `-night` resource folders.
  - **First-Launch Theme Sync & Explicit User Preference**: Opens strictly following device system appearance on initial launch, then retains explicit user preference across subsequent sessions once toggled.
  - **Responsive Phone & Tablet Architecture**:
    - **Adaptive Navigation**: Bottom navigation bar on phones (<600dp) and an 88dp left Navigation Rail with emblem on tablets (≥600dp), both with 4 tabs (Dashboard, Rules, Activity, Settings). Add Apps opens as its own page from Rules.
    - **Dashboard Bento**: 5:7 two-column responsive bento on tablet.
    - **Add Apps Screen**: 2-column responsive grid on tablet with 5 category filter chips.
    - **App Details Screen**: 5:7 two-column split on tablet.
    - **Schedule Editor Screen**: 7:5 two-column split on tablet.
    - **Settings Screen**: 6:6 two-column bento on tablet with storage audit and diagnostic cards.
    - **Onboarding & Permission Centers**: Centered editorial cards (max 680dp) on tablet.
  - **Smart Backup Import & Dormant Vault**: Detects uninstalled apps in `.notiflow` backups and offers to *"Keep in Vault & Auto-Apply on Install"* (safely parked in local DB and auto-applied when installed) or *"Exclude These Apps"*. Settings → **Dormant Vault** card opens a sheet listing parked apps, each with a × to remove it (after confirmation).
  - **Quick Load Rule Templates**: Reusable schedule rule dropdown with deduplication, pre-seeded with `"Focus Hours"` (09:00 AM – 05:00 PM, Mon–Fri); the default is fixed, while other saved rules can be fully edited (name, behaviour, times, days, VIP) from Settings → Saved Rules without changing apps already using them.
  - **Multiple Schedules per App**: Full support for attaching multiple active schedules to a single app with independent monitoring switches.
  - **Unified `.notiflow` Backup**: Single backup file format bundling rule templates alongside managed apps and schedules with 100% backward compatibility.
  - **Google Play In-App Updates**: Added zero-network In-App Update checker via Play Core IPC (`in_app_update`), maintaining strict 100% on-device privacy with **zero `INTERNET` permission** in [`AndroidManifest.xml`](android/app/src/main/AndroidManifest.xml).
  - **12-Hour vs 24-Hour Time Format Option**: Added configurable time display preference under Settings, instantly updating schedule cards, dropdown templates, and activity logs across the entire app.
  - **Phone & Tablet Form Factors**: Restricted supported screen targets exclusively to Phone and Tablet devices.
- **v1.5.4 (`+9`) — Direct Permission Deep-Link, Auto-Return & Clean Play Store Onboarding**:
  - Removed the *"Sideloaded APK blocked on Android 13+?"* and *"Allow Restricted Settings"* cards from [`onboarding_screen.dart`](lib/presentation/screens/onboarding_screen.dart) and [`permission_screen.dart`](lib/presentation/screens/permission_screen.dart) for a clean Play Store onboarding experience.
  - Updated [`AndroidNotificationBridge.kt`](android/app/src/main/kotlin/com/notificationhandler/notification_handler/AndroidNotificationBridge.kt) to deep-link directly to Notiflow's `Allow notification access` switch (`Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS`) on Android 11+, skipping the all-apps list.
  - Added automatic foreground return to Notiflow the moment the user toggles Notification Access ON in Android Settings.
- **v1.5.3 (`+8`) — Semantic Toast Colors by State**:
  - Updated all `SnackBar` toasts across the app to match project state colors: **Success Green** (`#22C55E`), **Error Red** (`#EF4444`), and **Warning Orange** (`#F59E0B`).
- **v1.5.2 (`+7`) — Google Play Store `.aab` Bundle & Release Signing**:
  - Configured release upload keystore signing in [`android/app/build.gradle.kts`](android/app/build.gradle.kts) and updated [`.github/workflows/build-apk.yml`](.github/workflows/build-apk.yml) to publish signed `.aab` bundles alongside `.apk` installers on GitHub Releases.
- **v1.5.1 (`+6`) — Real `.notiflow` Backup File Export/Import & Play Store Privacy Policy**:
  - Fixed **Export Rules Backup** in [`AndroidNotificationBridge.kt`](android/app/src/main/kotlin/com/notificationhandler/notification_handler/AndroidNotificationBridge.kt) to save a real `.notiflow` file via Android's system file saver (`ACTION_CREATE_DOCUMENT`) instead of sharing plain text, and enabled direct 1-tap `.notiflow` file selection on [`ImportRulesScreen`](lib/presentation/screens/import_rules_screen.dart).
  - Added Play Console-compliant [`PRIVACY_POLICY.md`](PRIVACY_POLICY.md) and GitHub Pages [`docs/privacy-policy.html`](docs/privacy-policy.html).
- **v1.5.0 (`+5`) — Muted Notification Activity Log & Automated GitHub Releases**:
  - Added full muted notification capture (title, message body, subtext, rule reason, app icon, real-time feed updates, and interactive details bottom sheet with **Open App**).
  - Added automated GitHub Actions CI/CD workflow for building and publishing release artifacts.

---

## 🛠️ Local Development & Building from Source

### Prerequisites
- Flutter SDK (`>= 3.44.0` / Dart `>= 3.13.4`)
- JDK 17 & Android SDK

### Commands
```bash
# 1. Install dependencies
flutter pub get

# 2. Run Dart unit & widget tests
flutter test

# 3. Build release APK & Play Store App Bundle (.aab)
flutter build apk --release
flutter build appbundle --release
```

For detailed screen-by-screen specifications, future roadmap, and flow diagrams, see [`APP_FEATURES.md`](APP_FEATURES.md), [`plan.MD`](plan.MD), and the [`docs/`](docs/) directory.

