# Testing Strategy & Verification Guide

## 1. Overview
Reliability in schedule evaluation and notification suppression is critical. A single logic failure could suppress an emergency notification during an allowed window, or allow unwanted notifications during sleep hours.

---

## 2. Test Pyramid

### 2.1 Schedule Engine Unit Tests (Dart)
The pure Dart schedule evaluator (`lib/domain/engine/schedule_evaluator.dart`) is tested exhaustively against all edge cases:
- **Normal Intervals (`09:00 -> 18:00`)**:
  - `08:59:59`: BLOCK
  - `09:00:00`: ALLOW
  - `17:59:59`: ALLOW
  - `18:00:00`: ALLOW (boundary definition)
  - `18:00:01`: BLOCK
- **Overnight Intervals (`18:00 -> 06:00`)**:
  - `17:59:59`: BLOCK
  - `18:00:00`: ALLOW
  - `23:59:59`: ALLOW
  - `00:00:00`: ALLOW (Day wrap-around)
  - `05:59:59`: ALLOW
  - `06:00:00`: BLOCK
- **Day of Week Recurrence**:
  - Rules active only on Weekdays (Mon-Fri) vs Weekends (Sat-Sun).
  - Overnight schedules spanning between Sunday night and Monday morning.
- **Same Start/End**:
  - Handled explicitly via `all_day_allow` and `all_day_block` modes.
- **Multiple Schedules per App**:
  - e.g. Allow 08:00-10:00 AND 18:00-22:00.
- **Precedence Hierarchy**:
  - Manual Emergency Override > Temporary Override > Recurring Schedules > Default Allow.
- **Disabled Rules**:
  - Disabled rules never cause suppression.
- **Unmanaged Apps**:
  - Always default to `ALLOW`.

### 2.2 Native Synchronization Tests (Kotlin)
- Serializing and parsing JSON schedule configurations in `NativeScheduleStore`.
- Verification of time-interval matching logic inside Kotlin `NotificationHandlerListenerService`.
- Zero-leakage verification of package filtering.

### 2.3 Integration and AVD Verification
1. Grant Notification Access via Android system settings.
2. Verify connection callback in `NotificationHandlerListenerService.onListenerConnected()`.
3. Trigger test notifications using ADB:
   ```bash
   adb shell cmd notification post -S bigtext -t "Test Alert" "test_tag" "Testing notification suppression"
   ```
4. Verify that:
   - Blocked apps have their notifications cancelled immediately.
   - Allowed apps remain in the notification drawer.
   - Unmanaged apps are untouched.
   - Suppression continues when the Flutter app is cleared from recent apps.

---

## 3. Running Automated Tests

```bash
# Run pure Dart unit tests
flutter test test/domain/schedule_evaluator_test.dart

# Run all test suites
flutter test
```
