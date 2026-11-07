# Notiflow — Post-Play Store Launch Improvement Plan (`plan.MD`)

> **Status:** Saved for implementation after initial Google Play Store publication and live Play Store download testing.

---

## 1. Goal & Context

Once **Notiflow** is published on the Google Play Store and installed directly from Google Play (`com.android.vending`):
- Android **trusts** Play Store installations and **does not trigger Android 13+ "Restricted Settings"** (`"App was denied access"`).
- Therefore, several instructions and warning cards currently shown on first launch (Onboarding Step 2 and Permission Screen) are unnecessary for Play Store users and should be streamlined or hidden.

---

## 2. Planned Improvements (After Play Store Download & Testing)

### A. Smart Installer Detection (`Play Store` vs. `Sideloaded APK`)
- **File:** [`AndroidNotificationBridge.kt`](file:///home/antigravity/nawabrahbar/notiflow/android/app/src/main/kotlin/com/notificationhandler/notification_handler/AndroidNotificationBridge.kt)
- **What to build:**
  - Add a bridge method `getInstallSourceInfo` using `PackageManager.getInstallSourceInfo(context.packageName)` (Android 11+) / `getInstallerPackageName` fallback.
  - Detect whether `installingPackageName == "com.android.vending"` (Google Play Store).
- **UI Behavior:**
  - **When installed from Google Play Store:**
    - Hide the *"Sideloaded APK blocked on Android 13+?"* warning box on [`onboarding_screen.dart`](file:///home/antigravity/nawabrahbar/notiflow/lib/presentation/screens/onboarding_screen.dart#L459-L516).
    - Hide the *"Installed via APK? Allow Restricted Settings"* card and help icon on [`permission_screen.dart`](file:///home/antigravity/nawabrahbar/notiflow/lib/presentation/screens/permission_screen.dart#L127-L131).
    - Show a simple, clean **1-Step Enable Notification Access** instruction for non-technical users.
  - **When sideloaded via `.apk` (GitHub Releases / direct testing):**
    - Show the guided 3-step Restricted Settings assistant in the **correct order** so Android always reveals the `⋮ → Allow restricted settings` option:
      1. **Step 1:** Open Notiflow's Notification Access screen and tap the disabled switch once (triggers Android's *"App was denied access"* prompt so Android unlocks the `⋮` menu in App Info).
      2. **Step 2:** Open Notiflow's **App Info** page → tap `⋮` (top-right) → tap **Allow restricted settings**.
      3. **Step 3:** Return to Notiflow's Notification Access screen and flip **Allow notification access** ON.

### B. Direct Deep-Link to Notiflow's Toggle Screen (Skip the App List)
- **File:** [`AndroidNotificationBridge.kt`](file:///home/antigravity/nawabrahbar/notiflow/android/app/src/main/kotlin/com/notificationhandler/notification_handler/AndroidNotificationBridge.kt#L77-L87)
- **Current Issue:**
  - `openNotificationAccessSettings` uses `Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS`, which opens the long list of all installed listener apps and requires the user to find and tap **Notiflow** first.
- **Improvement:**
  - On Android 11+ (`API 30+`), launch `Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS` with `Settings.EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME` set to `ComponentName(context, NotificationHandlerListenerService::class.java).flattenToString()` (with automatic fallback to `ACTION_NOTIFICATION_LISTENER_SETTINGS` on older devices).
  - This takes the user **directly to Notiflow's `Allow notification access` switch** in 1 tap.
  - Consequently, Step 2 (*"Find Notiflow in the list"*) can be removed from the onboarding instructions!

### C. Automatic Return to App Once Permission Is Granted
- **Files:** [`AndroidNotificationBridge.kt`](file:///home/antigravity/nawabrahbar/notiflow/android/app/src/main/kotlin/com/notificationhandler/notification_handler/AndroidNotificationBridge.kt), [`onboarding_screen.dart`](file:///home/antigravity/nawabrahbar/notiflow/lib/presentation/screens/onboarding_screen.dart), [`permission_screen.dart`](file:///home/antigravity/nawabrahbar/notiflow/lib/presentation/screens/permission_screen.dart)
- **What to build:**
  - While the user is in Android Settings granting Notification Access, poll `NotificationManagerCompat.getEnabledListenerPackages(context)` every 500ms (or listen inside `NotificationHandlerListenerService.onListenerConnected()`).
  - As soon as the user flips the switch ON and confirms, automatically bring `MainActivity` back to the foreground (`FLAG_ACTIVITY_REORDER_TO_FRONT` / `FLAG_ACTIVITY_SINGLE_TOP`) and advance directly to the next screen without requiring the user to press Back multiple times.

### D. Copy & Branding Cleanup in Permission Screens
- **Files:** [`permission_screen.dart`](file:///home/antigravity/nawabrahbar/notiflow/lib/presentation/screens/permission_screen.dart#L343), [`restricted_settings_sheet.dart`](file:///home/antigravity/nawabrahbar/notiflow/lib/presentation/widgets/restricted_settings_sheet.dart#L145)
- **What to fix:**
  - Replace remaining legacy references to `"Notification Handler"` with `"Notiflow"`.
  - Simplify the first-time onboarding copy so non-technical users only see clear, jargon-free instructions.

---

## 3. Google Play Store CI/CD Automation (Post-First Manual Upload)

After the first release is live on Google Play Console:
1. Configure release signing in [`android/app/build.gradle.kts`](file:///home/antigravity/nawabrahbar/notiflow/android/app/build.gradle.kts) reading from GitHub Actions secrets (`KEYSTORE_BASE64`, `KEY_ALIAS`, `KEY_PASSWORD`, `STORE_PASSWORD`) with fallback to debug signing for local/PR builds.
2. Update [`.github/workflows/build-apk.yml`](file:///home/antigravity/nawabrahbar/notiflow/.github/workflows/build-apk.yml) to also build the signed `.aab` (`flutter build appbundle --release`) and optionally publish to Google Play Console via `r0adkll/upload-google-play@v1` using `PLAY_STORE_JSON_KEY`.
