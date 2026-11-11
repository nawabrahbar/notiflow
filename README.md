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

### 2. Muted Notification Activity Log & Local Vault
- **Full Muted Notification Capture**: Whenever a notification arrives while an app is muted, Notiflow suppresses the alert from your status bar and records its full details locally on-device:
  - **App Icon & Display Name**
  - **Notification Title / Sender** (e.g., contact name, group chat title, or email subject)
  - **Full Message Body** (supports multi-line `EXTRA_BIG_TEXT` and inbox-style lines)
  - **Channel / Subtext** (e.g., conversation or account name)
  - **Exact Timestamp** and **Triage Rule Reason** (e.g., `Blocked by ‘Work Focus’ rule (09:00 - 17:00)` or `Silenced by Global Mute override`)
- **Real-Time Feed & Filters**: Live-updating stream with **All**, **Silenced**, and **Allowed** filter chips, pull-to-refresh, and focus metrics (*Intercepted*, *Focus Gain*, *0% Leak Rate*).
- **Interactive Notification Inspector**: Tap any recorded notification card to open a bottom sheet with full selectable message text (`SelectableText` for copying OTPs/messages) and a one-tap **Open App** button.

### 3. Quick Session Overrides (Global & Per-App)
- **Global Session Overrides**: Engage **Mute All (15m)**, **Mute All (1h)**, or **Pass Calls** directly from the Dashboard with a live countdown banner and one-tap **Restore**.
- **Per-App Instant Mute Pills**: Temporarily mute any individual app for **15m**, **30m**, **1h**, or **Today 24h** from the App Details screen without altering recurring schedules.

### 4. Rules Backup, Portability (`.notiflow`) & Curated Presets
- **Export `.notiflow` Backup File**: Serialize all managed apps, schedules, and preferences into a `.notiflow` file (`notiflow_backup_<timestamp>.notiflow`) and save it directly to your chosen folder on device storage via Android's native Storage Access Framework (`Intent.ACTION_CREATE_DOCUMENT`).
- **1-Tap Import from Storage or Clipboard**: Restore rules in a single tap by selecting an exported `.notiflow` file from device storage (`Intent.ACTION_OPEN_DOCUMENT`), or paste raw backup JSON text.
- **3 Built-In Focus Protocols**:
  - **Deep Work Protocol**: Blocks Slack, Teams, and Gmail from `09:00 – 17:00` (Mon–Fri).
  - **Mindful Evening**: Blocks Instagram, X, and YouTube overnight from `20:00 – 08:00` (Everyday).
  - **Minimalist Default**: Holds WhatsApp notifications 24/7 while letting phone calls and SMS pass through.

### 5. 100% On-Device Privacy, Semantic Feedback & Zero Telemetry
- **Zero Network Access**: `android.permission.INTERNET` is completely omitted from [`AndroidManifest.xml`](android/app/src/main/AndroidManifest.xml). It is physically impossible for the app to transmit data off your device.
- **Privacy Policy**: View the official Play Store Privacy Policy at **[nawabrahbar.github.io/notiflow/privacy-policy.html](https://nawabrahbar.github.io/notiflow/privacy-policy.html)** (or [`PRIVACY_POLICY.md`](PRIVACY_POLICY.md)).
- **Unmanaged Apps Untouched**: Apps you haven't added to Notiflow pass through the OS untouched.
- **Semantic State Toasts & Obsidian Signal Design**: High-contrast Dark (`#09090B`) and Crisp Light (`#F9F9FB`) themes with Signal Amber (`#F59E0B`) accents, semantic toast notifications (**Success Green** `#22C55E`, **Error Red** `#EF4444`, **Warning Orange** `#F59E0B`), custom 60/120fps animated vector emblems, and dynamic time-of-day greetings.

---

## 🧭 App Screens & Architecture

Notiflow is organized into **11 screens** across a clean 4-layer architecture (`domain`, `data`, `platform`, `presentation`):

| # | Screen | File | Description |
| :--- | :--- | :--- | :--- |
| 1 | **Splash Screen** | [`lib/presentation/screens/splash_screen.dart`](lib/presentation/screens/splash_screen.dart) | Animated Stitch emblem, engine initialization, smart route dispatch |
| 2 | **Onboarding Screen** | [`lib/presentation/screens/onboarding_screen.dart`](lib/presentation/screens/onboarding_screen.dart) | 3-step onboarding with direct 1-tap notification access setup |
| 3 | **Permission Center** | [`lib/presentation/screens/permission_screen.dart`](lib/presentation/screens/permission_screen.dart) | Quick 2-step permission recovery with auto-return & OEM battery tips |
| 4 | **Import & Presets** | [`lib/presentation/screens/import_rules_screen.dart`](lib/presentation/screens/import_rules_screen.dart) | `.notiflow` file picker, JSON paste modal, and 3 curated focus presets |
| 5 | **Navigation Shell** | [`lib/presentation/screens/main_navigation_shell.dart`](lib/presentation/screens/main_navigation_shell.dart) | 4-tab bottom navigation (*Rules*, *Apps*, *Activity*, *Settings*) |
| 6 | **Dashboard (Rules)** | [`lib/presentation/screens/dashboard_screen.dart`](lib/presentation/screens/dashboard_screen.dart) | Time-based greeting, triage counters, global overrides, managed apps |
| 7 | **Add Apps Screen** | [`lib/presentation/screens/add_apps_screen.dart`](lib/presentation/screens/add_apps_screen.dart) | Installed app discovery, search, and category filters (*Messaging*, *Social*, etc.) |
| 8 | **App Details Screen** | [`lib/presentation/screens/app_details_screen.dart`](lib/presentation/screens/app_details_screen.dart) | Real-time triage status card, quick mute pills, multiple schedule rules list, and + Add Schedule button |
| 9 | **Schedule Editor** | [`lib/presentation/screens/schedule_editor_screen.dart`](lib/presentation/screens/schedule_editor_screen.dart) | Quick Load Template dropdown with deduplication, BLOCK/ALLOW mode, time pickers, overnight badge, and day pills |
| 10 | **Activity Log** | [`lib/presentation/screens/activity_screen.dart`](lib/presentation/screens/activity_screen.dart) | Muted notification log with full message details and app launcher sheet |
| 11 | **Settings Screen** | [`lib/presentation/screens/settings_screen.dart`](lib/presentation/screens/settings_screen.dart) | Service health, on-device privacy audit, `.notiflow` backup/restore, reset |

### Native Android Engine (`android/app/src/main/kotlin/...`)
- **[`NotificationHandlerListenerService.kt`](android/app/src/main/kotlin/com/notificationhandler/notification_handler/NotificationHandlerListenerService.kt)**: System-bound `NotificationListenerService` that intercepts posted notifications, extracts notification title/message/channel extras, records triage events, and cancels muted notifications in `< 5ms`.
- **[`NativeScheduleStore.kt`](android/app/src/main/kotlin/com/notificationhandler/notification_handler/NativeScheduleStore.kt)**: Pure Kotlin schedule evaluator (`NativeScheduleEvaluator`) and persistent store (`SharedPreferences`) that runs independently even when the Flutter UI is closed.
- **[`AndroidNotificationBridge.kt`](android/app/src/main/kotlin/com/notificationhandler/notification_handler/AndroidNotificationBridge.kt)**: MethodChannel bridge (`com.notificationhandler/bridge`) connecting Flutter with Android package discovery, direct Notification Access deep-linking (`ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS`) with automatic foreground return, `.notiflow` file import/export, app launching, and real-time activity updates.

---

## 📋 Changelog & Recent Updates

- **v1.6.0 (`+10`) — Botanical Sanctuary Redesign, Rule Templates & Play In-App Updates**:
  - **Botanical Sanctuary & Nocturne Redesign**: Warm Canvas (`#FEF8F6`) / Deep Forest (`#101412`), Terracotta (`#7D562D` / `#FCBC76`), and Sage Green (`#5A6242` / `#BECCA3`) with elegant Newsreader display serifs and Plus Jakarta Sans body typography.
  - **Seamless Canvas Flow**: Completely eliminated header bottom borders and dividers for a unified single-page aesthetic.
  - **Quick Load Rule Templates**: Reusable schedule rule dropdown with deduplication, pre-seeded with `"Work Focus Hours"` (09:00 AM – 05:00 PM, Mon–Fri).
  - **Multiple Schedules per App**: Full support for attaching multiple active schedules to a single app with independent monitoring switches.
  - **Unified `.notiflow` Backup**: Single backup file format bundling rule templates alongside managed apps and schedules with 100% backward compatibility.
  - **Google Play In-App Updates**: Added zero-network In-App Update checker via Play Core IPC (`in_app_update`), maintaining strict 100% on-device privacy with **zero `INTERNET` permission** in [`AndroidManifest.xml`](android/app/src/main/AndroidManifest.xml).
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

