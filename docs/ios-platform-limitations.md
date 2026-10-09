# iOS Platform Limitations & Architectural Compliance

## 1. Executive Summary
This document records the architectural limitations of Apple's iOS platform with respect to third-party notification scheduling, and defines the compliance rules observed by the Notification Handler codebase.

---

## 2. Platform Sandbox & Apple API Constraints

### 2.1 The Core Distinction: Android vs. iOS
- **Android**: Features an explicit, user-authorized system service (`NotificationListenerService`) allowing third-party apps to observe, inspect, and dismiss notifications posted by other apps on the device.
- **iOS**: Strictly enforces application sandboxing. There is **no public API** in the iOS SDK that allows an app or app extension to observe, read, intercept, or cancel notifications belonging to third-party applications (such as WhatsApp, Telegram, Instagram, or Mail).

### 2.2 Why `UNNotificationServiceExtension` Does Not Work
- `UNNotificationServiceExtension` is designed exclusively for an app to modify or enrich its **own** remote push notifications before presentation.
- An application's extension is executed **only** when Apple Push Notification service (APNs) delivers a push notification addressed to that application's specific bundle identifier with the `mutable-content: 1` payload flag.
- It cannot observe or affect any push or local notification belonging to any other app on the user's iPhone.

### 2.3 Focus Modes & Screen Time / DeviceActivity Frameworks
- **Focus Filters**: Apple allows apps to configure custom focus filters within their *own* app (e.g. filtering email accounts in Mail or work accounts in Messages). Third-party apps cannot control system-level notification delivery for arbitrary third-party apps.
- **DeviceActivity / FamilyControls**: Apple provides `DeviceActivity` and `ManagedSettings` primarily for parental controls and digital wellbeing. While apps can be shielded completely (blocking the entire app from launching), it does not allow selectively suppressing notifications from an app while keeping the app accessible.

---

## 3. Strict Compliance Guidelines

In accordance with Sections 2, 30, and 45 of the Product Specification:

1. **No Faking Behavior**: We will never display fake "blocked notification" logs or simulate notification suppression on iOS.
2. **No Misleading Marketing**: The iOS application will explicitly display a clear, transparent message explaining Apple platform security constraints.
3. **No Private APIs or Circumventions**: We will not use undocumented Apple private frameworks (e.g. `SpringBoard` private hooks) or recommend jailbreak tools, as these violate App Store Review Guidelines and compromise user device integrity.
4. **Codebase Cleanliness**: The iOS target builds cleanly within the shared Flutter project, with the `IosNotificationBridge` reporting platform capabilities as unsupported.
