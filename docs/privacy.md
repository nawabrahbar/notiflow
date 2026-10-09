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

### 2.2 Strict Zero-Content Processing
When the Android `NotificationListenerService` intercepts an incoming notification:
- **Never Extracted**: The notification title, message body, BigPicture, conversation thread, media attachments, actions, or extras bundle are strictly ignored and never read into memory structures.
- **Only Evaluated**:
  - `sbn.packageName` (String): Used solely to check against the user's managed app list.
  - `sbn.key` (String): Used solely to invoke `cancelNotification(key)`.
  - System timestamp: Used to compare against the user's local schedule.
- **Never Persisted**: Notification text is never stored in SQLite, SharedPreferences, files, or logs.

### 2.3 Release-Safe Logging
- Debug log statements (`Log.d`, `debugPrint`) never output notification keys or sensitive app identifiers in production/release builds.
- ProGuard / R8 rules strip all verbose logging from release APKs and App Bundles.

### 2.4 Minimal Permissions
The app requests only what is strictly required to execute its core scheduling functionality:
- `android.permission.BIND_NOTIFICATION_LISTENER_SERVICE`: To listen to notifications and call `cancelNotification`.
- Package visibility query: To allow the user to select which installed apps to schedule.
- Zero SMS, Contacts, Location, Camera, Microphone, or Storage permissions.
