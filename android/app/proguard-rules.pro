# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep NotificationListenerService and MainActivity entry points
-keep class com.notificationhandler.notification_handler.NotificationHandlerListenerService { *; }
-keep class com.notificationhandler.notification_handler.MainActivity { *; }

# Google Play Core In-App Updates (used by in_app_update plugin)
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Strip verbose and debug Android logs from production release builds
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int d(...);
    public static int i(...);
}
