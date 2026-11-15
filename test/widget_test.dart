import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:notification_handler/data/repositories/schedule_repository.dart';
import 'package:notification_handler/domain/models/managed_app.dart';
import 'package:notification_handler/domain/models/schedule_rule.dart';
import 'package:notification_handler/domain/models/temporary_override.dart';
import 'package:notification_handler/main.dart';
import 'package:notification_handler/platform/notification_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockPlatformService implements NotificationPlatformInterface {
  @override
  Future<bool> isPlatformSupported() async => true;

  @override
  Future<bool> isNotificationAccessGranted() async => true;

  @override
  Future<void> openNotificationAccessSettings() async {}

  @override
  Future<void> openAppDetailsSettings() async {}

  @override
  Future<List<DiscoveredAppInfo>> getInstalledApplications() async => [];

  @override
  Future<void> syncSchedules({
    required List<ManagedApp> managedApps,
    required List<ScheduleRule> schedules,
    required List<TemporaryOverride> overrides,
    bool unmanagedAppsUntouched = true,
    bool vipEmergencyBypass = true,
  }) async {}

  @override
  Future<String?> exportBackupFile({
    required String fileName,
    required String content,
  }) async => '/mock/$fileName';

  @override
  Future<String?> pickBackupFile() async => null;
}

void main() {
  testWidgets('NotificationHandlerApp launches to splash screen', (WidgetTester tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({'pref_onboarding_completed': true});

    final mockPlatform = MockPlatformService();
    final repository = ScheduleRepository(platformService: mockPlatform);

    await tester.pumpWidget(NotificationHandlerApp(repository: repository));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Notiflow'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
