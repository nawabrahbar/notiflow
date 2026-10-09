import 'package:flutter_test/flutter_test.dart';
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
    SharedPreferences.setMockInitialValues({'pref_onboarding_completed': true});

    final mockPlatform = MockPlatformService();
    final repository = ScheduleRepository(platformService: mockPlatform);

    await tester.pumpWidget(NotificationHandlerApp(repository: repository));

    expect(find.text('Notiflow'), findsOneWidget);
  });
}
