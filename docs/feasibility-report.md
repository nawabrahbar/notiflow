# Notification Handler: Platform Feasibility & Architecture Report

**Date:** October 1, 2026  
**Document Status:** Complete / Approved for Phase 0  
**Target Platforms:** Android (Primary / Full Support), iOS (Documentation & Platform Limitation Enforcement)

---

## Executive Summary

The primary objective of **Notification Handler** is to allow mobile users to define granular time windows during which notifications from specific third-party applications (e.g., WhatsApp, Instagram) are allowed to alert them, while suppressing/canceling notifications outside those defined windows.

This report comprehensively assesses the platform capabilities, security sandboxes, OS lifecycle constraints, OEM-specific behaviors (such as OnePlus / OxygenOS), and architectural strategies required to deliver a reliable, privacy-preserving utility.

---

## 1. Can Android Implement the Required Notification Scheduling Behavior?

**Yes.** Android provides a dedicated, official system-level framework for listening to and managing status bar notifications across the entire OS. 

By implementing an Android `NotificationListenerService` and obtaining explicit user permission via Android's **Notification Access** settings screen, an application can:
- Receive a callback every time any application posts, updates, or removes a notification (`onNotificationPosted`, `onNotificationRemoved`).
- Inspect the origin of the notification via `StatusBarNotification.getPackageName()`.
- Uniquely identify the notification using its stable identifier `StatusBarNotification.getKey()`.
- Actively cancel/dismiss the notification from the system shade in real time via `NotificationListenerService.cancelNotification(String key)`.

Because cancellation can occur immediately upon posting, the notification can be suppressed before the user is interrupted or notices the banner.

---

## 2. Which Android APIs Are Required?

| Android API / Component | Purpose | Official Documentation Reference |
| :--- | :--- | :--- |
| `android.service.notification.NotificationListenerService` | Base class for listening to system-wide notification events and canceling notifications. | [Android NotificationListenerService API](https://developer.android.com/reference/android/service/notification/NotificationListenerService) |
| `android.service.notification.StatusBarNotification` | Represents an individual notification posted to the system. Provides `getPackageName()`, `getKey()`, `getPostTime()`, and `getId()`. | [StatusBarNotification Reference](https://developer.android.com/reference/android/service/notification/StatusBarNotification) |
| `NotificationListenerService.cancelNotification(String key)` | Cancels a specific posted notification by its unique notification key. | [cancelNotification(key) Reference](https://developer.android.com/reference/android/service/notification/NotificationListenerService#cancelNotification(java.lang.String)) |
| `android.provider.Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS` | Intent action to launch the system settings screen where the user grants Notification Access. | [Settings Actions Reference](https://developer.android.com/reference/android/provider/Settings#ACTION_NOTIFICATION_LISTENER_SETTINGS) |
| `android.content.pm.PackageManager` | Discovers installed user-facing launcher applications (`queryIntentActivities`) and loads dynamic launcher icons and labels. | [PackageManager Reference](https://developer.android.com/reference/android/content/pm/PackageManager) |
| `android.content.SharedPreferences` | Synchronous, low-latency, zero-IPC key-value storage for schedule rules directly accessible by the background listener service. | [SharedPreferences Reference](https://developer.android.com/reference/android/content/SharedPreferences) |

---

## 3. What User Permissions and Access Are Required?

1. **Notification Access (`BIND_NOTIFICATION_LISTENER_SERVICE`)**:
   - Declared in `AndroidManifest.xml` with `android:permission="android.permission.BIND_NOTIFICATION_LISTENER_SERVICE"`.
   - Requires explicit, out-of-band user enablement via system settings (`Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS`).
   - The app cannot programmatically grant this permission; it must guide the user with a transparent onboarding flow.
2. **Query All Packages (`QUERY_ALL_PACKAGES` or targeted queries)**:
   - On Android 11+ (API 30+), package visibility is restricted by default.
   - To discover installed user apps to manage, the app queries for applications matching the `android.intent.action.MAIN` + `android.intent.category.LAUNCHER` intent. In modern Android, querying launcher intents or declaring `<queries>` with `intent` filters avoids needing broad unrestricted queries where possible, or requests `QUERY_ALL_PACKAGES` if full user app discovery is mandatory.
3. **No Unnecessary Permissions**:
   - `RECEIVE_BOOT_COMPLETED`: Not strictly required for the listener itself, as Android automatically binds enabled `NotificationListenerService` instances upon system startup.
   - No Internet Permission (`INTERNET`): The app strictly operates offline, guaranteeing that notification metadata never leaves the device.

---

## 4. What Android Version Restrictions Exist?

- **API 26 (Android 8.0 Oreo)**: Introduced Notification Channels. `cancelNotification(key)` has been stable since API 21 (Lollipop), but API 26 is the baseline for modern background execution limits.
- **API 29 (Android 10)**: Strict background activity launch restrictions. Notification listeners remain functional as long-running system bound services.
- **API 30 (Android 11)**: Package visibility filtering introduced. Requires `<queries>` declarations in `AndroidManifest.xml` for launcher intents.
- **API 33 (Android 13)**: Runtime notification permission (`POST_NOTIFICATIONS`) introduced. Note: This applies to notifications *sent by* Notification Handler itself, not to the listener listening to third parties.
- **API 34/35 (Android 14/15)**: Stricter foreground service type declarations and broadcast receiver lifecycle rules. `NotificationListenerService` is a system-managed bound service (managed by `NotificationManagerService` inside `system_server`), so it is not subject to normal foreground service kill policies.

---

## 5. What Limitations Exist on OnePlus / OxygenOS?

OnePlus devices running OxygenOS (and Oppo ColorOS codebase) feature aggressive proprietary power management optimizations that can disrupt background services:

1. **Aggressive Background Killing**:
   - OxygenOS often kills background processes after extended screen-off periods.
   - *Mitigation*: Because `NotificationListenerService` is bound directly by Android's `system_server`, the OS will attempt to restart it when notifications arrive. However, users should be guided in Settings/Help to set battery management for Notification Handler to **"Don't optimize"** / **"Unrestricted"** and enable **"Allow background activity"** in OxygenOS App Battery Usage.
2. **Notification Listener Service Dropping (OEM Bug)**:
   - On OxygenOS 13/14, users occasionally report that `NotificationListenerService` stops receiving callbacks until toggled off and on in Settings.
   - *Mitigation*: The app must programmatically verify active listener connectivity using `NotificationManagerCompat.getEnabledListenerPackages(context)` and `ComponentName(context, NotificationHandlerListenerService::class.java)` on app resume, offering a quick re-bind or direct link if disconnected.
3. **Deep Clean / Auto-Freeze**:
   - "Deep Clean" memory killers kill cached apps. Keeping the native schedule rules stored in disk-persisted `SharedPreferences` ensures that whenever `NotificationListenerService` is spun up by `system_server`, it reads state immediately without requiring the Flutter engine or UI process to be alive.

---

## 6. Can iOS Implement Equivalent Functionality for Arbitrary Third-Party Apps?

**No. It is technically impossible using public, supported Apple APIs.**

### Detailed Technical Breakdown:
- **`UNNotificationServiceExtension`**: Apple provides this extension point solely for applications to decrypt or enrich *their own* remote push notifications before presentation. An app's extension is only invoked for push payloads specifically targeted to that app's bundle ID.
- **App Sandboxing & Privacy Boundaries**: iOS maintains a strict security perimeter around every application. No third-party application or extension can intercept, observe, inspect, or cancel notifications belonging to another application (such as WhatsApp, Instagram, or Mail).
- **Focus Modes / Screen Time**: Apple provides Focus Modes and Screen Time APIs, but:
  - Focus Modes are configured directly by the end-user in iOS System Settings.
  - The `ScreenTime` / `DeviceActivity` API allows restricting app usage (shielding apps or web domains for parental controls), but does not expose an API to selectively listen to and drop incoming notifications from specific apps while leaving the app unshielded.
- **Compliance Rule (Section 2 & 30 of Spec)**:
  - We will **never** fake this feature on iOS.
  - We will **never** use private APIs or suggest jailbreak mechanisms.
  - The iOS build will clearly inform the user that system-wide third-party notification scheduling is an Android-exclusive capability due to Apple platform privacy architecture.

---

## 7. Which Parts Can Be Shared Using Flutter?

1. **Presentation / UI Layer**:
   - Modern Material 3 dashboard, onboarding, permission explanations, schedule editor, settings, and about screens.
   - Time pickers, day selectors, responsive layouts, dark/light themes.
2. **Domain Layer & Schedule Engine**:
   - Pure Dart schedule evaluation logic (`isNotificationAllowed(appId, dateTime)`).
   - Timezone-aware date/time handling, overnight interval math, recurrence rules (weekdays, weekends, custom).
   - Temporary overrides logic and priority resolution.
3. **Data & State Management**:
   - Data models (`ManagedApp`, `ScheduleRule`, `TemporaryOverride`, `ScheduleDecision`).
   - Repository interfaces and app state management (Riverpod/BLoC/ChangeNotifier).
   - High-coverage unit test suites for the engine and domain rules.

---

## 8. Which Parts Must Be Native?

1. **Android (`android/app/src/main/kotlin/`)**:
   - `NotificationHandlerListenerService`: Extends `NotificationListenerService` to receive system events and call `cancelNotification(sbn.key)`.
   - `NativeScheduleStore`: Reads `SharedPreferences` containing JSON rules synchronously inside the service with zero IPC latency.
   - `AndroidNotificationBridge`: `MethodChannel` handler that:
     - Detects Notification Access permission status.
     - Launches `Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS`.
     - Queries installed launcher applications using `PackageManager`.
     - Extracts and encodes app icons into byte streams for Flutter `Image.memory`.
     - Synchronizes schedule rules from Flutter into `SharedPreferences`.
2. **iOS (`ios/Runner/`)**:
   - `IosNotificationBridge`: Reports unsupported status cleanly to the Flutter platform interface.

---

## 9. Recommended Project Architecture

A clean, modular layered architecture:

```
lib/
├── core/
│   ├── constants/
│   ├── theme/                     # Teal accent, Amber warnings, Material 3
│   └── utils/
├── domain/
│   ├── engine/
│   │   ├── schedule_evaluator.dart# Pure Dart deterministic schedule math
│   │   └── time_interval.dart     # Normal & overnight interval calculations
│   └── models/
│       ├── managed_app.dart
│       ├── schedule_rule.dart
│       ├── temporary_override.dart
│       └── schedule_decision.dart
├── data/
│   ├── repositories/
│   │   └── schedule_repository.dart
│   └── local/
│       └── shared_preferences_adapter.dart
├── platform/
│   ├── notification_platform_interface.dart
│   ├── android_notification_platform.dart
│   └── ios_notification_platform.dart
└── presentation/
    ├── screens/
    │   ├── splash/
    │   ├── onboarding/
    │   ├── permission/
    │   ├── dashboard/
    │   ├── add_apps/
    │   ├── app_details/
    │   ├── schedule_editor/
    │   └── settings/
    └── widgets/
```

---

## 10. Recommended Language / Framework Selection

- **Application Framework**: Flutter (Dart 3.x)  
  *Justification*: High-quality declarative UI, unified cross-platform structure, fast prototyping, and straightforward integration with native platform channels.
- **Android Native**: Kotlin (JVM 17 / 21)  
  *Justification*: Standard modern Android development language, idiomatic null-safety, and seamless interoperability with Android SDK and Flutter embedding.
- **iOS Native**: Swift  
  *Justification*: Clean, modern Apple platform integration for standard Flutter embedding and compliant fallback messaging.

---

## 11. Risks and Mitigations

| Risk | Impact | Likelihood | Mitigation Strategy |
| :--- | :--- | :--- | :--- |
| **Notification Notification Leakage** (Audible ding before cancel) | Low / Medium | Medium | `NotificationListenerService.cancelNotification` is executed within milliseconds of system arrival. On modern Android, notifications posted during blocked periods are cancelled before user heads-up display renders in most instances. |
| **OEM Background Killing (OxygenOS/MIUI)** | High | Medium | Provide explicit in-app guidance for disabling battery optimizations. Native service is bound by `system_server`, which revives it on new notifications. |
| **Notification Access Revocation** | High | Low | Detect revocation on every app resume (`onResume`); update Dashboard banner immediately with a direct one-tap repair button. |
| **Performance Degradation During App Discovery** | Medium | Medium | Fetch installed apps and icons asynchronously in background coroutine / worker thread; cache icon bytes in memory. |
| **Data Privacy Accidental Logging** | High | Low | Zero persistence of notification titles, bodies, extras, or contents. Strict adherence to logging only non-sensitive diagnostic codes in debug builds. |

---

## 12. MVP Scope Boundaries

### In Scope for MVP:
1. Full Android feasibility PoC proving notification interception and cancellation.
2. Discovery of user-installed launcher apps with live dynamic app icons.
3. Creation, editing, pausing, and deletion of notification schedules (regular and overnight intervals).
4. Temporary override support ("Allow for 30m / 1h / today", "Block for 1h / today").
5. Background notification cancellation operating independently of the Flutter UI.
6. Offline-only, zero-backend, strict local data model.
7. Clear Android permission onboarding & settings deep-linking.
8. Clear iOS explanation screen acknowledging platform sandbox differences.

### Out of Scope for MVP (Reserved for Future Versions):
1. Notification Digest / Notification history inbox (avoid reconstructing third-party notification content until proven privacy-safe).
2. Cloud synchronization or user accounts (unnecessary and violates privacy-first core principles).
3. Sound/vibration-only filtering without cancellation (Android API does not permit modifying other apps' notification alerts without canceling).
4. System app management (filter to user launcher apps to prevent breaking system stability).

---

## Phase 0 Approval Gate

With the delivery and verification of this feasibility report, the project is ready to proceed to:
1. Setup of the Flutter / Android toolchain.
2. Minimal Android Proof of Concept verifying `NotificationListenerService` interception and cancellation on an active AVD emulator.
