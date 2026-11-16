# Privacy and Security Guarantees

## 1. Guiding Principles
Notification Handler is built on an unconditional **Privacy-First, Offline-First** principle. Notifications contain the most sensitive aspects of users' digital lives: personal messages, banking alerts, OTP codes, and health updates. 

This document defines the strict security and privacy guarantees enforced in the architecture.

---

## 2. Hard Architectural Guarantees

### 2.1 Zero Network Transmission
- The application contains **NO** network client libraries (no remote analytics, no crash reporting beacons, no telemetry SDKs, no cloud databases).
- No notification metadata, bundle identifiers, schedule rules, or timestamps are ever transmitted off the device.
- The app requires **NO user account** and **NO authentication**.

### 2.2 Strict On-Device Triage & Activity Logging
When the Android `NotificationListenerService` intercepts an incoming notification:
- **Evaluated Locally in Memory**:
  - `sbn.packageName` (String): Checked against the user's managed app list and active overrides.
  - `sbn.key` (String): Used to invoke `cancelNotification(key)` when a block rule or mute override applies.
  - System timestamp & category: Compared against the user's local schedule and urgent repeated call bypass window.
- **Strictly Private On-Device Activity Log**:
  - Silenced and allowed notification events for managed apps, including paused apps (capped at the most recent 150 events), are stored strictly in private app sandbox storage (`MODE_PRIVATE` `SharedPreferences`) so users can review alerts in the **Activity** tab and clear them at any time.
  - Cloud backup and device-to-device extraction are explicitly disabled (`android:allowBackup="false"` and `data_extraction_rules.xml`).

### 2.3 Release-Safe Logging
- Production builds never output suppressed package names, notification keys, or rule reasons to system `logcat`.
- ProGuard / R8 rules strip verbose/debug logging (`Log.v`, `Log.d`, `Log.i`) from release APKs and App Bundles.

### 2.4 Minimal Permissions
The app requests only what is strictly required to execute its core scheduling functionality:
- `android.permission.BIND_NOTIFICATION_LISTENER_SERVICE`: To listen to notifications and call `cancelNotification`.
- `<queries>` launcher intent filter (`CATEGORY_LAUNCHER`): To allow the user to select which installed apps to schedule without requesting `QUERY_ALL_PACKAGES`.
- Zero `INTERNET`, SMS, Contacts, Location, Camera, Microphone, or broad Storage permissions.
