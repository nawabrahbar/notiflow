# Notiflow v1.6.0 Implementation Plan: Botanical Sanctuary & Tablet Expansion

## 1. Project Overview & Scope
- **App Name**: Notiflow (`com.notificationhandler.notification_handler`)
- **Version**: `1.6.0+10`
- **Active Branch**: `feat/botanical-redesign-v1.6.0`
- **Design Systems**:
  - Dark Theme: **Botanical Nocturne** (Verdant Obsidian `#0F1312`, Terracotta `#DDA15E`, Sage `#A7D4A3`)
  - Light Theme: **Botanical Sanctuary** (Warm Linen Parchment `#FEF8F6`, Earth Terracotta `#7D562D`, Botanical Sage `#5A6242`)
- **Typography**: `Newsreader` (Display Serif) + `Plus Jakarta Sans` (Functional UI Sans)
- **Target Form Factors**: **Phone & Tablet only** (Desktop/Chromebooks and XR explicitly excluded)

---

## 2. Core Functional Requirements & Specifications

### 2.1. Seamless Canvas & Header (No Bottom Border)
- The app bar (`BotanicalHeader`) must have **no bottom border**, **no divider line**, and **zero elevation / shadow** (`elevation: 0`, `scrolledUnderElevation: 0`).
- Header background exactly matches the page canvas (`#0F1312` dark / `#FEF8F6` light) so the entire screen flows as one continuous, tranquil surface.

### 2.2. Schedule Rule Editor — "Choose a rule" Dropdown (Feature 1)
- **Top Dropdown Title**: `"QUICK LOAD TEMPLATE / SAVED RULE"`
- **Placeholder**: Exactly `"Choose a rule"` (NOT pre-selected by default).
- **Pre-Seeded Template**: Exactly **ONE** pre-seeded option:
  - **`Work Focus Hours`** (09:00 AM → 05:00 PM, Monday to Friday, Block mode, Urgent calls enabled).
- **Auto-Fill Behavior**:
  - Selecting `"Work Focus Hours"` immediately auto-fills:
    - Rule Name: `"Work Focus Hours"`
    - Behavior: `Block`
    - Start Time: `09:00`
    - End Time: `17:00`
    - Recurrence Days: `Monday, Tuesday, Wednesday, Thursday, Friday`
    - Priority Escalation: `True`
- **Deduplication Logic**:
  - When a user taps `"Save Schedule Rule"`:
    - Check if a template with the exact same hours (`startHour:startMinute` → `endHour:endMinute`), mode, and days of week already exists in local DB.
    - If identical: ignore (do not create duplicate templates).
    - If unique: save to `SharedPreferences` as a new custom template.
- **Dynamic Cycle**:
  - Any new saved template immediately appears in the `"Choose a rule"` dropdown for future use.

### 2.3. Multiple Schedules per App on App Details (Feature 2)
- Under `AppDetailsScreen`:
  - Query `List<ScheduleRule> getRulesForApp(app.id)`.
  - Header: `Active Schedule Rules (N)`.
  - Render a vertical list of all schedule cards configured for this app.
  - Each schedule card includes:
    - Time range (e.g. `21:00 → 08:00`) + overnight indicator (`+1 DAY` if applicable).
    - Recurrence days chips.
    - Tags: `Silent Hold` / `Batch Summary`.
    - Individual switch toggle (active / disabled).
    - Delete button (deletes only this individual rule).
  - Dashed card button at the bottom: **`+ Add New Schedule`** (opens `ScheduleEditorScreen` targeting this app).

### 2.4. Unified Single `.notiflow` Backup File
- Output format: Exactly **one file** with extension `.notiflow`.
- Schema Version 2 includes:
  ```json
  {
    "version": 2,
    "exportedAt": "2026-11-11T...",
    "defaultScheduleMode": "allow",
    "unmanagedAppsUntouched": true,
    "vipEmergencyBypass": true,
    "managedApps": [...],
    "schedules": [...],
    "ruleTemplates": [
      {
        "id": "tpl_work_focus",
        "name": "Work Focus Hours",
        "mode": "blockDuring",
        "startHour": 9,
        "startMinute": 0,
        "endHour": 17,
        "endMinute": 0,
        "daysOfWeek": [1, 2, 3, 4, 5],
        "allowVipContacts": true
      }
    ]
  }
  ```
- **Backward Compatibility**: Importing older v1 `.notiflow` files without `ruleTemplates` preserves the default pre-seeded template without errors.

### 2.5. In-App Update Checker — Approach A (`in_app_update`)
- Integrated via Google Play Core In-App Updates (`in_app_update`).
- Communicates directly with the Google Play Store Android app via IPC.
- **Maintains 100% on-device privacy guarantee**: No internet permission is required in `AndroidManifest.xml` for Notiflow itself, as the Play Store app handles the update check.
- When a new Play Store version is available:
  - Displays a calm, non-intrusive banner or prompt: *"Update available: Notiflow vX.X.X is ready on Google Play with new features and improvements."*
  - Has an *"Update"* action that launches Google Play's flexible update flow.

### 2.6. Device Target Restriction: Phone & Tablet Only
- Exclude Desktop (Chromebooks) and XR:
  - In `android/app/src/main/AndroidManifest.xml`:
    - Add `<supports-screens android:smallScreens="true" android:normalScreens="true" android:largeScreens="true" android:xlargeScreens="true" />`.
    - Explicitly restrict to touchscreen/handheld/tablet environments.
  - In Google Play Console:
    - Under **Release > Device catalog** and **Device categories**, uncheck / opt out of **ChromeOS / Desktop** and **XR**.

### 2.7. Real Application Icons Across Entire Project
- Display each app's **real native installed application icon** (`iconBytes` loaded from Android's `PackageManager`) everywhere in the app:
  - **Dashboard**: Managed Apps cards list.
  - **App Details**: Top App Identity profile squircle.
  - **Add Apps**: App discovery list rows.
  - **Activity Log**: Event audit trail cards.
- Render inside an elegant squircle with a subtle Botanical border and background.
- Never display generic fallback icons (like generic chat/mail glyphs) when the real native app icon (e.g., WhatsApp, Telegram, Slack, Gmail, Instagram, etc.) is available from the device.

### 2.8. Smart Backup Import for Uninstalled Apps & Auto-Apply on Install
- **The Problem**: When moving to a new device or restoring a `.notiflow` file, some managed apps from the backup may not yet be installed on the current phone.
- **Pre-Import Device Inspection**:
  - Compare package names in the `.notiflow` backup against device-installed packages via `PackageManager`.
  - If all apps exist, proceed seamlessly.
- **User Choice Bottom Sheet (When Uninstalled Apps Detected)**:
  - Header: *"Uninstalled Apps Detected"*
  - Content: *"Your backup includes rules for N apps not currently installed on this device (e.g. Telegram, Discord)."*
  - **Option 1: Keep in Vault & Auto-Apply on Install (Recommended)**:
    - Saves the apps and their schedule rules in local storage, marked with `pendingInstall: true`.
    - **Hidden from Rules Page**: Prevents "ghost" apps from cluttering the active Rules (Dashboard) page.
    - **Auto-Detection**: Whenever Notiflow opens or queries installed apps, it checks if any pending packages are now installed. When installed, Notiflow automatically loads the app's native icon, moves it to the active Rules page, and shows a gentle toast (*"Telegram installed: saved focus rules automatically applied!"*).
  - **Option 2: Exclude Uninstalled Apps**:
    - Discards uninstalled apps and imports only the apps currently present on the device.

### 2.9. Urgent Repeated Call Escalation (< 3 Minutes) Bug Diagnosis & Native Fix
- **Reported Bug**: WhatsApp calls ring through on the first attempt even when an app is in a muted focus schedule, failing the *"Allow repeated calls within 3 minutes"* policy.
- **Deep-Check Root Causes Identified**:
  1. **Premature Ongoing Filter in NLS**:
     - In `NotificationHandlerListenerService.kt` (line 49): `if (sbn.isOngoing) return`.
     - Incoming calls in Android (WhatsApp, Telegram, system dialer) are posted with `Notification.FLAG_ONGOING_EVENT` while the phone is ringing. This caused all incoming call notifications to immediately bypass Notiflow's evaluation engine without being checked.
  2. **Missing `allowVipContacts` in Native Kotlin Engine**:
     - `NativeScheduleStore.kt` does not parse or persist `allowVipContacts` on `NativeScheduleRule` from the sync payload JSON.
  3. **No Caller Timestamp Tracking**:
     - `NativeScheduleStore.kt` currently lacks a caller history map (`Map<String, Long>`) to differentiate between a 1st incoming call and a 2nd repeated call within 180 seconds (`3 minutes`).
- **Target Native Architecture Fix**:
  - Differentiate incoming calls from generic background services: inspect `sbn.notification.category == Notification.CATEGORY_CALL`, call styles, or caller extras before applying `sbn.isOngoing`.
  - Parse `allowVipContacts: Boolean` in `NativeScheduleStore.kt`.
  - Maintain a thread-safe `callerHistory: MutableMap<String, Long>` (keyed by `packageName + ":" + callerTitle`):
    - **Call 1**: If inside an active block window and `allowVipContacts == true`, suppress the notification (`cancelNotification(key)`), record `callerHistory[callerKey] = postTimeMs`, and log event as *"Call 1 Silenced (Urgent escalation armed for 3m)"*.
    - **Call 2 (within 180 seconds from same caller)**: Recognize repeated urgent call, bypass suppression, and allow the call to ring through!
    - **Outside 3 minutes**: Reset timestamp and treat as Call 1.

### 2.10. 12-Hour vs 24-Hour Time Display Preference
- **Feature**: Under Settings > Triage & Automation Preferences, users can toggle between:
  - **12-Hour format** (e.g. `09:00 AM`, `05:00 PM`)
  - **24-Hour format** (e.g. `09:00`, `17:00`)
- **App-Wide Adoption**: Dynamically updates the time representation on App Details schedule cards, Rule Editor pickers, and Activity logs.
- **Persistence & Portability**: Saved in `SharedPreferences` (`pref_use_24_hour_format`) and bundled into single `.notiflow` backup files.

### 2.11. Material You Themed App Icon for Device Home Screen & App Drawer
- **Implementation**: Configure `<monochrome android:drawable="@drawable/ic_launcher_monochrome" />` in Android's adaptive icon XML (`mipmap-anydpi-v26/ic_launcher.xml` and `ic_launcher_round.xml`).
- **Dynamic Behavior**: On Android 13+ (API 33+) devices, the launcher icon in the home screen and app drawer dynamically switches between Light Mode (light background with dark emblem) and Dark Mode (dark background with light emblem) automatically following system appearance.

### 2.12. First-Launch Theme Sync & Explicit User Preference Retention
- **Initial Install / First Launch**:
  - No user preference stored yet (`pref_theme_mode == null`).
  - The app strictly follows the **device's current system appearance** (`ThemeMode.system`).
  - If the user's device is in Light Mode, Notiflow opens in Botanical Sanctuary (Light). If in Dark Mode, it opens in Botanical Nocturne (Dark).
- **Subsequent Sessions (Explicit User Preference)**:
  - The moment the user explicitly taps the header theme switch, Notiflow records an explicit preference (`'light'` or `'dark'`) in `SharedPreferences`.
  - From the second session onward, the app strictly obeys the **user's explicit choice** across all app restarts, ignoring subsequent device system theme changes until changed again by the user.

---

## 3. Phased Roadmap

### Phase 1: Foundation & Data Architecture (COMPLETED ✅)
1. AppTheme update (`Botanical Nocturne` & `Botanical Sanctuary` tokens). [Done]
2. Typography integration (`Newsreader` display serif + `Plus Jakarta Sans` UI sans). [Done]
3. `RuleTemplate` model and storage in `ScheduleRepository` with the single pre-seeded `"Work Focus Hours"` template. [Done]
4. Deduplication logic on rule save. [Done]
5. Single `.notiflow` schema update (exporting and importing custom rule templates). [Done]
6. Google Play In-App Updates integration (`in_app_update` & `InAppUpdateService`). [Done]
7. Device target declaration in `AndroidManifest.xml` (Phone & Tablet only). [Done]
8. Seamless header foundation (zero bottom border, continuous canvas flow). [Done]

### Phase 2: Core Scheduling UI (COMPLETED ✅)
1. `BotanicalHeader`: zero bottom border, continuous page canvas. [Done]
2. `AppDetailsScreen`:
   - Multi-schedule list (`Active Schedule Rules (N)`). [Done]
   - Individual schedule switches, mode tags, and delete actions. [Done]
   - Dashed `+ Add New Schedule` button. [Done]
   - Real native app icon from PackageManager. [Done]
3. `ScheduleEditorScreen`:
   - `"Choose a rule"` dropdown at the top with bookmark icon. [Done]
   - Auto-fill logic upon selecting a saved template. [Done]
   - Block vs Allow radio cards. [Done]
   - Start / End time cards with duration math. [Done]
   - Recurrence day preset chips + 7 day pills. [Done]
   - Automatic template caching on custom rule save with deduplication. [Done]

### Phase 3: Dashboard, Apps, Activity & Settings (COMPLETED ✅)
1. `SplashScreen`: Botanical medallion with rotating pulse rings, Newsreader branding, and cadence dots. [Done]
2. `MainNavigationShell`: Adaptive navigation shell: <600dp bottom navigation bar, ≥600dp 88dp left Navigation Rail. [Done]
3. `DashboardScreen`: Ambient time-based greeting, 5:7 two-column bento on tablet, side-by-side Intercepted/Permitted metrics, 3 quick session override pills, managed apps list with real icons. [Done]
4. `AddAppsScreen`: Live search, 5 category chips, 2-column grid on tablet, "+ Add Rule" / "Active" state buttons. [Done]
5. `ActivityScreen`: 3 metric cards, filter pills (All, Silenced, Allowed), clear confirmation dialog, event cards, notification details bottom sheet. [Done]
6. `SettingsScreen`: Botanical styling, tablet 6:6 two-column bento, encrypted storage audit, in-app update status tile (Play Core IPC), 12h/24h toggle, Dormant Vault count card, danger zone reset. [Done]
7. `Smart Backup Import`: Detection of uninstalled apps with user choice bottom sheet ("Keep in Vault & Auto-Apply on Install" vs "Exclude These Apps"). [Done]
8. `Urgent Call Escalation Fix`: Native fix in `NotificationHandlerListenerService.kt` and `NativeScheduleStore.kt` ensuring ringing calls aren't dropped as ongoing, and second call within 3 minutes rings through. [Done]
9. `Material You Themed App Icon`: Added `<monochrome>` adaptive icon layer so the Android home screen & app drawer launcher icon dynamically switches between Light and Dark mode on Android 13+. [Done]
10. `First-Launch Theme Sync & User Override`: Initial launch strictly follows device system appearance, but once the user toggles a theme, persist the explicit preference to always override device theme. [Done]

### Phase 4: Onboarding Streamlining (COMPLETED ✅)
1. Step 1: 3 feature cards (RULES, OFFLINE, BYPASS) with tablet max-width constraint. [Done]
2. Step 2: 3-step numbered card (all sideload/restricted settings warnings removed). [Done]
3. Step 3: Elevated "Import .notiflow Backup File" card + "Done" CTA. [Done]

### Phase 5: Tablet Optimization & Responsive Adaptation (COMPLETED ✅)
1. Navigation Rail (≥600dp): 88dp left rail with emblem and 4 tabs (Rules, Apps, Activity, Settings). [Done]
2. Dashboard (≥600dp): 5:7 two-column bento layout. [Done]
3. App Details (≥600dp): 5:7 two-column split layout. [Done]
4. Schedule Editor (≥600dp): 7:5 two-column split layout. [Done]
5. Add Apps (≥600dp): 2-column app discovery grid. [Done]
6. Settings (≥600dp): 6:6 two-column bento layout. [Done]
7. Onboarding & Permission (≥600dp): Centered editorial card column (max 680dp). [Done]
8. Phone (<600dp): Responsive stacked layouts with bottom navigation bar. [Done]
