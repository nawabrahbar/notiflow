# Notification Handler

> **Take control of when app notifications interrupt you.**

Notification Handler is a clean, focused, privacy-first mobile application that allows Android users to define precise delivery schedules for notifications from specific apps (e.g., allow WhatsApp between 6:00 PM and 6:00 AM, and suppress notifications outside that window).

---

## Key Features
- **App-Specific Schedules**: Configure independent schedules for any installed application.
- **Overnight Schedule Support**: Seamlessly handle overnight time windows (e.g. 10:00 PM to 7:00 AM).
- **Temporary Overrides**: Temporarily allow or block notifications (e.g., "Allow for 30 minutes" or "Block until 6 PM").
- **Reliable Background Execution**: Native Android `NotificationListenerService` operates independently of the Flutter UI with zero battery drain.
- **Absolute Privacy**: 100% offline, zero network access, zero server tracking, and zero storage of notification content.
- **Modern Material 3 Design**: Professional, calm utility aesthetic with accessible high-contrast themes.

---

## Platform Availability
- **Android**: Full support via Android's `NotificationListenerService`.
- **iOS**: Acknowledges platform sandboxing constraints; clearly informs users that third-party notification interception is not supported by Apple's public APIs.

---

## Documentation
- [Platform Feasibility & Architecture Report](file:///Users/mohammadenayatullah/Documents/Personal/notification-handler/docs/feasibility-report.md)
- [Architecture Decision Record (ADR 001)](file:///Users/mohammadenayatullah/Documents/Personal/notification-handler/docs/architecture-decision.md)
- [Architecture Overview](file:///Users/mohammadenayatullah/Documents/Personal/notification-handler/docs/architecture.md)
- [Android Notification Pipeline Flow](file:///Users/mohammadenayatullah/Documents/Personal/notification-handler/docs/android-notification-flow.md)
- [iOS Platform Limitations](file:///Users/mohammadenayatullah/Documents/Personal/notification-handler/docs/ios-platform-limitations.md)
- [Privacy and Security Guarantees](file:///Users/mohammadenayatullah/Documents/Personal/notification-handler/docs/privacy.md)
- [Testing Strategy & Verification](file:///Users/mohammadenayatullah/Documents/Personal/notification-handler/docs/testing.md)

---

## License
Private and Confidential.
