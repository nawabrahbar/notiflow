import 'package:flutter/foundation.dart';
import 'android_notification_platform.dart';
import 'ios_notification_platform.dart';
import 'notification_platform_interface.dart';

/// Provides the active [NotificationPlatformInterface] for the host platform.
class PlatformFactory {
  static NotificationPlatformInterface? mockPlatformService;

  static NotificationPlatformInterface createPlatformService() {
    if (mockPlatformService != null) return mockPlatformService!;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidNotificationPlatform();
    } else {
      return IosNotificationPlatform();
    }
  }
}
