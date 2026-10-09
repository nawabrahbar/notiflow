import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notification_handler/data/repositories/schedule_repository.dart';
import 'package:notification_handler/domain/models/managed_app.dart';
import 'package:notification_handler/domain/models/schedule_rule.dart';
import 'package:notification_handler/domain/models/temporary_override.dart';
import 'package:notification_handler/platform/notification_platform_interface.dart';
import 'package:notification_handler/platform/platform_factory.dart';
import 'package:notification_handler/presentation/screens/dashboard_screen.dart';
import 'package:notification_handler/presentation/screens/onboarding_screen.dart';
import 'package:notification_handler/presentation/screens/activity_screen.dart';
import 'package:notification_handler/presentation/screens/permission_screen.dart';
import 'package:notification_handler/presentation/screens/settings_screen.dart';
import 'package:notification_handler/presentation/screens/app_details_screen.dart';
import 'package:notification_handler/presentation/widgets/stitch_header.dart';
import 'package:notification_handler/presentation/theme/app_theme.dart';
import 'package:notification_handler/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockPlatformService implements NotificationPlatformInterface {
  bool permissionGranted = true;

  @override
  Future<bool> isPlatformSupported() async => true;

  @override
  Future<bool> isNotificationAccessGranted() async => permissionGranted;

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
  }) async => null;

  @override
  Future<String?> pickBackupFile() async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockPlatformService mockPlatform;
  late ScheduleRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    mockPlatform = MockPlatformService();
    PlatformFactory.mockPlatformService = mockPlatform;
    repository = ScheduleRepository(platformService: mockPlatform);
    await repository.initialize();
  });

  tearDown(() {
    PlatformFactory.mockPlatformService = null;
  });

  Widget wrapWithTheme(Widget child) {
    return MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(body: child),
    );
  }

  testWidgets('OnboardingScreen displays Step 1 value pillars and advances to Step 2', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(wrapWithTheme(OnboardingScreen(repository: repository)));
    await tester.pumpAndSettle();

    // Verify Step 1 title and pillars
    expect(find.text('Take back control of your attention'), findsOneWidget);
    expect(find.text('Precision Scheduling'), findsOneWidget);
    expect(find.text('100% On-Device Privacy'), findsOneWidget);
    expect(find.text('Unmanaged Apps Untouched'), findsOneWidget);

    // Tap Get Started
    final getStartedButton = find.text('Get Started');
    expect(getStartedButton, findsOneWidget);
    await tester.tap(getStartedButton);
    await tester.pumpAndSettle();

    // Verify Step 2 Notification Access requirement
    expect(find.text('Notification Access is required'), findsOneWidget);
    expect(find.text('Open Android Settings'), findsAtLeastNWidgets(1));
  });

  testWidgets('PermissionScreen displays paused status, reconnection steps, and battery guide', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    mockPlatform.permissionGranted = false;

    await tester.pumpWidget(wrapWithTheme(PermissionScreen(
      repository: repository,
      isInitialSetup: false,
    )));
    await tester.pumpAndSettle();

    expect(find.textContaining('ACTION REQUIRED'), findsOneWidget);
    expect(find.text('Notification Access is paused'), findsOneWidget);
    expect(find.text('3-Step Reconnection'), findsOneWidget);
    expect(find.text('Using Samsung, Xiaomi, or OnePlus?'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Open Android Settings'), findsOneWidget);
  });

  testWidgets('DashboardScreen displays Focus Shield Online banner when restored', (WidgetTester tester) async {
    await tester.pumpWidget(wrapWithTheme(DashboardScreen(
      repository: repository,
      initialShowRestorationBanner: true,
    )));
    await tester.pumpAndSettle();

    expect(find.text('Focus Shield Online'), findsOneWidget);
    expect(find.text('ACCESS RESTORED'), findsOneWidget);
    expect(find.text('Audit Health'), findsOneWidget);
  });

  testWidgets('SettingsScreen displays Engine status, Zero Telemetry card, and Triage preferences', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(wrapWithTheme(SettingsScreen(
      repository: repository,
      showBackButton: true,
    )));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.byType(StitchThemeSwitch), findsOneWidget);
    expect(find.text('ENGINE & BACKGROUND SERVICES'), findsOneWidget);
    expect(find.textContaining('ON-DEVICE INTEGRITY'), findsOneWidget);
    expect(find.text('TRIAGE & AUTOMATION PREFERENCES'), findsOneWidget);
    expect(find.textContaining('Reset All Rules'), findsAtLeastNWidgets(1));
  });

  testWidgets('DashboardScreen renders dynamic time greeting, quote and handles multi-select delete', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final now = DateTime.now();
    final testApp = ManagedApp(
      id: 'app_test_chat',
      packageName: 'com.test.chat',
      displayName: 'Test Chat',
      enabled: true,
      createdAt: now,
      updatedAt: now,
    );
    await repository.addApp(testApp);

    await tester.pumpWidget(wrapWithTheme(DashboardScreen(
      repository: repository,
    )));
    await tester.pumpAndSettle();

    // Verify Greeting is displayed
    expect(find.textContaining('Good '), findsOneWidget);
    // Verify an attention quote is displayed
    expect(find.byType(Text), findsWidgets);
    expect(find.text('Test Chat'), findsOneWidget);

    // Long press on app card to trigger selection mode
    await tester.longPress(find.text('Test Chat'));
    await tester.pumpAndSettle();

    // Verify selection bar is displayed with Checkbox and NO Select/Deselect All text
    expect(find.text('1 Selected'), findsOneWidget);
    expect(find.text('Select All'), findsNothing);
    expect(find.text('Deselect All'), findsNothing);
    expect(find.byKey(const Key('select_all_checkbox')), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);

    // Tap Delete button
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // Dialog confirmation
    expect(find.text('Delete 1 Rule?'), findsOneWidget);
    // Tap Delete inside dialog
    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete').last);
    await tester.pumpAndSettle();

    // Verify app was deleted
    expect(repository.managedApps.any((a) => a.id == 'app_test_chat'), isFalse);
  });

  testWidgets('ActivityScreen displays Clear Log button in events section and handles empty state', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(wrapWithTheme(ActivityScreen(repository: repository)));
    await tester.pumpAndSettle();

    // Verify exactly one Clear Log button exists (in Events section)
    expect(find.text('Clear Log'), findsOneWidget);

    // Tap Clear Log button when empty
    await tester.tap(find.text('Clear Log'));
    await tester.pumpAndSettle();

    // Verify empty state snackbar
    expect(find.text('Activity log is already empty.'), findsOneWidget);
  });

  testWidgets('StitchThemeSwitch shows Sun and hides Moon in Light mode, and shows Moon and hides Sun in Dark mode', (WidgetTester tester) async {
    // Start with Light mode
    themeModeNotifier.value = ThemeMode.light;

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: StitchThemeSwitch(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // In Light mode:
    // Sun icon should be visible, Moon icon should be hidden, 'Light' text should be visible
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsNothing);
    expect(find.byIcon(Icons.wb_sunny_rounded), findsOneWidget);
    expect(find.byIcon(Icons.nightlight_round), findsNothing);

    // Tap to switch to Dark mode
    await tester.tap(find.byType(StitchThemeSwitch));
    await tester.pumpAndSettle();

    // In Dark mode:
    // Moon icon should be visible on right, Sun icon should be hidden, 'Dark' text should be visible
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('Light'), findsNothing);
    expect(find.byIcon(Icons.nightlight_round), findsOneWidget);
    expect(find.byIcon(Icons.wb_sunny_rounded), findsNothing);

    // Tap again to switch back to Light mode
    await tester.tap(find.byType(StitchThemeSwitch));
    await tester.pumpAndSettle();

    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsNothing);
    expect(find.byIcon(Icons.wb_sunny_rounded), findsOneWidget);
    expect(find.byIcon(Icons.nightlight_round), findsNothing);
  });

  testWidgets('DashboardScreen renders "+ Add App" with single plus and no leading add icon', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final now = DateTime.now();
    await repository.addApp(ManagedApp(
      id: 'com.example.test',
      packageName: 'com.example.test',
      displayName: 'Test App',
      createdAt: now,
      updatedAt: now,
    ));

    await tester.pumpWidget(wrapWithTheme(DashboardScreen(repository: repository)));
    await tester.pumpAndSettle();

    final addAppButton = find.widgetWithText(TextButton, '+ Add App');
    expect(addAppButton, findsOneWidget);
    // Ensure no redundant Icons.add_rounded is placed inside this TextButton
    expect(find.descendant(of: addAppButton, matching: find.byIcon(Icons.add_rounded)), findsNothing);
  });

  testWidgets('AppDetailsScreen renders "+ Add Schedule" with single plus and no leading add icon', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final now = DateTime.now();
    final testApp = ManagedApp(
      id: 'com.example.test2',
      packageName: 'com.example.test2',
      displayName: 'Test App 2',
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(wrapWithTheme(AppDetailsScreen(
      app: testApp,
      repository: repository,
    )));
    await tester.pumpAndSettle();

    final addScheduleButton = find.widgetWithText(TextButton, '+ Add Schedule');
    expect(addScheduleButton, findsOneWidget);
    // Ensure no redundant Icons.add_rounded is placed inside this TextButton
    expect(find.descendant(of: addScheduleButton, matching: find.byIcon(Icons.add_rounded)), findsNothing);
  });
}

