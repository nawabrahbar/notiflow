# Architecture Decision Record (ADR 001)

## Title: Technology Stack, Cross-Platform Strategy, and Background Notification Sync

**Status:** Accepted  
**Date:** October 1, 2026  

---

## 1. Context and Problem Statement
The application "Notification Handler" requires:
1. Intercepting and suppressing notifications from selected third-party Android applications during scheduled windows (e.g., WhatsApp allowed 6 PM → 6 AM, blocked 6 AM → 6 PM).
2. A cross-platform mobile UI for managing schedules, discovering installed apps, and configuring overrides.
3. Decoupled, reliable background operation when the UI is closed or killed, without battery drain or startup latency.
4. Platform compliance: iOS does not provide public APIs for intercepting third-party app notifications.

---

## 2. Considered Alternatives

### Framework Options:
1. **Flutter + Dart (Chosen)**:
   - High-fidelity declarative UI, unified cross-platform structure, strong typing in Dart.
   - Platform channel architecture cleanly isolates native platform boundaries.
   - Enables writing the schedule evaluation engine once in pure Dart with extensive automated unit tests.
2. **Angular + Capacitor**:
   - Familiar to web developers, but adds an unnecessary WebView layer and complex bridge without solving native Android background listener execution.
   - Rejected per Section 4 of instructions.
3. **React Native**:
   - Cross-platform, but does not provide advantages over Flutter for custom utility UI and requires heavier JS runtime bridge.
   - Rejected.
4. **Kotlin Multiplatform (KMP)**:
   - Capable, but Flutter provides a faster, more mature unified UI ecosystem with Material 3 components.
   - Rejected.

### Native Notification Persistence Synchronization:
1. **Option A: Android `SharedPreferences` with Serialized JSON Rules (Chosen)**:
   - Flutter writes schedule rules and managed app IDs via `MethodChannel` directly to a dedicated `SharedPreferences` file (`notification_handler_schedules`).
   - Native Kotlin `NotificationListenerService` reads and parses this synchronously in memory upon notification arrival (`onNotificationPosted`).
   - Reading takes `< 1ms`, requires zero IPC, has no database lock contentions, and requires zero additional heavyweight database dependencies.
2. **Option B: Shared SQLite / Room Database**:
   - More relational power, but higher overhead and unnecessary schema complexity for simple per-app time interval rules.

---

## 3. Decision
1. **Frontend & Application Core**: Flutter (Dart 3.x) with Material 3.
2. **Android Native**: Kotlin using `NotificationListenerService` and `PackageManager`.
3. **iOS Native**: Swift with public Apple APIs only, honestly communicating platform limitations to the user.
4. **Schedule Engine**: Pure Dart domain engine, timezone-aware, with comprehensive automated unit test coverage.
5. **Background Sync**: Dedicated Android `SharedPreferences` providing synchronized, sub-millisecond schedule queries directly to the native background listener.

---

## 4. Consequences

### Positive:
- Single codebase for UI, domain models, and schedule engine.
- Background notification cancellation happens in < 5ms without spinning up the Flutter engine.
- Complete privacy: strictly offline-first, no network access, no notification content logging or storage.
- Transparent and honest platform boundaries: Android features full functionality; iOS build builds cleanly while clearly informing users of Apple's platform security constraints.

### Negative / Trade-offs:
- Android `NotificationListenerService` requires user to manually enable Notification Access in Android system settings.
- Android OEMs with aggressive background process management (e.g. OxygenOS) require user guidance to exempt the app from battery optimizations.
