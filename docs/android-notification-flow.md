# Android Notification Pipeline & Interception Flow

## 1. Overview
The Android notification pipeline relies on `android.service.notification.NotificationListenerService`. This document details the exact execution path when a notification is posted to the system.

---

## 2. Sequence Diagram

```text
Android System (App posts notification)
            |
            | 1. OS notifies bound listeners
            v
NotificationHandlerListenerService.onNotificationPosted(sbn)
            |
            | 2. Extract packageName & sbn.key
            v
Is packageName in managed apps list?
       /                      \
     NO                        YES
     |                          |
   (Ignore)                     | 3. Query NativeScheduleStore for active rules
   Allow to remain              v
                           Evaluate Schedule:
                           - Check Temporary Override
                           - Check Recurring Schedules
                           - Check Days of Week & Intervals
                                |
                    +-----------+-----------+
                    |                       |
                  ALLOW                   BLOCK
                    |                       |
             Leave Untouched       4. cancelNotification(sbn.key)
                                            |
                                            v
                                  Notification dismissed 
                                  from Android status bar
```

---

## 3. Step-by-Step Execution Detail

### Step 1: System Event Reception
When any app on the device (e.g. WhatsApp) posts a notification:
```kotlin
override fun onNotificationPosted(sbn: StatusBarNotification?) {
    if (sbn == null) return
    val packageName = sbn.packageName ?: return
    val key = sbn.key ?: return
    
    handleNotification(packageName, key)
}
```

### Step 2: Management Check
The listener first leaves recognized call-like notifications untouched; not every calling app provides recognizable metadata. Other notifications proceed through app management and global override checks.

### Step 3: Schedule Evaluation in Native Kotlin
`NativeScheduleStore` evaluates the active rules for the package:
1. **Manual Override**: If an override exists for this app, its mode (`ALLOW` or `BLOCK`) immediately takes precedence until its expiry time.
2. **Standard Schedules**:
   - Compares the current local time against the app's configured time intervals.
   - Evaluates normal intervals (`start < end`, e.g., 09:00 to 17:00).
   - Evaluates overnight intervals (`start > end`, e.g., 18:00 to 06:00).
   - Validates that today is an active day of week for the rule.
3. **Default Behavior**: If no matching schedule is active or all are disabled, the default decision is `ALLOW`.

### Step 4: Action Execution
- **Decision == ALLOW**: Do nothing. The notification appears normally in the status bar with sound/vibration as configured by the user.
- **Decision == BLOCK during a rule window or pause** (Android 8.0+): Call `snoozeNotification(key, duration)` until one minute after the window ends, and record it in `held_notifications`. When Android returns it, the listener sees the window is over, lets it through without logging it again, and posts one "quiet hours ended" Catch-up digest notification about 15 seconds later.
- **Decision == BLOCK otherwise** (permanent mute, eligible foreground notifications, or if snoozing fails): Call `cancelNotification(key)`. The system immediately dismisses the notification from the notification tray. Recognized call notifications never reach this decision.

---

## 4. Key Performance and Reliability Characteristics
- **Zero Flutter Engine dependency**: The evaluation runs 100% in native Kotlin using locally cached preferences. No Flutter isolates or Dart runtimes are booted during notification arrival.
- **Latency**: Evaluation completes in under 1-2 milliseconds, preventing notification sound/heads-up banner from lingering.
- **Targeted Cancellation**: Only `snoozeNotification(key, …)` or `cancelNotification(key)` is invoked for the specific matching notification. System notifications, unmanaged apps, and allowed apps are strictly unaffected.
