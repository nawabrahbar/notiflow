# Architecture Overview: Notification Handler

## 1. System Architecture

Notification Handler follows a clean, decoupled architecture dividing responsibilities between the **Cross-Platform Application Layer (Flutter / Dart)** and the **Native Platform Layer (Android Kotlin / iOS Swift)**.

```
+-------------------------------------------------------------------------------+
|                            PRESENTATION LAYER (Flutter)                       |
|   Dashboard | Add Apps | Schedule Editor | App Details | Settings | Onboard   |
+-------------------------------------------------------------------------------+
                                        |
+-------------------------------------------------------------------------------+
|                             DOMAIN LAYER (Dart)                               |
|   ManagedApp | ScheduleRule | TemporaryOverride | ScheduleDecision            |
|   Schedule Evaluator (Pure functions, timezone-aware, overnight support)      |
+-------------------------------------------------------------------------------+
                                        |
+-------------------------------------------------------------------------------+
|                             DATA LAYER (Dart)                                 |
|   ScheduleRepository (Local cache & SharedPreferences bridge)                 |
+-------------------------------------------------------------------------------+
                                        |
                               MethodChannel Bridge
                                        |
         +------------------------------+------------------------------+
         |                                                             |
         v                                                             v
+------------------------------------+        +------------------------------------+
|        ANDROID NATIVE LAYER        |        |          IOS NATIVE LAYER          |
|  - AndroidNotificationBridge       |        |  - IosNotificationBridge           |
|    * PackageManager App Discovery  |        |    * Clean fallback interface      |
|    * Dynamic App Icon Extraction   |        |    * Supported Apple APIs only     |
|    * Permission Status & Intent    |        |                                    |
|  - NativeScheduleStore             |        +------------------------------------+
|    * SharedPreferences sync cache  |
|  - NotificationHandlerService      |
|    * NotificationListenerService   |
|    * onNotificationPosted(sbn)     |
|    * Native Schedule Evaluator     |
|    * cancelNotification(sbn.key)   |
+------------------------------------+
```

---

## 2. Core Layers and Responsibilities

### 2.1 Presentation Layer (`lib/presentation/`)
- Built using Flutter with **Material 3**.
- Visual identity:
  - Primary Accent: Teal (`#00897B`)
  - Warning/Attention: Amber (`#FFA000`)
  - Backgrounds: Dark slate neutral (`#121212`) and Crisp light neutral (`#F8F9FA`).
- Manages user flows:
  - First-run Onboarding & Permission explanation.
  - Dashboard displaying active managed apps, blocked/allowed badges, and quick toggles.
  - Add Apps screen with dynamic package search and live launcher icons.
  - Schedule Editor supporting time intervals, overnight periods, and day-of-week selections.
  - Settings, Privacy explanation, and Help/OEM guidance.

### 2.2 Domain Layer (`lib/domain/`)
- Contains zero platform-specific imports.
- Pure Dart business logic and models.
- **ScheduleEvaluator**: Evaluates whether a notification is allowed or blocked at any given timestamp:
  - Regular intervals (e.g. `09:00 -> 18:00`).
  - Overnight intervals crossing midnight (e.g. `18:00 -> 06:00`).
  - Same-start-and-end modes (`all_day_allow`, `all_day_block`).
  - Temporary overrides (take precedence over standard schedules).
  - Unmanaged apps default to `ALLOW`.

### 2.3 Android Native Layer (`android/app/src/main/kotlin/`)
- **NotificationHandlerListenerService**:
  - Bound by Android OS `system_server`.
  - Runs in background independently of Flutter UI lifecycle.
  - Intercepts incoming notifications via `onNotificationPosted(sbn: StatusBarNotification)`.
  - Queries `NativeScheduleStore` to determine if the originating package has an active block rule.
  - Suppresses notifications via `cancelNotification(sbn.key)`.
- **AndroidNotificationBridge**:
  - Handles Flutter `MethodChannel` invocations.
  - Interacts with Android's `PackageManager` to retrieve user-facing launcher applications and encode their icons as PNG bytes for Flutter rendering.
  - Checks permission status via `NotificationManagerCompat.getEnabledListenerPackages()`.
  - Fires Intent `Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS` to route users directly to the system permission screen.

---

## 3. Data Synchronization Protocol
1. User configures or updates a schedule in Flutter.
2. The domain model is serialized to structured JSON.
3. The repository writes to Flutter local preferences and invokes `MethodChannel("com.notificationhandler/bridge").invokeMethod("syncSchedules", jsonPayload)`.
4. Kotlin's `AndroidNotificationBridge` writes this JSON atomically to `SharedPreferences("notification_handler_schedules")`.
5. When `NotificationHandlerListenerService.onNotificationPosted` fires:
   - Reads the parsed cache in memory (invalidated automatically when preferences change).
   - Evaluates the schedule in `< 1ms`.
   - Executes `cancelNotification` if blocked.
