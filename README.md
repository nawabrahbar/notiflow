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
| **📲 Direct APK Download (Latest)** | **[Download `notiflow-latest.apk`](https://github.com/nawabrahbar/notiflow/releases/latest/download/notiflow-latest.apk)** | One-tap direct download of the newest Release APK |
| **🏷️ Latest Release Page** | **[View Latest Release](https://github.com/nawabrahbar/notiflow/releases/latest)** | Release notes and versioned APK (`notiflow-v1.5.0.apk`) |
| **🗂️ All Releases Archive** | **[Browse All Releases](https://github.com/nawabrahbar/notiflow/releases)** | Complete history of all published Notiflow builds |
| **⚙️ GitHub Actions Builds** | **[View CI/CD Workflow Runs](https://github.com/nawabrahbar/notiflow/actions/workflows/build-apk.yml)** | Live build logs and PR workflow artifacts |

### Installing on Android 13+ (Sideloaded APK Note)
When installing an `.apk` outside the Play Store on Android 13 or newer, Android places a security lock on **Notification Access** until you allow restricted settings:
1. Install and open **Notiflow**, then tap **Unlock Restricted Settings** when prompted.
2. **Step 1**: Tap **Open App Info** → tap the **`⋮`** menu (top-right corner) → tap **Allow restricted settings** and verify with your fingerprint/PIN.
3. **Step 2**: Tap **Open Notification Access** → toggle **Notiflow** to **ON**.

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
- **Export `.notiflow` Backups**: Serialize all managed apps, schedules, and preferences into a `.notiflow` JSON file and share or save via the Android system share sheet.
- **Import from Storage or Clipboard**: Restore rules by picking a `.notiflow` file from device storage or pasting raw JSON directly.
- **3 Built-In Focus Protocols**:
  - **Deep Work Protocol**: Blocks Slack, Teams, and Gmail from `09:00 – 17:00` (Mon–Fri).
  - **Mindful Evening**: Blocks Instagram, X, and YouTube overnight from `20:00 – 08:00` (Everyday).
  - **Minimalist Default**: Holds WhatsApp notifications 24/7 while letting phone calls and SMS pass through.

### 5. 100% On-Device Privacy & Zero Telemetry
- **Zero Network Access**: `android.permission.INTERNET` is completely omitted from [`AndroidManifest.xml`](android/app/src/main/AndroidManifest.xml). It is physically impossible for the app to transmit data off your device.
- **Unmanaged Apps Untouched**: Apps you haven't added to Notiflow pass through the OS untouched.
- **Stitch Obsidian Signal Design**: High-contrast Dark (`#09090B`) and Crisp Light (`#F9F9FB`) themes with Signal Amber (`#F59E0B`) accents, custom 60/120fps animated vector emblems, and dynamic time-of-day greetings.

---

## 🧭 App Screens & Architecture

Notiflow is organized into **11 screens** across a clean 4-layer architecture (`domain`, `data`, `platform`, `presentation`):

| # | Screen | File | Description |
| :--- | :--- | :--- | :--- |
| 1 | **Splash Screen** | [`lib/presentation/screens/splash_screen.dart`](lib/presentation/screens/splash_screen.dart) | Animated Stitch emblem, engine initialization, smart route dispatch |
| 2 | **Onboarding Screen** | [`lib/presentation/screens/onboarding_screen.dart`](lib/presentation/screens/onboarding_screen.dart) | 3-step onboarding for value pillars & notification access |
| 3 | **Permission Center** | [`lib/presentation/screens/permission_screen.dart`](lib/presentation/screens/permission_screen.dart) | Permission recovery, Android 13+ sideload guide, OEM battery tips |
| 4 | **Import & Presets** | [`lib/presentation/screens/import_rules_screen.dart`](lib/presentation/screens/import_rules_screen.dart) | `.notiflow` file picker, JSON paste modal, and 3 curated focus presets |
| 5 | **Navigation Shell** | [`lib/presentation/screens/main_navigation_shell.dart`](lib/presentation/screens/main_navigation_shell.dart) | 4-tab bottom navigation (*Rules*, *Apps*, *Activity*, *Settings*) |
| 6 | **Dashboard (Rules)** | [`lib/presentation/screens/dashboard_screen.dart`](lib/presentation/screens/dashboard_screen.dart) | Time-based greeting, triage counters, global overrides, managed apps |
| 7 | **Add Apps Screen** | [`lib/presentation/screens/add_apps_screen.dart`](lib/presentation/screens/add_apps_screen.dart) | Installed app discovery, search, and category filters (*Messaging*, *Social*, etc.) |
| 8 | **App Details Screen** | [`lib/presentation/screens/app_details_screen.dart`](lib/presentation/screens/app_details_screen.dart) | Real-time triage status card, quick mute pills, and app rule list |
| 9 | **Schedule Editor** | [`lib/presentation/screens/schedule_editor_screen.dart`](lib/presentation/screens/schedule_editor_screen.dart) | Rule name, BLOCK/ALLOW mode, time pickers, overnight badge, day pills |
| 10 | **Activity Log** | [`lib/presentation/screens/activity_screen.dart`](lib/presentation/screens/activity_screen.dart) | Muted notification log with full message details and app launcher sheet |
| 11 | **Settings Screen** | [`lib/presentation/screens/settings_screen.dart`](lib/presentation/screens/settings_screen.dart) | Service health, on-device privacy audit, `.notiflow` backup/restore, reset |

### Native Android Engine (`android/app/src/main/kotlin/...`)
- **[`NotificationHandlerListenerService.kt`](android/app/src/main/kotlin/com/notificationhandler/notification_handler/NotificationHandlerListenerService.kt)**: System-bound `NotificationListenerService` that intercepts posted notifications, extracts notification title/message/channel extras, records triage events, and cancels muted notifications in `< 5ms`.
- **[`NativeScheduleStore.kt`](android/app/src/main/kotlin/com/notificationhandler/notification_handler/NativeScheduleStore.kt)**: Pure Kotlin schedule evaluator (`NativeScheduleEvaluator`) and persistent store (`SharedPreferences`) that runs independently even when the Flutter UI is closed.
- **[`AndroidNotificationBridge.kt`](android/app/src/main/kotlin/com/notificationhandler/notification_handler/AndroidNotificationBridge.kt)**: MethodChannel bridge (`com.notificationhandler/bridge`) connecting Flutter with Android package discovery, permission intents, `.notiflow` file import/export, app launching, and real-time activity updates.

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

# 3. Build release APK locally
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

For detailed screen-by-screen specifications and flow diagrams, see [`APP_FEATURES.md`](APP_FEATURES.md) and the [`docs/`](docs/) directory.
