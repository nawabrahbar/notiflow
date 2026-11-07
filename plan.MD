# Notiflow — Post-Play Store Launch Improvement Plan (`plan.MD`)

> **Status:** ✅ Implemented in `v1.5.4+9` (`feat/simplify-permission-and-remove-sideload-guide`)

---

## Completed Items

### 1. ✅ Removed Sideloaded APK / Restricted Settings UI
- Removed the *"Sideloaded APK blocked on Android 13+?"* section from [`onboarding_screen.dart`](lib/presentation/screens/onboarding_screen.dart).
- Removed the *"Installed via APK? Allow Restricted Settings"* card and header help button from [`permission_screen.dart`](lib/presentation/screens/permission_screen.dart).
- Streamlined Onboarding Step 2 and Permission Screen to a clean 2-step flow:
  1. **Open Android Settings** — Opens Notiflow's notification permission screen directly.
  2. **Switch Toggle to ON** — Turn on "Allow notification access" and return automatically.

### 2. ✅ Direct Deep-Link to Notiflow's Toggle Screen (Skip the App List)
- Updated [`AndroidNotificationBridge.kt`](android/app/src/main/kotlin/com/notificationhandler/notification_handler/AndroidNotificationBridge.kt) to launch `Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS` with `Settings.EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME` on Android 11+ (`API 30+`), with automatic fallback to `Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS` on older devices.

### 3. ✅ Automatic Return to App Once Permission Is Granted
- Added `startPermissionGrantWatcher()` in [`AndroidNotificationBridge.kt`](android/app/src/main/kotlin/com/notificationhandler/notification_handler/AndroidNotificationBridge.kt) so the moment the user switches "Allow notification access" ON in Android Settings, `MainActivity` is automatically brought back to the foreground and advances to the next screen.

### 4. ✅ Copy & Branding Cleanup in Permission Screens
- Replaced all remaining legacy `"Notification Handler"` labels with `"Notiflow"` in [`permission_screen.dart`](lib/presentation/screens/permission_screen.dart).

### 5. ✅ Signed Google Play Store `.aab` Bundle in CI/CD
- Configured release keystore signing in [`android/app/build.gradle.kts`](android/app/build.gradle.kts) and `.aab` publishing in [`.github/workflows/build-apk.yml`](.github/workflows/build-apk.yml).
