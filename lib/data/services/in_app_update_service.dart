import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

/// Service managing Google Play In-App Updates via Play Core IPC.
/// Operates on-device without declaring android.permission.INTERNET in AndroidManifest.xml.
class InAppUpdateService {
  const InAppUpdateService();

  /// Checks Google Play for an available app update.
  /// Returns [AppUpdateInfo] if check succeeds, or null if running outside Play Store or error occurs.
  Future<AppUpdateInfo?> checkForUpdate() async {
    try {
      final info = await InAppUpdate.checkForUpdate();
      return info;
    } catch (e) {
      debugPrint('InAppUpdateService: Check for update skipped or unavailable ($e)');
      return null;
    }
  }

  /// Triggers a Google Play immediate update dialog (full screen flow).
  Future<AppUpdateResult?> performImmediateUpdate() async {
    try {
      final result = await InAppUpdate.performImmediateUpdate();
      return result;
    } catch (e) {
      debugPrint('InAppUpdateService: Immediate update failed ($e)');
      return null;
    }
  }

  /// Starts a Google Play flexible update (background download flow).
  Future<AppUpdateResult?> startFlexibleUpdate() async {
    try {
      final result = await InAppUpdate.startFlexibleUpdate();
      return result;
    } catch (e) {
      debugPrint('InAppUpdateService: Flexible update failed ($e)');
      return null;
    }
  }

  /// Completes a downloaded flexible update, prompting app restart.
  Future<void> completeFlexibleUpdate() async {
    try {
      await InAppUpdate.completeFlexibleUpdate();
    } catch (e) {
      debugPrint('InAppUpdateService: Complete flexible update failed ($e)');
    }
  }
}
