import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderAnimatedOpacity;
import 'package:notification_handler/data/services/installed_apps_cache.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:notification_handler/data/repositories/schedule_repository.dart';
import 'package:notification_handler/domain/models/bulk_apply.dart';
import 'package:notification_handler/domain/models/managed_app.dart';
import 'package:notification_handler/domain/models/rule_template.dart';
import 'package:notification_handler/domain/models/schedule_rule.dart';
import 'package:notification_handler/domain/models/temporary_override.dart';
import 'package:notification_handler/platform/notification_platform_interface.dart';
import 'package:notification_handler/platform/platform_factory.dart';
import 'package:notification_handler/presentation/screens/dashboard_screen.dart';
import 'package:notification_handler/presentation/screens/import_rules_screen.dart';
import 'package:notification_handler/presentation/screens/main_navigation_shell.dart';
import 'package:notification_handler/presentation/screens/onboarding_screen.dart';
import 'package:notification_handler/presentation/screens/activity_screen.dart';
import 'package:notification_handler/presentation/screens/add_apps_screen.dart';
import 'package:notification_handler/presentation/screens/bulk_apply_screen.dart';
import 'package:notification_handler/presentation/screens/permission_screen.dart';
import 'package:notification_handler/presentation/screens/settings_screen.dart';
import 'package:notification_handler/presentation/screens/app_details_screen.dart';
import 'package:notification_handler/presentation/screens/schedule_editor_screen.dart';
import 'package:notification_handler/domain/models/import_report.dart';
import 'package:notification_handler/presentation/widgets/app_toast.dart';
import 'package:notification_handler/presentation/widgets/import_summary_sheet.dart';
import 'package:notification_handler/presentation/widgets/quick_mute_card.dart';
import 'package:notification_handler/presentation/widgets/stitch_header.dart';
import 'package:notification_handler/presentation/widgets/stitch_switch.dart';
import 'package:notification_handler/presentation/theme/app_theme.dart';
import 'package:notification_handler/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockPlatformService implements NotificationPlatformInterface {
  bool permissionGranted = true;
  List<DiscoveredAppInfo> installedApps = [];

  @override
  Future<bool> isPlatformSupported() async => true;

  @override
  Future<bool> isNotificationAccessGranted() async => permissionGranted;

  @override
  Future<void> openNotificationAccessSettings() async {}

  @override
  Future<void> openAppDetailsSettings() async {}

  Completer<void>? installedAppsGate;

  @override
  Future<List<DiscoveredAppInfo>> getInstalledApplications() async {
    await installedAppsGate?.future;
    return installedApps;
  }

  /// Packages reported as not installed by [getInstalledStatus].
  Set<String> uninstalledPackages = {};

  @override
  Future<List<DiscoveredAppInfo>> getInstalledAppsLite() async {
    await installedAppsGate?.future;
    return [
      for (final a in installedApps)
        DiscoveredAppInfo(
          packageName: a.packageName,
          displayName: a.displayName,
          isSystemApp: a.isSystemApp,
          androidCategory: a.androidCategory,
        ),
    ];
  }

  @override
  Future<Map<String, Uint8List>> getAppIcons(List<String> packageNames) async {
    iconRequests++;
    iconBatches.add(List.of(packageNames));
    await iconsGate?.future;
    return {
      for (final a in installedApps)
        if (packageNames.contains(a.packageName) && a.iconBytes != null)
          a.packageName: a.iconBytes!,
    };
  }

  @override
  Future<Map<String, bool>> getInstalledStatus(List<String> packageNames) async => {
        for (final p in packageNames) p: !uninstalledPackages.contains(p),
      };

  /// Simulated package-change counter and the packages changed since 0.
  int changeSequence = 0;
  List<String> changedPackages = [];
  int iconRequests = 0;
  final List<List<String>> iconBatches = [];
  Completer<void>? iconsGate;

  @override
  Future<PackageChanges?> getChangedPackages(int sequenceNumber) async =>
      PackageChanges(
        sequenceNumber: changeSequence,
        packageNames: sequenceNumber < changeSequence ? changedPackages : const [],
      );

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
  }) async => null;

  @override
  Completer<String?>? backupPicker;

  @override
  Future<String?> pickBackupFile() => backupPicker?.future ?? Future.value(null);
}

Future<void> flushFontsAndSettle(WidgetTester tester) async {
  await tester.runAsync(() async {
    await GoogleFonts.pendingFonts();
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });
  await tester.pumpAndSettle();
}

/// Steps the clock without settling: a live toast's countdown keeps
/// animating, so pumpAndSettle would run it to the end.
Future<void> pumpFor(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 50);
  for (var t = Duration.zero; t < total; t += step) {
    await tester.pump(step);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockPlatformService mockPlatform;
  late ScheduleRepository repository;

  setUp(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    mockPlatform = MockPlatformService();
    PlatformFactory.mockPlatformService = mockPlatform;
    AddAppsScreen.clearInstalledAppsCache();
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
    await flushFontsAndSettle(tester);

    // Verify Step 1 title and pillars
    expect(find.text('Take back control of your attention'), findsOneWidget);
    expect(find.text('Precision Scheduling'), findsOneWidget);
    expect(find.text('100% On-Device Privacy'), findsOneWidget);
    expect(find.text('Unmanaged Apps Untouched'), findsOneWidget);

    // Tap Get Started
    final getStartedButton = find.text('Get Started');
    expect(getStartedButton, findsOneWidget);
    await tester.tap(getStartedButton);
    await flushFontsAndSettle(tester);

    // Verify Step 2 Notification Access requirement
    expect(find.text('Notification Access is required'), findsOneWidget);
    expect(find.text('Open Android Settings'), findsAtLeastNWidgets(1));
  });

  for (final scenario in [
    (name: 'light phone', size: const Size(390, 844), mode: ThemeMode.light, tablet: false),
    (name: 'dark phone', size: const Size(390, 844), mode: ThemeMode.dark, tablet: false),
    (name: 'light tablet', size: const Size(800, 1100), mode: ThemeMode.light, tablet: true),
    (name: 'dark tablet', size: const Size(800, 1100), mode: ThemeMode.dark, tablet: true),
  ]) {
    testWidgets('Onboarding import page supports ${scenario.name}', (WidgetTester tester) async {
      tester.view.physicalSize = scenario.size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: scenario.mode,
        home: ImportRulesScreen(
          repository: repository,
        ),
      ));
      await flushFontsAndSettle(tester);

      expect(find.text('Notiflow'), findsOneWidget);
      expect(find.text('Import Rules'), findsOneWidget);
      expect(find.textContaining('STEP 3 OF 3'), findsOneWidget);
      expect(find.text('Import .notiflow Backup File'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(
        scaffold.backgroundColor,
        scenario.mode == ThemeMode.dark
            ? AppTheme.darkBackground
            : AppTheme.lightBackground,
      );

      if (scenario.tablet) {
        expect(find.text('Select .notiflow File'), findsOneWidget);
        expect(find.text('Or Paste Backup JSON'), findsOneWidget);
        expect(find.textContaining('configure filters'), findsOneWidget);
      } else {
        expect(find.text('Select .notiflow File'), findsNothing);
        expect(find.text('Or Paste Backup JSON'), findsNothing);
      }

      expect(find.text('Apply Preset & Finish'), findsNothing);
    });
  }

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
    await flushFontsAndSettle(tester);

    expect(find.textContaining('ACTION REQUIRED'), findsOneWidget);
    expect(find.text('Notification Access is paused'), findsOneWidget);
    expect(find.text('Quick Reconnection'), findsOneWidget);
    expect(find.text('Using Samsung, Xiaomi, or OnePlus?'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Open Android Settings'), findsOneWidget);
  });

  testWidgets('DashboardScreen displays Focus Shield Online banner when restored', (WidgetTester tester) async {
    await tester.pumpWidget(wrapWithTheme(DashboardScreen(
      repository: repository,
      view: DashboardView.home,
      initialShowRestorationBanner: true,
    )));
    await flushFontsAndSettle(tester);

    expect(find.text('Focus Shield Online'), findsOneWidget);
    expect(find.text('ACCESS RESTORED'), findsOneWidget);
    expect(find.text('Audit Health'), findsOneWidget);
  });

  for (final scenario in [
    (name: 'light phone', size: const Size(390, 1600), mode: ThemeMode.light, tablet: false),
    (name: 'dark phone', size: const Size(390, 1600), mode: ThemeMode.dark, tablet: false),
    (name: 'light tablet', size: const Size(800, 1600), mode: ThemeMode.light, tablet: true),
    (name: 'dark tablet', size: const Size(800, 1600), mode: ThemeMode.dark, tablet: true),
  ]) {
    testWidgets('DashboardScreen overrides section matches design on ${scenario.name}', (WidgetTester tester) async {
      tester.view.physicalSize = scenario.size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: scenario.mode,
        home: DashboardScreen(repository: repository, view: DashboardView.home),
      ));
      await flushFontsAndSettle(tester);

      expect(find.textContaining('Botanical Calm'), findsNothing);
      expect(find.text('MANAGED APPS'), findsNothing);
      expect(find.text('All caught up'), findsOneWidget);
      expect(find.textContaining(RegExp(r'^Good (morning|afternoon|evening|night)$')), findsOneWidget);
      expect(find.text('MUTED'), findsOneWidget);
      expect(find.text('ALERTS'), findsOneWidget);
      if (scenario.tablet) {
        expect(find.text('Intercepted'), findsOneWidget);
        expect(find.text('Permitted'), findsOneWidget);
      } else {
        expect(find.text('INTERCEPTED'), findsOneWidget);
        expect(find.text('PERMITTED'), findsOneWidget);
        expect(find.textContaining(RegExp(r'^(item|items)$')), findsOneWidget);
        expect(find.textContaining(RegExp(r'^(pass|passes)$')), findsOneWidget);
      }

      expect(find.text('QUICK MUTE · ALL APPS'), findsOneWidget);
      expect(find.text('QUICK SESSION OVERRIDES'), findsNothing);
      expect(find.text('OVERRIDES'), findsNothing);
      expect(find.text('Mute All (15m)'), findsNothing);

      await tester.tap(find.byKey(const Key('quick_mute_all_30')));
      await flushFontsAndSettle(tester);
      expect(repository.getActiveOverride('global_mute')?.durationMinutes, 30);
      expect(find.text('All apps muted'), findsOneWidget);
    });
  }

  testWidgets('QuickMuteAllCard mutes all apps, shows live status, extends and ends', (WidgetTester tester) async {
    await tester.pumpWidget(wrapWithTheme(Scaffold(
      body: QuickMuteAllCard(repository: repository),
    )));
    await flushFontsAndSettle(tester);

    expect(find.text('QUICK MUTE · ALL APPS'), findsOneWidget);
    expect(find.text('All apps muted'), findsNothing);

    await tester.tap(find.byKey(const Key('quick_mute_all_30')));
    await flushFontsAndSettle(tester);
    expect(repository.getActiveOverride('global_mute')?.durationMinutes, 30);
    expect(find.text('All apps muted'), findsOneWidget);
    expect(find.byKey(const Key('quick_mute_all_15')), findsNothing);
    expect(
      tester.widget<Text>(find.byKey(const Key('quick_mute_all_remaining'))).data,
      startsWith('30 min left · until '),
    );

    await tester.tap(find.byKey(const Key('quick_mute_all_extend')));
    await flushFontsAndSettle(tester);
    expect(repository.getActiveOverride('global_mute')?.durationMinutes, 45);

    await tester.tap(find.byKey(const Key('quick_mute_all_end')));
    await flushFontsAndSettle(tester);
    expect(repository.getActiveOverride('global_mute'), isNull);
    expect(find.byKey(const Key('quick_mute_all_15')), findsOneWidget);

    final bypassBefore = repository.vipEmergencyBypass;
    await tester.tap(find.byKey(const Key('quick_mute_all_repeat_callers')));
    await flushFontsAndSettle(tester);
    expect(repository.vipEmergencyBypass, !bypassBefore);
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
    await flushFontsAndSettle(tester);

    expect(find.text('Settings'), findsOneWidget);
    expect(find.byType(StitchThemeSwitch), findsOneWidget);
    expect(find.text('ENGINE & BACKGROUND SERVICES'), findsOneWidget);
    expect(find.textContaining('ON-DEVICE INTEGRITY'), findsOneWidget);
    expect(find.text('TRIAGE & AUTOMATION PREFERENCES'), findsOneWidget);
    expect(find.textContaining('Reset All Rules'), findsAtLeastNWidgets(1));
  });

  testWidgets('DashboardScreen rules view lists managed apps and handles multi-select delete', (WidgetTester tester) async {
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
    await flushFontsAndSettle(tester);

    // Rules view shows only the managed apps catalog, not the dashboard cards
    expect(find.textContaining('Good '), findsNothing);
    expect(find.text('INTERCEPTED'), findsNothing);
    expect(find.text('Test Chat'), findsOneWidget);

    // Long press on app card to trigger selection mode
    await tester.longPress(find.text('Test Chat'));
    await flushFontsAndSettle(tester);

    // Verify selection bar is displayed with Checkbox and NO Select/Deselect All text
    expect(find.text('1 Selected'), findsOneWidget);
    expect(find.text('Select All'), findsNothing);
    expect(find.text('Deselect All'), findsNothing);
    expect(find.byKey(const Key('select_all_checkbox')), findsOneWidget);
    final deleteIcon = find.byKey(const ValueKey('rules-delete-selected'));
    expect(deleteIcon, findsOneWidget);
    expect(find.text('Delete'), findsNothing);
    expect(
      tester.widget<Icon>(find.descendant(of: deleteIcon, matching: find.byType(Icon))).color,
      anyOf(AppTheme.lightError, AppTheme.darkError),
    );

    // Tap the red delete icon
    await tester.tap(deleteIcon);
    await flushFontsAndSettle(tester);

    // Dialog confirmation
    expect(find.text('Delete 1 Rule?'), findsOneWidget);
    // Tap Delete inside dialog
    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete').last);
    await flushFontsAndSettle(tester);

    // Verify app was deleted
    expect(repository.managedApps.any((a) => a.id == 'app_test_chat'), isFalse);
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    for (final size in [const Size(390, 844), const Size(800, 1100)]) {
      testWidgets('Header transition softens only scrolled content ($mode, $size)', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        final controller = ScrollController();
        addTearDown(() {
          controller.dispose();
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        var tappedItem = -1;
        var headerTaps = 0;
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: mode,
          home: Scaffold(
            appBar: StitchHeader(
              title: 'Settings',
              showThemeToggle: false,
              actions: [
                IconButton(
                  key: const ValueKey('header-action'),
                  onPressed: () => headerTaps++,
                  icon: const Icon(Icons.settings),
                ),
              ],
            ),
            body: HeaderScrollTransition(
              child: ListView.builder(
                controller: controller,
                itemExtent: 64,
                itemCount: 40,
                itemBuilder: (_, i) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => tappedItem = i,
                  child: Text('Item $i'),
                ),
              ),
            ),
          ),
        ));
        await flushFontsAndSettle(tester);
        final fade = find.byKey(const ValueKey('header-scroll-fade'));
        double opacity() => tester.renderObject<RenderAnimatedOpacity>(fade).opacity.value;
        final headerRect = tester.getRect(find.byType(StitchHeader));
        final listRect = tester.getRect(find.byType(ListView));
        final firstRect = tester.getRect(find.text('Item 0'));
        expect(opacity(), 0);

        controller.jumpTo(140);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 75));
        expect(opacity(), inExclusiveRange(0, 1));
        await tester.pumpAndSettle();
        expect(opacity(), 1);
        expect(tester.getRect(fade).height, 24);
        expect(tester.getRect(fade).top, listRect.top);
        expect(tester.getRect(find.byType(StitchHeader)), headerRect);
        // The softened strip must not intercept taps on the list underneath.
        await tester.tapAt(Offset(listRect.left + 20, listRect.top + 18));
        expect(tappedItem, 2);
        await tester.tap(find.byKey(const ValueKey('header-action')));
        expect(headerTaps, 1);

        controller.jumpTo(0);
        await tester.pumpAndSettle();
        expect(opacity(), 0);
        expect(tester.getRect(find.text('Item 0')), firstRect);
        expect(tester.takeException(), isNull);
      });

      testWidgets('Add app sheet follows the app theme ($mode, $size)', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        mockPlatform.installedApps = const [
          DiscoveredAppInfo(packageName: 'com.fresh', displayName: 'Fresh App'),
        ];
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: mode,
          home: AddAppsScreen(repository: repository),
        ));
        await flushFontsAndSettle(tester);
        await tester.tap(find.byKey(const ValueKey('add-app-com.fresh')));
        await flushFontsAndSettle(tester);

        final sheet = find.byKey(const ValueKey('app-action-sheet'));
        final decoration = tester.widget<Container>(sheet).decoration! as BoxDecoration;
        final isDark = mode == ThemeMode.dark;
        expect(decoration.color, isDark
            ? AppTheme.darkSurfaceContainerLow : AppTheme.lightSurfaceContainerLow);
        final title = tester.widget<Text>(find.descendant(
          of: sheet, matching: find.text('Fresh App'),
        ));
        expect(title.style!.fontFamily, contains('Newsreader'));
        expect(title.style!.color,
            isDark ? AppTheme.darkOnSurface : AppTheme.lightOnSurface);
        final label = tester.widget<Text>(find.text('Set up rules'));
        expect(label.style!.fontFamily, contains('PlusJakartaSans'));
        expect(label.style!.color, title.style!.color);
        expect(tester.getSize(sheet).width, lessThanOrEqualTo(560));
        expect(tester.getRect(find.text('Record history only')).bottom,
            lessThanOrEqualTo(size.height));

        await tester.tap(find.byKey(const ValueKey('history-action-rules')));
        await tester.pump();
        await flushFontsAndSettle(tester);
        expect(find.byType(AppDetailsScreen), findsOneWidget);
        expect(repository.managedApps.single.packageName, 'com.fresh');
        expect(repository.historyApps, isEmpty);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final size in [const Size(390, 844), const Size(1024, 1100)]) {
    testWidgets('Settings uses installed app version metadata ($size)', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      const channel = MethodChannel('com.notificationhandler/bridge');
      final metadata = Completer<Map<String, String>>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getAppVersion') return metadata.future;
        return null;
      });
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      await tester.pumpWidget(wrapWithTheme(SettingsScreen(repository: repository)));
      await flushFontsAndSettle(tester);
      final isTablet = size.width >= 600;
      await tester.scrollUntilVisible(
        find.text(isTablet ? 'Notiflow Loading version...' : 'Loading version...'),
        400,
      );
      metadata.complete({'version': '9.8.7', 'buildNumber': '321'});
      await flushFontsAndSettle(tester);
      expect(find.text(isTablet ? 'Notiflow v9.8.7' : 'v9.8.7'), findsOneWidget);
      expect(find.textContaining('1.6.0'), findsNothing);
      if (isTablet) {
        expect(find.textContaining('Build 321 '), findsOneWidget);
        await tester.ensureVisible(find.byKey(const ValueKey('settings-licenses')));
        await tester.tap(find.byKey(const ValueKey('settings-licenses')));
        await tester.pump();
        await flushFontsAndSettle(tester);
        expect(tester.widget<LicensePage>(find.byType(LicensePage)).applicationVersion, 'v9.8.7');
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final malformed in [false, true]) {
    testWidgets('Settings reports unavailable version instead of stale data (malformed: $malformed)', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      const channel = MethodChannel('com.notificationhandler/bridge');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getAppVersion') {
          if (malformed) return {'version': '9.8.7'};
          throw PlatformException(code: 'APP_VERSION_UNAVAILABLE');
        }
        return null;
      });
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      await tester.pumpWidget(wrapWithTheme(SettingsScreen(repository: repository)));
      await flushFontsAndSettle(tester);
      await tester.scrollUntilVisible(find.text('Version unavailable'), 400);
      expect(find.text('Version unavailable'), findsOneWidget);
      expect(find.textContaining('v1.6.'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Header transition restores scroll state, respects reduced motion and clears after resize', (tester) async {
    final controller = ScrollController(initialScrollOffset: 140);
    final count = ValueNotifier(40);
    addTearDown(controller.dispose);
    addTearDown(count.dispose);
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Scaffold(
          body: HeaderScrollTransition(
            child: ValueListenableBuilder<int>(
              valueListenable: count,
              builder: (_, items, _) => ListView.builder(
                controller: controller,
                itemCount: items,
                itemExtent: 64,
                itemBuilder: (_, i) => Text('Item $i'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    final fade = find.byKey(const ValueKey('header-scroll-fade'));
    double opacity() => tester.renderObject<RenderAnimatedOpacity>(fade).opacity.value;
    expect(opacity(), 1);
    controller.jumpTo(0);
    await tester.pump();
    expect(opacity(), 0);
    controller.jumpTo(140);
    await tester.pump();
    expect(opacity(), 1);
    count.value = 2;
    await tester.pumpAndSettle();
    expect(controller.offset, 0);
    expect(opacity(), 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Header transition ignores horizontal filter scrolling', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HeaderScrollTransition(
          child: ListView(
            children: [
              SizedBox(
                height: 100,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (var i = 0; i < 20; i++)
                      SizedBox(width: 120, child: Text('Filter $i')),
                  ],
                ),
              ),
              const SizedBox(height: 1400),
            ],
          ),
        ),
      ),
    ));
    await tester.drag(find.text('Filter 0'), const Offset(-300, 0));
    await tester.pumpAndSettle();
    final fade = find.byKey(const ValueKey('header-scroll-fade'));
    expect(tester.renderObject<RenderAnimatedOpacity>(fade).opacity.value, 0);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(390, 1000), const Size(800, 1100)]) {
    testWidgets('History filters use stored source and preserve delivery status ($size)', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      const channel = MethodChannel('com.notificationhandler/bridge');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method != 'getActivityLog') return null;
        return jsonEncode([
          for (var i = 0; i < 3; i++)
            {
              'id': '$i',
              'packageName': 'com.example.history',
              'appName': 'History App',
              'timestampMs': 1795000000000 - i * 60000,
              'isBlocked': i == 1,
              'isHistoryOnly': i < 2,
              'title': ['History allowed', 'History silenced', 'Rules allowed'][i],
              'message': 'Message $i',
            },
        ]);
      });
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      await repository.startHistoryOnly(
          packageName: 'com.example.history', displayName: 'History App');
      await tester.pumpWidget(wrapWithTheme(ActivityScreen(repository: repository)));
      await flushFontsAndSettle(tester);

      expect(find.byKey(const ValueKey('activity-history-badge')), findsNWidgets(2));
      expect(find.byKey(const ValueKey('history-manage-apps-fab')), findsNothing);
      final all = find.byKey(const ValueKey('activity-filter-all'));
      final digest = find.byKey(const ValueKey('activity-filter-digest'));
      final history = find.byKey(const ValueKey('activity-filter-history'));
      final silenced = find.byKey(const ValueKey('activity-filter-silenced'));
      final allowed = find.byKey(const ValueKey('activity-filter-allowed'));
      expect(tester.getTopLeft(all).dx, lessThan(tester.getTopLeft(digest).dx));
      expect(tester.getTopLeft(digest).dx, lessThan(tester.getTopLeft(history).dx));
      expect(tester.getTopLeft(history).dx, lessThan(tester.getTopLeft(silenced).dx));
      expect(tester.getTopLeft(silenced).dx, lessThan(tester.getTopLeft(allowed).dx));

      await tester.tap(history);
      await flushFontsAndSettle(tester);
      expect(find.textContaining('Rules allowed'), findsNothing);
      expect(find.textContaining('History allowed'), findsOneWidget);
      expect(find.textContaining('History silenced'), findsOneWidget);
      expect(find.byKey(const ValueKey('history-manage-apps-fab')), findsOneWidget);
      await repository.stopHistoryOnly(repository.historyApps.single.id);
      await flushFontsAndSettle(tester);
      expect(find.byKey(const ValueKey('activity-history-badge')), findsNWidgets(2));

      await tester.ensureVisible(silenced);
      await tester.tap(silenced);
      await flushFontsAndSettle(tester);
      expect(find.textContaining('History silenced'), findsOneWidget);
      expect(find.textContaining('History allowed'), findsNothing);
      expect(find.byKey(const ValueKey('history-manage-apps-fab')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('History Manage apps button animates and opens the picker ($size)', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      const channel = MethodChannel('com.notificationhandler/bridge');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method != 'getActivityLog') return null;
        return jsonEncode([
          for (var i = 0; i < 40; i++)
            {
              'id': '$i', 'packageName': 'com.example.history', 'appName': 'History App',
              'timestampMs': 1795000000000 - i * 60000,
              'isBlocked': false, 'isHistoryOnly': true, 'title': 'Message $i',
            },
        ]);
      });
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      await tester.pumpWidget(wrapWithTheme(ActivityScreen(repository: repository)));
      await flushFontsAndSettle(tester);
      await tester.tap(find.byKey(const ValueKey('activity-filter-history')));
      await flushFontsAndSettle(tester);
      final fab = find.byKey(const ValueKey('history-manage-apps-fab'));
      final original = tester.getRect(fab);
      final scroll = find.byType(ListView).last;
      await tester.drag(scroll, const Offset(0, -180));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.getSize(fab).width, inExclusiveRange(60, original.width));
      expect(tester.getRect(fab).right, closeTo(original.right, 0.01));
      await tester.pumpAndSettle();
      expect(tester.getSize(fab).width, closeTo(60, 0.01));
      await tester.drag(scroll, const Offset(0, 100));
      await tester.pumpAndSettle();
      expect(tester.getSize(fab).width, closeTo(original.width, 0.01));
      await tester.tap(fab);
      await flushFontsAndSettle(tester);
      expect(find.text('Manage history apps'), findsOneWidget);
      expect(tester.widget<AddAppsScreen>(find.byType(AddAppsScreen)).historyManagement, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('History Add choice and cancelled promotion keep recording ($size)', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      mockPlatform.installedApps = const [
        DiscoveredAppInfo(packageName: 'com.example.history', displayName: 'History App'),
      ];
      await tester.pumpWidget(wrapWithTheme(AddAppsScreen(repository: repository)));
      await flushFontsAndSettle(tester);
      await tester.tap(find.byKey(const ValueKey('add-app-com.example.history')));
      await flushFontsAndSettle(tester);
      expect(repository.allManagedApps, isEmpty);
      expect(find.text('Set up rules'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('history-action-history')));
      await flushFontsAndSettle(tester);
      expect(repository.managedApps, isEmpty);
      final id = repository.historyApps.single.id;
      expect(find.text('History on'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('history-manage-com.example.history')));
      await flushFontsAndSettle(tester);
      await tester.tap(find.byKey(const ValueKey('history-action-add-rules')));
      await flushFontsAndSettle(tester);
      expect(find.byType(ScheduleEditorScreen), findsOneWidget);
      expect(repository.historyApps.single.id, id);
      Navigator.of(tester.element(find.byType(ScheduleEditorScreen))).pop();
      await flushFontsAndSettle(tester);
      expect(repository.historyApps.single.id, id);
      expect(repository.schedules, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('History checkboxes add recording without changing existing paused rules apps', (tester) async {
    mockPlatform.installedApps = const [
      DiscoveredAppInfo(packageName: 'com.fresh', displayName: 'Fresh'),
      DiscoveredAppInfo(packageName: 'com.rules', displayName: 'Rules App'),
    ];
    await repository.addApp(ManagedApp(
      id: 'rules', packageName: 'com.rules', displayName: 'Rules App',
      enabled: false, createdAt: DateTime(2026), updatedAt: DateTime(2026),
    ));
    await tester.pumpWidget(wrapWithTheme(AddAppsScreen(
      repository: repository, historyManagement: true,
    )));
    await flushFontsAndSettle(tester);
    expect(find.text('Using rules'), findsOneWidget);
    expect(find.byKey(const ValueKey('history-toggle-com.rules')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('history-toggle-com.fresh')));
    await flushFontsAndSettle(tester);
    expect(repository.historyApps.single.packageName, 'com.fresh');
    expect(repository.managedApps.single.enabled, isFalse);
    expect(repository.schedules, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('History manager separates stop from confirmed deletion and reports errors', (tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    const channel = MethodChannel('com.notificationhandler/bridge');
    final deletes = <String>[];
    var failDeletion = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'deleteHistoryForApp') {
        if (failDeletion) throw PlatformException(code: 'FAILED', message: 'History could not be deleted');
        deletes.add((call.arguments as Map)['packageName'] as String);
      }
      return null;
    });
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    // Missing from the installed list: still removable in the manager.
    await repository.startHistoryOnly(
        packageName: 'com.example.history', displayName: 'History App');
    await tester.pumpWidget(wrapWithTheme(AddAppsScreen(
      repository: repository, historyManagement: true,
    )));
    await flushFontsAndSettle(tester);
    final manage = find.byKey(const ValueKey('history-manage-com.example.history'));
    Future<void> requestDeletion() async {
      await tester.tap(manage);
      await flushFontsAndSettle(tester);
      await tester.tap(find.byKey(const ValueKey('history-action-delete')));
      await flushFontsAndSettle(tester);
      expect(deletes, isEmpty);
      await tester.tap(find.byKey(const ValueKey('history-delete-confirm')));
      await tester.pump();
      await pumpFor(tester, const Duration(milliseconds: 350));
    }
    await requestDeletion();
    expect(find.text('History could not be deleted'), findsOneWidget);
    expect(repository.historyApps, hasLength(1));
    failDeletion = false;
    await requestDeletion();
    expect(deletes, ['com.example.history']);
    expect(repository.historyApps, hasLength(1));
    await tester.tap(find.byKey(const ValueKey('history-toggle-com.example.history')));
    await flushFontsAndSettle(tester);
    expect(repository.historyApps, isEmpty);
    expect(deletes, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('ActivityScreen displays Clear Log button in events section and handles empty state', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(wrapWithTheme(ActivityScreen(repository: repository)));
    await flushFontsAndSettle(tester);

    // Verify exactly one Clear Log button exists (in Events section)
    expect(find.text('Clear Log'), findsOneWidget);
    expect(find.text('Privacy Node'), findsNothing);
    expect(find.text('LOCAL'), findsNothing);

    // Tap Clear Log button when empty
    await tester.tap(find.text('Clear Log'));
    await pumpFor(tester, const Duration(milliseconds: 500));

    // Verify empty state toast
    expect(find.text('Activity log is already empty.'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('ActivityScreen phone layout matches design ($mode)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: mode,
        home: Scaffold(body: ActivityScreen(repository: repository)),
      ));
      await flushFontsAndSettle(tester);

      expect(find.textContaining('Recorded'), findsOneWidget);
      expect(find.text('Clear Log'), findsOneWidget);
      expect(find.text('All caught up'), findsOneWidget);
      expect(find.text('Intercepted'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final use24h in [false, true]) {
    testWidgets('ActivityScreen record card uses compact text and date-time (24h: $use24h)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1.0;
      const channel = MethodChannel('com.notificationhandler/bridge');
      final ts = DateTime(2026, 9, 12, 23, 40);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getActivityLog') {
          return jsonEncode([
            {
              'packageName': 'com.whatsapp',
              'appName': 'WhatsApp',
              'timestampMs': ts.millisecondsSinceEpoch,
              'isBlocked': true,
              'title': 'Sunil AP 401',
              'message': 'Hii',
            }
          ]);
        }
        return null;
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await repository.setUse24HourFormat(use24h);

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(body: ActivityScreen(repository: repository)),
      ));
      await flushFontsAndSettle(tester);

      expect(find.text(use24h ? '12 Sept, 23:40' : '12 Sept, 11:40 PM'), findsOneWidget);
      double size(String t) => tester.widget<Text>(find.text(t)).style!.fontSize!;
      FontWeight? weight(String t) => tester.widget<Text>(find.text(t)).style!.fontWeight;
      for (final t in ['WhatsApp', 'Sunil AP 401', 'Hii']) {
        expect(size(t), 13);
      }
      expect(weight('Sunil AP 401'), FontWeight.w700);
      expect(weight('Hii'), FontWeight.w400);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Activity log groups messages from one person into one card', (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1.0;
    const channel = MethodChannel('com.notificationhandler/bridge');
    final ts = DateTime(2026, 9, 12, 23, 40).millisecondsSinceEpoch;
    Map<String, dynamic> msg(int minutesAgo, String text) => {
          'packageName': 'com.whatsapp',
          'appName': 'WhatsApp',
          'timestampMs': ts - minutesAgo * 60000,
          'isBlocked': true,
          'title': 'Sunil',
          'message': text,
          'conversationKey': 'sunil@lid',
        };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getActivityLog') {
        return jsonEncode([msg(0, 'Third'), msg(5, 'Second'), msg(10, 'First')]);
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await repository.setUse24HourFormat(true);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: ActivityScreen(repository: repository)),
    ));
    await flushFontsAndSettle(tester);

    expect(find.text('12 Sept, 23:40 · 3 messages'), findsOneWidget);
    expect(find.text('1 Event'), findsOneWidget);
    // Collapsed: only the latest message.
    expect(find.text('Third'), findsOneWidget);
    expect(find.text('First'), findsNothing);
    expect(find.byIcon(Icons.expand_more_rounded), findsOneWidget);

    // The arrow expands the card in place, oldest message first.
    await tester.tap(find.byIcon(Icons.expand_more_rounded));
    await tester.pumpAndSettle();
    final dy = [for (final t in ['First', 'Second', 'Third']) tester.getTopLeft(find.text(t)).dy];
    expect(dy[0] < dy[1] && dy[1] < dy[2], isTrue);
    expect(find.text('23:30'), findsNothing);

    await tester.tap(find.byIcon(Icons.expand_less_rounded));
    await tester.pumpAndSettle();
    expect(find.text('First'), findsNothing);

    // Tapping the card itself opens the details sheet with every message.
    await tester.tap(find.text('Third'));
    await tester.pumpAndSettle();
    expect(find.text('Sunil · 3 messages'), findsOneWidget);
    expect(find.text('First'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final scenario in [
    (name: 'light phone', size: const Size(390, 900), mode: ThemeMode.light),
    (name: 'dark phone', size: const Size(390, 900), mode: ThemeMode.dark),
    (name: 'light tablet', size: const Size(1024, 1300), mode: ThemeMode.light),
    (name: 'dark tablet', size: const Size(1024, 1300), mode: ThemeMode.dark),
  ]) {
    testWidgets('Activity log resolves original icons and displays allowed and silenced events (${scenario.name})', (tester) async {
      tester.view.physicalSize = scenario.size;
      tester.view.devicePixelRatio = 1.0;
      const channel = MethodChannel('com.notificationhandler/bridge');
      final icon = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==',
      );
      mockPlatform.installedApps = [
        DiscoveredAppInfo(
          packageName: 'com.whatsapp',
          displayName: 'WhatsApp',
          iconBytes: icon,
        ),
      ];
      final now = DateTime.now();
      await repository.addApp(ManagedApp(
        id: 'whatsapp',
        packageName: 'com.whatsapp',
        displayName: 'WhatsApp',
        enabled: false,
        createdAt: now,
        updatedAt: now,
      ));
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getActivityLog') {
          return jsonEncode([
            for (final blocked in [false, true])
              {
                'packageName': 'com.whatsapp',
                'timestampMs': now.millisecondsSinceEpoch,
                'isBlocked': blocked,
                'title': blocked ? 'Muted message' : 'Paused app message',
                'message': 'Notification body',
              },
          ]);
        }
        return null;
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: scenario.mode,
        home: Scaffold(body: ActivityScreen(repository: repository)),
      ));
      await flushFontsAndSettle(tester);

      expect(find.textContaining('Paused app message'), findsOneWidget);
      expect(find.textContaining('Muted message'), findsOneWidget);
      final images = tester.widgetList<Image>(find.byType(Image)).toList();
      expect(images, hasLength(2));
      for (final image in images) {
        expect((image.image as MemoryImage).bytes, icon);
        expect(image.width, scenario.size.width < 600 ? 34 : 42);
        expect(image.height, scenario.size.width < 600 ? 34 : 42);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await flushFontsAndSettle(tester);
    });
  }

  for (final scenario in [
    (name: 'light phone', size: const Size(390, 900), mode: ThemeMode.light, tablet: false),
    (name: 'dark phone', size: const Size(390, 900), mode: ThemeMode.dark, tablet: false),
    (name: 'light tablet', size: const Size(1024, 900), mode: ThemeMode.light, tablet: true),
    (name: 'dark tablet', size: const Size(1024, 900), mode: ThemeMode.dark, tablet: true),
  ]) {
    testWidgets('MainNavigationShell nav icons match design on ${scenario.name}', (WidgetTester tester) async {
      tester.view.physicalSize = scenario.size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: scenario.mode,
        home: MainNavigationShell(repository: repository),
      ));
      await flushFontsAndSettle(tester);

      for (final label in ['Dashboard', 'Rules', 'Activity', 'Settings']) {
        expect(find.text(label), findsWidgets);
      }
      // Dashboard is the start tab.
      expect(find.byKey(const Key('digest_overview_card')), findsOneWidget);
      final labels = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .where((d) => const ['Dashboard', 'Rules', 'Apps', 'Activity', 'Settings'].contains(d))
          .toList();
      expect(labels, ['Dashboard', 'Rules', 'Activity', 'Settings']);
      if (scenario.tablet) {
        expect(find.byType(SvgPicture), findsNothing);
        expect(find.byIcon(Icons.dashboard_outlined), findsOneWidget);
        expect(find.byIcon(Icons.tune), findsOneWidget);
        expect(find.byIcon(Icons.notifications_active_outlined), findsOneWidget);
      } else {
        expect(find.byType(SvgPicture), findsNWidgets(4));
        expect(find.byIcon(Icons.tune_rounded), findsNothing);
      }

      await tester.tap(find.text('Settings').last);
      await flushFontsAndSettle(tester);
      expect(find.text('Settings'), findsWidgets);

      await tester.tap(find.text('Rules').last);
      await flushFontsAndSettle(tester);
      expect(find.text('MANAGED APPS'), findsOneWidget);

      // Add Apps opens as its own page from Rules.
      await tester.tap(find.text('Add Apps').first);
      await flushFontsAndSettle(tester);
      expect(find.byType(AddAppsScreen), findsOneWidget);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
      navigator.pop();
      await flushFontsAndSettle(tester);
      expect(find.byType(AddAppsScreen), findsNothing);
      expect(find.text('MANAGED APPS'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  String digestJson(DateTime now, {bool reviewed = false, bool running = false}) => jsonEncode([
        {
          'id': 7,
          'packageName': 'com.whatsapp',
          'appName': 'WhatsApp',
          'ruleName': 'Work hours',
          'startMs': now.subtract(const Duration(hours: 8)).millisecondsSinceEpoch,
          'endMs': (running ? now.add(const Duration(hours: 1)) : now.subtract(const Duration(minutes: 5)))
              .millisecondsSinceEpoch,
          'reviewed': reviewed,
          'isPriority': true,
          'count': 3,
          'events': [
            for (var i = 1; i <= 3; i++)
              {
                'id': '$i',
                'packageName': 'com.whatsapp',
                'appName': 'WhatsApp',
                'title': 'Chat $i',
                'message': 'Message $i',
                'timestampMs': now.subtract(Duration(hours: i)).millisecondsSinceEpoch,
                'isBlocked': true,
                'reason': 'Scheduled quiet time',
                'windowId': 7,
              },
          ],
        },
      ]);

  for (final scenario in [
    (name: 'light phone', size: const Size(390, 1400), mode: ThemeMode.light),
    (name: 'dark phone', size: const Size(390, 1400), mode: ThemeMode.dark),
    (name: 'light tablet', size: const Size(1024, 1300), mode: ThemeMode.light),
    (name: 'dark tablet', size: const Size(1024, 1300), mode: ThemeMode.dark),
  ]) {
    testWidgets('Dashboard digest card opens the Activity Digest and marks it reviewed (${scenario.name})', (tester) async {
      tester.view.physicalSize = scenario.size;
      tester.view.devicePixelRatio = 1.0;
      const channel = MethodChannel('com.notificationhandler/bridge');
      final now = DateTime.now();
      var reviewed = false;
      final markedIds = <List<Object?>>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'getDigest':
            return digestJson(now, reviewed: reviewed);
          case 'getActivityLog':
            return '[]';
          case 'markDigestReviewed':
            markedIds.add((call.arguments as Map)['ids'] as List<Object?>);
            reviewed = true;
            return null;
        }
        return null;
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: scenario.mode,
        home: MainNavigationShell(repository: repository),
      ));
      await flushFontsAndSettle(tester);

      expect(find.text('3 silenced notifications'), findsOneWidget);
      expect(find.text('Review now'), findsOneWidget);

      await tester.tap(find.byKey(const Key('digest_overview_card')));
      await flushFontsAndSettle(tester);

      expect(find.text('Activity Log'), findsOneWidget);
      expect(find.byKey(const ValueKey('digest_window_7')), findsOneWidget);
      expect(find.byKey(const ValueKey('digest_unreviewed_7')), findsOneWidget);
      expect(find.text('3 silenced'), findsOneWidget);
      expect(find.text('WhatsApp'), findsWidgets);

      await tester.tap(find.byKey(const ValueKey('digest_window_7')));
      await flushFontsAndSettle(tester);

      expect(markedIds, [
        [7]
      ]);
      expect(find.byKey(const ValueKey('digest_unreviewed_7')), findsNothing);
      expect(find.textContaining('Chat 1'), findsOneWidget);
      expect(find.textContaining('Chat 3'), findsOneWidget);

      await tester.tap(find.text('Dashboard').last);
      await flushFontsAndSettle(tester);
      expect(find.text('All caught up'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Opening a digest window that is still running does not mark it reviewed', (tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
    const channel = MethodChannel('com.notificationhandler/bridge');
    final now = DateTime.now();
    final markedIds = <Object?>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'getDigest':
          return digestJson(now, running: true);
        case 'getActivityLog':
          return '[]';
        case 'markDigestReviewed':
          markedIds.add(call.arguments);
          return null;
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: MainNavigationShell(repository: repository),
    ));
    await flushFontsAndSettle(tester);
    await tester.tap(find.byKey(const Key('digest_overview_card')));
    await flushFontsAndSettle(tester);

    await tester.tap(find.byKey(const ValueKey('digest_window_7')));
    await flushFontsAndSettle(tester);

    expect(find.textContaining('Chat 1'), findsOneWidget);
    expect(markedIds, isEmpty);
    expect(find.byKey(const ValueKey('digest_unreviewed_7')), findsOneWidget);
  });

  testWidgets('AppToast closes on ×, on timeout, and when replaced', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      })),
    ));

    final first = AppToast.show(ctx, message: 'Saved', type: AppToastType.info);
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.text('Saved'), findsOneWidget);
    expect(find.byIcon(Icons.info_rounded), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await pumpFor(tester, const Duration(milliseconds: 400));
    expect(await first, AppToastClosedReason.dismissed);
    expect(find.text('Saved'), findsNothing);

    final timed = AppToast.show(ctx, message: 'Timed');
    await pumpFor(tester, AppToast.defaultDuration + const Duration(milliseconds: 400));
    expect(await timed, AppToastClosedReason.timeout);
    expect(find.text('Timed'), findsNothing);

    final old = AppToast.show(ctx, message: 'Old', actionLabel: 'Undo');
    await pumpFor(tester, const Duration(milliseconds: 500));
    final replacement = AppToast.show(ctx, message: 'New', type: AppToastType.error);
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(await old, AppToastClosedReason.replaced);
    expect(find.text('Old'), findsNothing);
    expect(find.text('New'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(await replacement, AppToastClosedReason.timeout);
  });

  testWidgets('AppToast floats above the phone nav bar', (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Builder(builder: (c) {
          ctx = c;
          return const SizedBox();
        }),
        bottomNavigationBar: const AppToastBottomBar(child: SizedBox(height: 80)),
      ),
    ));
    AppToast.show(ctx, message: 'Above nav');
    await pumpFor(tester, const Duration(milliseconds: 500));
    final rect = tester.getRect(find.ancestor(of: find.text('Above nav'), matching: find.byType(Material)).first);
    expect(rect.bottom, lessThanOrEqualTo(800 - 80 - 12));
    await tester.pumpAndSettle();
  });

  testWidgets('AppToast floats above dialogs', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      builder: (context, child) => AppToastHost(child: child!),
      home: Scaffold(body: Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      })),
    ));
    showDialog<void>(context: ctx, builder: (_) => const AlertDialog(title: Text('Open dialog')));
    await tester.pumpAndSettle();
    final closed = AppToast.show(ctx, message: 'On top');
    await pumpFor(tester, const Duration(milliseconds: 500));
    await tester.tap(find.byTooltip('Close'));
    await pumpFor(tester, const Duration(milliseconds: 400));
    expect(await closed, AppToastClosedReason.dismissed);
    expect(find.text('Open dialog'), findsOneWidget);
  });

  test('Screens show toasts only through AppToast', () {
    final offenders = [
      for (final f in Directory('lib').listSync(recursive: true))
        if (f is File &&
            f.path.endsWith('.dart') &&
            f.readAsStringSync().contains('showSnackBar('))
          f.path,
    ];
    expect(offenders, isEmpty);
  });

  for (final scenario in [
    (name: 'phone', size: const Size(390, 1400)),
    (name: 'tablet', size: const Size(1024, 1300)),
  ]) {
    testWidgets('Swiping an Activity log card deletes it with Undo (${scenario.name})', (tester) async {
      tester.view.physicalSize = scenario.size;
      tester.view.devicePixelRatio = 1.0;
      const channel = MethodChannel('com.notificationhandler/bridge');
      final now = DateTime.now();
      final deleted = <String>{};
      final deleteCalls = <List<Object?>>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'getActivityLog':
            return jsonEncode([
              for (final (id, pkg, title, hours) in [
                ('10', 'com.slack', 'Slack ping', 1),
                ('11', 'com.gmail', 'Mail in', 5),
              ])
                if (!deleted.contains(id))
                  {
                    'id': id,
                    'packageName': pkg,
                    'title': title,
                    'message': 'Body',
                    'timestampMs': now.subtract(Duration(hours: hours)).millisecondsSinceEpoch,
                    'isBlocked': true,
                  },
            ]);
          case 'deleteActivityEvents':
            final ids = (call.arguments as Map)['ids'] as List<Object?>;
            deleteCalls.add(ids);
            deleted.addAll(ids.cast<String>());
            return null;
        }
        return null;
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(body: ActivityScreen(repository: repository)),
      ));
      await flushFontsAndSettle(tester);
      expect(find.textContaining('Slack ping'), findsOneWidget);

      await tester.fling(find.textContaining('Slack ping'), const Offset(600, 0), 2000);
      await pumpFor(tester, const Duration(seconds: 1));
      expect(find.textContaining('Slack ping'), findsNothing);
      expect(find.text('Message deleted'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await pumpFor(tester, const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.textContaining('Slack ping'), findsOneWidget);
      expect(deleteCalls, isEmpty);

      await tester.fling(find.textContaining('Slack ping'), const Offset(600, 0), 2000);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await flushFontsAndSettle(tester);
      expect(deleteCalls, [
        ['10']
      ]);
      expect(find.textContaining('Slack ping'), findsNothing);
      expect(find.textContaining('Mail in'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Swiping a digest card deletes the window and its log messages', (tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
    const channel = MethodChannel('com.notificationhandler/bridge');
    final now = DateTime.now();
    var windowDeleted = false;
    final deleteCalls = <List<Object?>>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'getDigest':
          return windowDeleted ? '[]' : digestJson(now, reviewed: true);
        case 'getActivityLog':
          if (windowDeleted) return '[]';
          final window = (jsonDecode(digestJson(now)) as List).first as Map;
          return jsonEncode(window['events']);
        case 'deleteDigestWindows':
          deleteCalls.add((call.arguments as Map)['ids'] as List<Object?>);
          windowDeleted = true;
          return null;
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: ActivityScreen(repository: repository)),
    ));
    await flushFontsAndSettle(tester);
    expect(find.textContaining('Chat 1'), findsWidgets);

    await tester.tap(find.textContaining('Digest').first);
    await flushFontsAndSettle(tester);
    await tester.fling(find.byKey(const ValueKey('digest_window_7')), const Offset(600, 0), 2000);
    await pumpFor(tester, const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('digest_window_7')), findsNothing);
    expect(find.text('Digest deleted · 3 messages'), findsOneWidget);

    // Its messages leave the log too, before the delete is committed.
    await tester.tap(find.textContaining('All').first);
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.textContaining('Chat 1'), findsNothing);
    expect(deleteCalls, isEmpty);

    await tester.pump(const Duration(seconds: 5));
    await flushFontsAndSettle(tester);
    expect(deleteCalls, [
      [7]
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Activity Digest filter shows an empty state when nothing was silenced', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: ActivityScreen(repository: repository)),
    ));
    await flushFontsAndSettle(tester);

    await tester.tap(find.textContaining('Digest').first);
    await flushFontsAndSettle(tester);
    expect(find.textContaining('Nothing to catch up on'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final scenario in [
    (name: 'phone', size: const Size(390, 800), tablet: false),
    (name: 'tablet', size: const Size(1024, 800), tablet: true),
  ]) {
    testWidgets('StitchThemeSwitch matches design toggle on ${scenario.name}', (WidgetTester tester) async {
      tester.view.physicalSize = scenario.size;
      tester.view.devicePixelRatio = 1.0;
      themeModeNotifier.value = ThemeMode.light;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        themeModeNotifier.value = ThemeMode.light;
      });

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Center(child: StitchThemeSwitch()))),
      );
      await flushFontsAndSettle(tester);

      double dx(Finder f) => tester.getCenter(f).dx;
      final moon = scenario.tablet ? Icons.dark_mode_outlined : Icons.dark_mode;

      expect(find.text('Light'), findsOneWidget);
      expect(find.byIcon(moon), findsNothing);
      expect(dx(find.byIcon(Icons.light_mode_outlined)), lessThan(dx(find.text('Light'))));

      await tester.tap(find.byType(StitchThemeSwitch));
      await flushFontsAndSettle(tester);

      expect(find.text('Dark'), findsOneWidget);
      expect(find.byIcon(Icons.light_mode_outlined), findsNothing);
      if (scenario.tablet) {
        expect(dx(find.byIcon(moon)), lessThan(dx(find.text('Dark'))));
      } else {
        expect(dx(find.byIcon(moon)), greaterThan(dx(find.text('Dark'))));
      }

      await tester.tap(find.byType(StitchThemeSwitch));
      await flushFontsAndSettle(tester);
      expect(find.text('Light'), findsOneWidget);
    });
  }

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
    await flushFontsAndSettle(tester);

    final addAppFab = find.byKey(const ValueKey('rules-add-app-fab'));
    final applyFab = find.byKey(const ValueKey('rules-apply-fab'));
    expect(addAppFab, findsOneWidget);
    expect(find.text('+ Add App'), findsNothing);
    expect(find.text('Add Apps'), findsNothing);
    expect(tester.getCenter(addAppFab).dy, lessThan(tester.getCenter(applyFab).dy));
    await tester.tap(addAppFab);
    await flushFontsAndSettle(tester);
    expect(find.byType(AddAppsScreen), findsOneWidget);
  });

  testWidgets('DashboardScreen shows only the big Add Apps button when no apps are managed', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(wrapWithTheme(DashboardScreen(repository: repository)));
    await flushFontsAndSettle(tester);

    expect(find.text('No apps managed yet'), findsOneWidget);
    expect(find.text('Add Apps'), findsOneWidget);
    expect(find.byKey(const ValueKey('rules-add-app-fab')), findsNothing);
  });

  for (final scenario in [
    (name: 'light phone', size: const Size(390, 2400), mode: ThemeMode.light),
    (name: 'dark phone', size: const Size(390, 2400), mode: ThemeMode.dark),
    (name: 'light tablet', size: const Size(1024, 2000), mode: ThemeMode.light),
    (name: 'dark tablet', size: const Size(1024, 2000), mode: ThemeMode.dark),
  ]) {
    testWidgets('AppDetailsScreen section headers and Remove button placement on ${scenario.name}', (WidgetTester tester) async {
      tester.view.physicalSize = scenario.size;
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

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: scenario.mode,
        home: AppDetailsScreen(app: testApp, repository: repository),
      ));
      await flushFontsAndSettle(tester);

      expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
      expect(find.text('+ Add Schedule'), findsNothing);
      expect(find.text('ACTIVE SCHEDULE RULES (0)'), findsOneWidget);
      expect(find.text('QUICK TEMPORARY BLOCK'), findsOneWidget);

      double top(String t) => tester.getTopLeft(find.text(t)).dy;
      expect(top('Remove from Rules Page'), greaterThan(top('Add Schedule Rule')));
      final done = find.byKey(const ValueKey('app-details-done-fab'));
      expect(done.hitTestable(), findsOneWidget);
      expect(find.text('Save Changes'), findsNothing);
      expect(tester.getBottomLeft(find.text('Remove from Rules Page')).dy,
          lessThan(tester.getTopLeft(done).dy));
      await tester.tap(done);
      await tester.pump();
      await flushFontsAndSettle(tester);
      expect(find.byType(MainNavigationShell), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('AppDetailsScreen schedule card edit/delete icons are right-aligned with the switch', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final now = DateTime.now();
    final testApp = ManagedApp(
      id: 'com.example.rules',
      packageName: 'com.example.rules',
      displayName: 'Rules App',
      createdAt: now,
      updatedAt: now,
    );
    await repository.addApp(testApp);
    await repository.saveRule(ScheduleRule(
      id: 'r1',
      appId: testApp.id,
      name: 'Work Focus Hours',
      mode: ScheduleMode.blockDuring,
      startTime: const TimeOfDayValue(hour: 9, minute: 0),
      endTime: const TimeOfDayValue(hour: 17, minute: 0),
      daysOfWeek: {1, 2, 3, 4, 5},
      createdAt: now,
      updatedAt: now,
    ), autoSaveTemplate: false);

    await tester.pumpWidget(wrapWithTheme(AppDetailsScreen(app: testApp, repository: repository)));
    await flushFontsAndSettle(tester);

    final deleteRight = tester.getTopRight(find.byIcon(Icons.delete_outline_rounded)).dx;
    final switchRight = tester.getTopRight(find.byType(StitchSwitch).first).dx;
    expect((deleteRight - switchRight).abs(), lessThanOrEqualTo(2));
    expect(
      tester.getTopRight(find.byIcon(Icons.edit_outlined)).dx,
      lessThan(tester.getTopLeft(find.byIcon(Icons.delete_outline_rounded)).dx),
    );
  });

  testWidgets('AppDetailsScreen displays Quick Temporary Block section, mutes on tap, and toggles off', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final now = DateTime.now();
    final testApp = ManagedApp(
      id: 'com.example.quicktest',
      packageName: 'com.example.quicktest',
      displayName: 'Quick Test App',
      createdAt: now,
      updatedAt: now,
    );
    await repository.addApp(testApp);

    await tester.pumpWidget(wrapWithTheme(AppDetailsScreen(
      app: testApp,
      repository: repository,
    )));
    await flushFontsAndSettle(tester);

    // Verify section header exists
    expect(find.text('QUICK TEMPORARY BLOCK'), findsOneWidget);
    expect(find.text('15m Mute'), findsOneWidget);
    expect(find.text('30m Mute'), findsOneWidget);
    expect(find.text('1h Mute'), findsOneWidget);
    expect(find.text('+ Custom'), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsNothing);
    final pillHeights = ['15m Mute', '30m Mute', '1h Mute', '+ Custom']
        .map((t) => tester.getSize(find.ancestor(of: find.text(t), matching: find.byType(Container)).first).height)
        .toSet();
    expect(pillHeights, {48.0});
    expect(find.text('Clear Temporary Override'), findsNothing);

    // Tap 15m Mute pill
    await tester.tap(find.text('15m Mute'));
    await flushFontsAndSettle(tester);

    // Override should now be active
    expect(repository.getActiveOverride(testApp.id), isNotNull);
    expect(find.text('Clear Temporary Override'), findsOneWidget);
    expect(find.textContaining('LEFT'), findsOneWidget);

    // Tap 15m Mute again to toggle off
    await tester.tap(find.text('15m Mute'));
    await flushFontsAndSettle(tester);

    // Override should be cleared
    expect(repository.getActiveOverride(testApp.id), isNull);
    expect(find.text('Clear Temporary Override'), findsNothing);

    // Tap + Custom pill to open custom mute dialog
    await tester.tap(find.text('+ Custom'));
    await flushFontsAndSettle(tester);

    // Dialog should be open
    expect(find.text('Custom Mute Duration'), findsOneWidget);
    expect(find.text('QUICK SELECT'), findsOneWidget);
    expect(find.text('3h'), findsOneWidget);

    // Select 3h preset and confirm
    await tester.tap(find.text('3h'));
    await flushFontsAndSettle(tester);
    await tester.tap(find.text('Mute for 3 hrs'));
    await flushFontsAndSettle(tester);

    // Override should now be active for 3 hours and pill should dynamically display '3h Mute'
    expect(repository.getActiveOverride(testApp.id), isNotNull);
    expect(repository.getActiveOverride(testApp.id)!.durationMinutes, 180);
    expect(find.text('3h Mute'), findsOneWidget);
    expect(find.text('+ Custom'), findsNothing);
    expect(find.text('Clear Temporary Override'), findsOneWidget);

    // Tap Clear Temporary Override button
    await tester.tap(find.text('Clear Temporary Override'));
    await flushFontsAndSettle(tester);

    // Custom timer should now be cleared and pill should reset back to + Custom
    expect(repository.getActiveOverride(testApp.id), isNull);
    expect(find.text('Clear Temporary Override'), findsNothing);
    expect(find.text('+ Custom'), findsOneWidget);
    expect(find.text('3h Mute'), findsNothing);
  });

  testWidgets('AddAppsScreen shows Manage for managed apps and opens app details', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    mockPlatform.installedApps = const [
      DiscoveredAppInfo(packageName: 'com.example.managed', displayName: 'Managed App'),
      DiscoveredAppInfo(packageName: 'com.example.fresh', displayName: 'Fresh App'),
    ];
    final now = DateTime.now();
    await repository.addApp(ManagedApp(
      id: 'com.example.managed',
      packageName: 'com.example.managed',
      displayName: 'Managed App',
      createdAt: now,
      updatedAt: now,
    ));

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: AddAppsScreen(repository: repository),
    ));
    await flushFontsAndSettle(tester);

    expect(find.text('Auto-synced'), findsNothing);
    expect(find.text('Active'), findsNothing);
    expect(find.text('Manage'), findsOneWidget);
    expect(find.byKey(const ValueKey('add-app-com.example.fresh')), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);
    expect(tester.getTopRight(find.textContaining('AVAILABLE')).dx, greaterThan(390 - 40));

    await repository.removeApp('com.example.managed');
    await tester.pump();
    expect(find.text('Manage'), findsNothing);
    expect(find.text('Add'), findsNWidgets(2));

    await repository.addApp(ManagedApp(
      id: 'com.example.managed',
      packageName: 'com.example.managed',
      displayName: 'Managed App',
      createdAt: now,
      updatedAt: now,
    ));
    await tester.pump();
    expect(find.text('Manage'), findsOneWidget);

    await tester.tap(find.text('Manage'));
    await flushFontsAndSettle(tester);
    expect(find.byType(AppDetailsScreen), findsOneWidget);
  });

  for (final size in [const Size(390, 844), const Size(1024, 900)]) {
    testWidgets('Rules buttons animate together with anchored right edges ($size)', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (var i = 0; i < 20; i++) {
        await repository.addApp(ManagedApp(
          id: 'app_$i',
          packageName: 'com.app$i',
          displayName: 'App $i',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ));
      }
      await tester.pumpWidget(wrapWithTheme(DashboardScreen(repository: repository)));
      await flushFontsAndSettle(tester);
      final add = find.byKey(const ValueKey('rules-add-app-fab'));
      final apply = find.byKey(const ValueKey('rules-apply-fab'));
      final initialAdd = tester.getRect(add);
      final initialApply = tester.getRect(apply);
      final scroll = find.byType(Scrollable).first;

      await tester.drag(scroll, const Offset(0, -180));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final midAdd = tester.getRect(add);
      final midApply = tester.getRect(apply);
      expect(midAdd.width, inExclusiveRange(60, initialAdd.width));
      expect(midApply.width, inExclusiveRange(60, initialApply.width));
      expect(midAdd.right, closeTo(initialAdd.right, 0.01));
      expect(midApply.right, closeTo(initialApply.right, 0.01));
      expect(
        (midAdd.width - 60) / (initialAdd.width - 60),
        closeTo((midApply.width - 60) / (initialApply.width - 60), 0.001),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(add).width, closeTo(60, 0.01));
      expect(tester.getSize(apply).width, closeTo(60, 0.01));

      await tester.drag(scroll, const Offset(0, 100));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.getSize(add).width, inExclusiveRange(60, initialAdd.width));
      await tester.drag(scroll, const Offset(0, -60));
      await tester.pumpAndSettle();
      expect(tester.getSize(add).width, closeTo(60, 0.01));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Add Apps icons update without rebuilding rows or shifting the list ($size)', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final icon = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==',
      );
      mockPlatform.installedApps = [
        for (var i = 0; i < 100; i++)
          DiscoveredAppInfo(
            packageName: 'com.app$i',
            displayName: 'App $i',
            iconBytes: icon,
          ),
      ];
      mockPlatform.iconsGate = Completer<void>();
      await tester.pumpWidget(wrapWithTheme(AddAppsScreen(repository: repository)));
      await flushFontsAndSettle(tester);

      final add = find.byKey(const ValueKey('add-app-com.app0'));
      final buttonBefore = tester.widget(add);
      final rectBefore = tester.getRect(add);
      final position = tester.state<ScrollableState>(find.byType(Scrollable).last).position;
      final offsetBefore = position.pixels;
      mockPlatform.iconsGate!.complete();
      await flushFontsAndSettle(tester);
      expect(identical(tester.widget(add), buttonBefore), isTrue,
          reason: 'icon arrivals must not rebuild the page or app rows');
      expect(tester.getRect(add), rectBefore);
      expect(position.pixels, offsetBefore);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('app-icon-com.app0')),
          matching: find.byType(Image),
        ),
        findsOneWidget,
      );
      expect(mockPlatform.iconBatches, isNotEmpty);
      expect(mockPlatform.iconBatches.every((b) => b.length <= 8), isTrue);
      expect(mockPlatform.iconBatches.expand((b) => b).toSet().length,
          lessThan(mockPlatform.installedApps.length),
          reason: 'prefetch remains viewport-bounded, not all apps up front');
      final requests = mockPlatform.iconRequests;
      await InstalledAppsCache.instance.loadIcons(mockPlatform.iconBatches.expand((b) => b));
      expect(mockPlatform.iconRequests, requests, reason: 'loaded icons stay cached');

      final list = find.byType(Scrollable).last;
      await tester.fling(list, const Offset(0, -350), 1500);
      await flushFontsAndSettle(tester);
      await tester.enterText(find.byType(TextField), 'App 99');
      await flushFontsAndSettle(tester);
      expect(find.byKey(const ValueKey('add-app-com.app99')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Rules buttons respect reduced motion', (tester) async {
    for (var i = 0; i < 20; i++) {
      await repository.addApp(ManagedApp(
        id: 'app_$i',
        packageName: 'com.app$i',
        displayName: 'App $i',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ));
    }
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: DashboardScreen(repository: repository),
    ));
    await flushFontsAndSettle(tester);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -180));
    await tester.pump();
    expect(tester.getSize(find.byKey(const ValueKey('rules-add-app-fab'))).width,
        closeTo(60, 0.01));
    expect(tester.getSize(find.byKey(const ValueKey('rules-apply-fab'))).width,
        closeTo(60, 0.01));
  });

  test('InstalledAppsCache fetches icons once and flags uninstalled apps only after loading', () async {
    final cache = InstalledAppsCache.instance;
    mockPlatform.installedApps = [
      DiscoveredAppInfo(
          packageName: 'com.example.one',
          displayName: 'One App',
          iconBytes: Uint8List.fromList([1, 2, 3])),
    ];
    mockPlatform.uninstalledPackages = {'com.example.gone'};

    expect(cache.isUninstalled('com.example.gone'), isFalse);
    await cache.ensureLoaded();
    expect(cache.iconFor('com.example.one'), isNull);

    await cache.loadIcons(['com.example.one']);
    await cache.loadIcons(['com.example.one']);
    expect(cache.iconFor('com.example.one'), [1, 2, 3]);
    expect(mockPlatform.iconRequests, 1);

    await cache.checkInstalled(['com.example.one', 'com.example.gone']);
    expect(cache.isUninstalled('com.example.one'), isFalse);
    expect(cache.isUninstalled('com.example.gone'), isTrue);
  });

  testWidgets('Rules page greys out uninstalled apps but keeps the rule', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final now = DateTime.now();
    await repository.addApp(ManagedApp(
      id: 'com.example.gone',
      packageName: 'com.example.gone',
      displayName: 'Gone App',
      createdAt: now,
      updatedAt: now,
    ));
    mockPlatform.uninstalledPackages = {'com.example.gone'};

    await tester.pumpWidget(wrapWithTheme(DashboardScreen(repository: repository)));
    await flushFontsAndSettle(tester);
    expect(find.text('UNINSTALLED'), findsNothing);

    await tester.runAsync(() =>
        InstalledAppsCache.instance.checkInstalled(['com.example.gone']));
    await tester.pump();
    expect(find.text('UNINSTALLED'), findsOneWidget);

    await tester.tap(find.byType(StitchSwitch), warnIfMissed: false);
    await tester.pump();
    expect(repository.managedApps.single.enabled, isTrue);

    await tester.tap(find.text('Gone App'));
    await flushFontsAndSettle(tester);
    expect(find.byType(AppDetailsScreen), findsOneWidget);
  });

  testWidgets('AddAppsScreen reuses the shared app list and refreshes only changed packages', (WidgetTester tester) async {
    mockPlatform.installedApps = [
      DiscoveredAppInfo(packageName: 'com.example.one', displayName: 'One App'),
    ];
    Future<void> open() async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: AddAppsScreen(key: UniqueKey(), repository: repository),
      ));
    }

    await open();
    await flushFontsAndSettle(tester);
    expect(find.byKey(const ValueKey('add-app-com.example.one')), findsOneWidget);

    mockPlatform.installedApps = [
      ...mockPlatform.installedApps,
      DiscoveredAppInfo(packageName: 'com.example.two', displayName: 'Two App'),
    ];
    mockPlatform.installedAppsGate = Completer<void>();
    await open();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byKey(const ValueKey('add-app-com.example.one')), findsOneWidget);
    expect(find.byKey(const ValueKey('add-app-com.example.two')), findsNothing);

    mockPlatform.installedAppsGate!.complete();
    mockPlatform.changeSequence = 1;
    mockPlatform.changedPackages = ['com.example.two'];
    InstalledAppsCache.instance.refreshChanges();
    await tester.pump();
    await flushFontsAndSettle(tester);
    expect(find.byKey(const ValueKey('add-app-com.example.two')), findsOneWidget);
  });

  for (final scenario in [
    (name: 'light phone', size: const Size(390, 844), mode: ThemeMode.light),
    (name: 'dark phone', size: const Size(390, 844), mode: ThemeMode.dark),
    (name: 'light tablet', size: const Size(1024, 1300), mode: ThemeMode.light),
    (name: 'dark tablet', size: const Size(1024, 1300), mode: ThemeMode.dark),
  ]) {
    testWidgets('Schedule editor aligns rule name and keeps Save visible (${scenario.name})', (WidgetTester tester) async {
      tester.view.physicalSize = scenario.size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetViewInsets();
      });

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: scenario.mode,
        home: ScheduleEditorScreen(repository: repository),
      ));
      await flushFontsAndSettle(tester);

      final button = find.byKey(const ValueKey('schedule-save-fab'));
      expect(button.hitTestable(), findsOneWidget);
      final initialButton = tester.getRect(button);
      expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
      final dropdown = find.byKey(const ValueKey('template-dropdown'));
      final dropdownRect = tester.getRect(dropdown);
      await tester.tap(dropdown);
      await flushFontsAndSettle(tester);
      final menuItem = find.byType(MenuItemButton).first;
      final menuPanel = find.ancestor(of: menuItem, matching: find.byType(Material)).first;
      final menuRect = tester.getRect(menuPanel);
      expect(menuRect.top, greaterThanOrEqualTo(dropdownRect.bottom));
      expect(menuRect.top - dropdownRect.bottom, lessThan(12));
      expect((menuRect.left - dropdownRect.left).abs(), lessThan(1));
      expect((menuRect.width - dropdownRect.width).abs(), lessThan(1));
      await tester.tapAt(const Offset(5, 5));
      await flushFontsAndSettle(tester);

      await tester.enterText(find.byType(TextField), 'Work Focus Hours');
      await tester.pump();

      final textCenter = tester.getCenter(find.text('Work Focus Hours'));
      final iconCenter = tester.getCenter(find.byIcon(Icons.edit_note_rounded));
      expect((textCenter.dy - iconCenter.dy).abs(), lessThan(1.5));

      final position = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      ).position;
      position.jumpTo(position.maxScrollExtent);
      await flushFontsAndSettle(tester);
      expect(tester.getRect(button), initialButton);
      expect(button.hitTestable(), findsOneWidget);
      expect(tester.getBottomLeft(find.text('M')).dy,
          lessThan(tester.getTopLeft(button).dy));

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(button.hitTestable(), findsOneWidget);
      expect(tester.getBottomLeft(button).dy,
          lessThanOrEqualTo(scenario.size.height - 300));
      expect(tester.takeException(), isNull);
    });
  }


  for (final size in [const Size(390, 844), const Size(1024, 900)]) {
    for (final updating in [false, true]) {
      testWidgets('Floating Save ${updating ? 'updates' : 'creates'} app schedule ($size)', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final app = ManagedApp(
          id: 'editor_app',
          packageName: 'com.editor',
          displayName: 'Editor App',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );
        await repository.addApp(app);
        final original = ScheduleRule(
          id: 'original',
          appId: app.id,
          name: 'Evening',
          enabled: false,
          mode: ScheduleMode.allowDuring,
          startTime: const TimeOfDayValue(hour: 19, minute: 0),
          endTime: const TimeOfDayValue(hour: 21, minute: 0),
          daysOfWeek: {6, 7},
          allowVipContacts: false,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );
        if (updating) {
          await repository.saveRule(original, autoSaveTemplate: false);
        }
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.darkTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ScheduleEditorScreen(
                      repository: repository,
                      targetApp: app,
                      existingRule: updating ? original : null,
                    ),
                  ),
                ),
                child: const Text('Open editor'),
              ),
            ),
          ),
        ));
        await tester.tap(find.text('Open editor'));
        await flushFontsAndSettle(tester);
        final save = find.byKey(const ValueKey('schedule-save-fab'));
        expect(save.hitTestable(), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'Updated name');
        await tester.tap(save);
        await pumpFor(tester, const Duration(milliseconds: 600));

        expect(find.byType(ScheduleEditorScreen), findsNothing);
        final saved = repository.getRulesForApp(app.id).single;
        expect(saved.name, 'Updated name');
        if (updating) {
          expect(saved.id, original.id);
          expect(saved.enabled, isFalse);
          expect(saved.mode, original.mode);
          expect(saved.daysOfWeek, original.daysOfWeek);
          expect(saved.startTime, original.startTime);
          expect(saved.endTime, original.endTime);
          expect(saved.allowVipContacts, isFalse);
          expect(saved.createdAt, original.createdAt);
        } else {
          expect(saved.mode, ScheduleMode.blockDuring);
          expect(saved.daysOfWeek, {1, 2, 3, 4, 5});
          expect(saved.enabled, isTrue);
        }
        await pumpFor(tester, const Duration(seconds: 5));
      });
    }

    testWidgets('Floating Done stays visible and returns without removing app changes ($size)', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final app = ManagedApp(
        id: 'details_app',
        packageName: 'com.details',
        displayName: 'Details App',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      await repository.addApp(app);
      for (var i = 0; i < 12; i++) {
        await repository.saveRule(ScheduleRule(
          id: 'details_rule_$i',
          appId: app.id,
          name: 'Rule $i',
          mode: ScheduleMode.blockDuring,
          startTime: const TimeOfDayValue(hour: 9, minute: 0),
          endTime: const TimeOfDayValue(hour: 17, minute: 0),
          daysOfWeek: {1},
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ), autoSaveTemplate: false);
      }
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AppDetailsScreen(repository: repository, app: app),
                ),
              ),
              child: const Text('Open details'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Open details'));
      await flushFontsAndSettle(tester);
      final done = find.byKey(const ValueKey('app-details-done-fab'));
      expect(done.hitTestable(), findsOneWidget);
      final rect = tester.getRect(done);
      await tester.tap(find.byType(StitchSwitch).first);
      await tester.pumpAndSettle();
      expect(repository.managedApps.single.enabled, isFalse);

      final position = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(tester.getRect(done), rect);
      expect(tester.getBottomLeft(find.text('Remove from Rules Page')).dy,
          lessThan(rect.top));
      await tester.tap(done);
      await flushFontsAndSettle(tester);
      expect(find.byType(AppDetailsScreen), findsNothing);
      expect(find.text('Open details'), findsOneWidget);
      expect(repository.managedApps.single.enabled, isFalse);
      expect(repository.getRulesForApp(app.id), hasLength(12));
    });
  }

  for (final scenario in [
    (name: 'light phone', size: const Size(390, 3600), mode: ThemeMode.light),
    (name: 'dark phone', size: const Size(390, 3600), mode: ThemeMode.dark),
    (name: 'light tablet', size: const Size(1024, 2600), mode: ThemeMode.light),
    (name: 'dark tablet', size: const Size(1024, 2600), mode: ThemeMode.dark),
  ]) {
    testWidgets('Settings Saved Rules can edit and delete templates (${scenario.name})', (WidgetTester tester) async {
      tester.view.physicalSize = scenario.size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await repository.saveRuleTemplate(RuleTemplate(
        id: 'template_wrong',
        name: 'Wrong Rule',
        mode: ScheduleMode.blockDuring,
        startTime: const TimeOfDayValue(hour: 22, minute: 0),
        endTime: const TimeOfDayValue(hour: 23, minute: 0),
        daysOfWeek: const {6, 7},
        createdAt: DateTime.now(),
      ));

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: scenario.mode,
        home: SettingsScreen(repository: repository),
      ));
      await flushFontsAndSettle(tester);

      expect(find.text('SAVED RULES'), findsOneWidget);
      final defaultTile = find.byKey(const ValueKey('saved-rule-template_work_focus'));
      final wrongTile = find.byKey(const ValueKey('saved-rule-template_wrong'));
      expect(find.descendant(of: defaultTile, matching: find.text('DEFAULT')), findsOneWidget);
      expect(find.descendant(of: defaultTile, matching: find.text('Focus Hours')), findsOneWidget);
      expect(find.descendant(of: defaultTile, matching: find.byTooltip('Delete')), findsNothing);
      expect(find.descendant(of: defaultTile, matching: find.byTooltip('Edit')), findsNothing);

      await tester.tap(find.descendant(of: wrongTile, matching: find.byTooltip('Edit')));
      await flushFontsAndSettle(tester);
      expect(find.text('Edit Saved Rule'), findsOneWidget);
      expect(find.text('QUICK LOAD TEMPLATE / SAVED RULE'), findsNothing);
      expect(find.text('RULE NAME'), findsOneWidget);
      expect(find.text('Apps already using this rule keep their current schedule.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Late Weekend');
      final everyday = find.text('Everyday');
      await tester.scrollUntilVisible(everyday, 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(everyday);
      await tester.pump();
      final save = find.byKey(const ValueKey('schedule-save-fab'));
      await tester.tap(save);
      await flushFontsAndSettle(tester);
      expect(find.text('Edit Saved Rule'), findsNothing);
      expect(find.text('Late Weekend'), findsOneWidget);
      final edited = repository.ruleTemplates.firstWhere((t) => t.id == 'template_wrong');
      expect(edited.name, 'Late Weekend');
      expect(edited.daysOfWeek, {1, 2, 3, 4, 5, 6, 7});

      await tester.tap(find.descendant(of: wrongTile, matching: find.byTooltip('Delete')));
      await flushFontsAndSettle(tester);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
      await flushFontsAndSettle(tester);
      expect(wrongTile, findsNothing);
      expect(repository.ruleTemplates.any((t) => t.id == 'template_wrong'), isFalse);
    });
  }


  for (final scenario in [
    (name: 'light phone', size: const Size(390, 844), mode: ThemeMode.light),
    (name: 'dark tablet', size: const Size(1024, 1300), mode: ThemeMode.dark),
  ]) {
    testWidgets('Import summary removes a waiting app only after confirmation (${scenario.name})', (tester) async {
      tester.view.physicalSize = scenario.size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final vaulted = ManagedApp(
        id: 'app_meesho',
        packageName: 'com.meesho',
        displayName: 'Meesho',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        isDormantVault: true,
      );
      await repository.addApp(vaulted);
      final report = ImportReport(
        waiting: [ImportReportApp(app: vaulted, ruleCount: 1)],
      );
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: scenario.mode,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showImportSummarySheet(context, report, repository: repository),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await flushFontsAndSettle(tester);

      final remove = find.byKey(const ValueKey('import-summary-remove-app_meesho'));
      await tester.tap(remove);
      await flushFontsAndSettle(tester);
      expect(find.text('Remove Meesho?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await flushFontsAndSettle(tester);
      expect(remove, findsOneWidget);
      expect(repository.dormantVaultApps.any((a) => a.id == 'app_meesho'), isTrue);

      await tester.tap(remove);
      await flushFontsAndSettle(tester);
      await tester.tap(find.byKey(const ValueKey('import-summary-remove-confirm')));
      await tester.pump();
      await pumpFor(tester, const Duration(milliseconds: 400));
      expect(remove, findsNothing);
      expect(find.byKey(const ValueKey('import-summary-waiting')), findsNothing);
      expect(repository.dormantVaultApps.any((a) => a.id == 'app_meesho'), isFalse);
      expect(find.text('Removed Meesho from the vault'), findsOneWidget);
      await pumpFor(tester, const Duration(seconds: 4));
    });
  }

  for (final scenario in [
    (name: 'light phone', size: const Size(390, 844), mode: ThemeMode.light),
    (name: 'dark tablet', size: const Size(1024, 1300), mode: ThemeMode.dark),
  ]) {
    testWidgets('Settings Dormant Vault card lists vaulted apps and removes after confirmation (${scenario.name})', (tester) async {
      tester.view.physicalSize = scenario.size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await repository.addApp(ManagedApp(
        id: 'app_meesho',
        packageName: 'com.meesho',
        displayName: 'Meesho',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        isDormantVault: true,
      ));
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: scenario.mode,
        home: SettingsScreen(repository: repository),
      ));
      await flushFontsAndSettle(tester);

      final card = find.byKey(const ValueKey('settings-dormant-vault'));
      await tester.ensureVisible(card);
      expect(find.descendant(of: card, matching: find.text('1 APP')), findsOneWidget);
      await tester.tap(card);
      await flushFontsAndSettle(tester);
      expect(find.byKey(const ValueKey('dormant-vault-app_meesho')), findsOneWidget);

      final remove = find.byKey(const ValueKey('import-summary-remove-app_meesho'));
      await tester.tap(remove);
      await flushFontsAndSettle(tester);
      expect(find.text('Remove Meesho?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await flushFontsAndSettle(tester);
      expect(repository.dormantVaultApps, hasLength(1));

      await tester.tap(remove);
      await flushFontsAndSettle(tester);
      await tester.tap(find.byKey(const ValueKey('import-summary-remove-confirm')));
      await tester.pump();
      await pumpFor(tester, const Duration(milliseconds: 400));
      expect(repository.dormantVaultApps, isEmpty);
      expect(find.byKey(const ValueKey('dormant-vault-empty')), findsOneWidget);
      expect(find.text('No uninstalled apps in the vault'), findsOneWidget);
      expect(find.text('Removed Meesho from the vault'), findsOneWidget);
      await pumpFor(tester, const Duration(seconds: 4));

      await tester.tap(find.byKey(const ValueKey('dormant-vault-done')));
      await flushFontsAndSettle(tester);
      expect(find.descendant(of: card, matching: find.text('0 APPS')), findsOneWidget);
      expect(find.textContaining('No uninstalled apps.'), findsOneWidget);
    });
  }

  for (final scenario in [
    (name: 'light phone', size: const Size(390, 844), mode: ThemeMode.light),
    (name: 'dark phone', size: const Size(390, 844), mode: ThemeMode.dark),
    (name: 'light tablet', size: const Size(1024, 1300), mode: ThemeMode.light),
    (name: 'dark tablet', size: const Size(1024, 1300), mode: ThemeMode.dark),
  ]) {
    testWidgets('Settings import shows a progress dialog until the backup is restored (${scenario.name})', (tester) async {
      tester.view.physicalSize = scenario.size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      mockPlatform.installedApps = const [
        DiscoveredAppInfo(packageName: 'com.slack', displayName: 'Slack'),
      ];
      await repository.addApp(ManagedApp(
        id: 'app_import_slack',
        packageName: 'com.slack',
        displayName: 'Slack',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ));
      final backup = repository.exportRulesJson();
      mockPlatform.backupPicker = Completer<String?>();
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: scenario.mode,
        home: SettingsScreen(repository: repository),
      ));
      await flushFontsAndSettle(tester);

      final importButton = find.byKey(const ValueKey('settings-import'));
      await tester.ensureVisible(importButton);
      await tester.tap(importButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Importing backup…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(ImportRulesScreen), findsNothing);

      mockPlatform.backupPicker!.complete(backup);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Importing backup…'), findsNothing);
      expect(find.text('Import complete'), findsOneWidget);
      expect(find.byKey(const ValueKey('import-summary-imported')), findsOneWidget);
      expect(find.text('Backup file restored successfully!'), findsNothing);

      // Sections start expanded; the chevron collapses them.
      final importedSection = find.byKey(const ValueKey('import-summary-imported'));
      const firstApp = 'Slack';
      expect(find.descendant(of: importedSection, matching: find.text(firstApp)), findsOneWidget);
      await tester.tap(find.descendant(of: importedSection, matching: find.text('Imported')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.descendant(of: importedSection, matching: find.text(firstApp)), findsNothing);

      await tester.tap(find.byKey(const ValueKey('import-summary-done')));
      await flushFontsAndSettle(tester);
      expect(find.text('Import complete'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final scenario in [
    (name: 'light phone', size: const Size(390, 4000), mode: ThemeMode.light, tablet: false),
    (name: 'dark phone', size: const Size(390, 4000), mode: ThemeMode.dark, tablet: false),
    (name: 'light tablet', size: const Size(1024, 3000), mode: ThemeMode.light, tablet: true),
    (name: 'dark tablet', size: const Size(1024, 3000), mode: ThemeMode.dark, tablet: true),
  ]) {
    testWidgets('Settings follows the new design and hides tablet-only items on phone (${scenario.name})', (WidgetTester tester) async {
      tester.view.physicalSize = scenario.size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: scenario.mode,
        home: SettingsScreen(repository: repository),
      ));
      await flushFontsAndSettle(tester);

      for (final shared in [
        'Manage Notification Access',
        'RULES BACKUP & PORTABILITY',
        'SAVED RULES',
        'TRIAGE & AUTOMATION PREFERENCES',
        'Keep Unmanaged Apps Untouched',
        'Allow Priority Phone Calls',
        '24-Hour Time Format',
        'ON-DEVICE INTEGRITY & STORAGE',
        'Zero Telemetry Guarantee',
        'View Security & Privacy Audit Report',
      ]) {
        expect(find.text(shared), findsOneWidget, reason: shared);
      }
      expect(find.textContaining('Focus Shield'), findsOneWidget);
      expect(find.text('Engine health, security & preferences'), findsNothing);
      expect(find.text('0.00 B'), findsNothing);
      expect(find.text(scenario.tablet ? 'Encrypted Local Storage' : 'Encrypted Locally'), findsOneWidget);
      expect(find.textContaining('No internet needed. Your data stays on this'), findsOneWidget);

      final tabletOnly = [
        'ENGINE & BACKGROUND SERVICES',
        'Standard Rule Profile',
        'High Bypass',
        'Hardware Keystore',
        'DIAGNOSTICS & SYSTEM METRICS',
        'DANGER ZONE',
        'Licenses',
        'Export Rules Backup',
        'Import Rules Backup',
      ];
      for (final label in tabletOnly) {
        expect(find.text(label), scenario.tablet ? findsWidgets : findsNothing, reason: label);
      }
      expect(find.text('Export Rules'), scenario.tablet ? findsNothing : findsOneWidget);
      expect(find.text('Import Rules'), scenario.tablet ? findsNothing : findsOneWidget);
      expect(find.byKey(const ValueKey('settings-version-footer')), scenario.tablet ? findsNothing : findsOneWidget);
      expect(find.byKey(const ValueKey('settings-check-updates')), scenario.tablet ? findsOneWidget : findsNothing);
      if (!scenario.tablet) {
        final footer = tester.widget<InkWell>(find.byKey(const ValueKey('settings-version-footer')));
        expect(footer.onTap, isNotNull);
      }

      final before = repository.unmanagedAppsUntouched;
      await tester.tap(find.descendant(
        of: find.byKey(const ValueKey('toggle-unmanaged')),
        matching: find.byType(StitchSwitch),
      ));
      await flushFontsAndSettle(tester);
      expect(repository.unmanagedAppsUntouched, !before);
      expect(find.text('CATCH-UP DIGEST'), findsNothing);
    });
  }

  for (final scenario in [
    (name: 'light phone', size: const Size(390, 4000), mode: ThemeMode.light),
    (name: 'dark phone', size: const Size(390, 4000), mode: ThemeMode.dark),
    (name: 'light tablet', size: const Size(1024, 3000), mode: ThemeMode.light),
    (name: 'dark tablet', size: const Size(1024, 3000), mode: ThemeMode.dark),
  ]) {
    testWidgets('Settings catch-up digest toggle asks for notification permission (${scenario.name})', (WidgetTester tester) async {
      tester.view.physicalSize = scenario.size;
      tester.view.devicePixelRatio = 1.0;
      const channel = MethodChannel('com.notificationhandler/bridge');
      var enabled = false;
      var permission = false;
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        switch (call.method) {
          case 'getDigestSettings':
            return {'enabled': enabled, 'permissionGranted': permission};
          case 'setDigestEnabled':
            enabled = (call.arguments as Map)['enabled'] as bool;
            return null;
          case 'requestNotificationPermission':
            return permission;
        }
        return null;
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: scenario.mode,
        home: SettingsScreen(repository: repository),
      ));
      await flushFontsAndSettle(tester);

      expect(find.text('CATCH-UP DIGEST'), findsOneWidget);
      expect(find.text('Notify When Quiet Hours End'), findsOneWidget);
      expect(find.text('NEEDS PERMISSION'), findsNothing);

      final toggle = find.descendant(
        of: find.byKey(const ValueKey('toggle-digest')),
        matching: find.byType(StitchSwitch),
      );
      await tester.tap(toggle);
      await flushFontsAndSettle(tester);
      expect(enabled, isTrue);
      expect(calls, contains('requestNotificationPermission'));
      expect(find.text('NEEDS PERMISSION'), findsOneWidget);
      expect(find.byKey(const ValueKey('settings-digest-allow')), findsOneWidget);

      permission = true;
      await tester.tap(find.byKey(const ValueKey('settings-digest-allow')));
      await flushFontsAndSettle(tester);
      expect(find.text('ALLOWED'), findsOneWidget);
      expect(find.byKey(const ValueKey('settings-digest-allow')), findsNothing);

      calls.clear();
      await tester.tap(toggle);
      await flushFontsAndSettle(tester);
      expect(enabled, isFalse);
      expect(calls, isNot(contains('requestNotificationPermission')));
      expect(find.text('ALLOWED'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  group('Apply rules wizard', () {
    Future<void> seed() async {
      mockPlatform.installedApps = [
        DiscoveredAppInfo(packageName: 'com.slack', displayName: 'Slack'),
        DiscoveredAppInfo(packageName: 'com.mail', displayName: 'Mail'),
      ];
      await repository.addApp(ManagedApp(
        id: 'app_slack',
        packageName: 'com.slack',
        displayName: 'Slack',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ));
    }

    testWidgets('phone: FAB → rules → apps → review → apply, then undo per rule and all',
        (tester) async {
      tester.view.physicalSize = const Size(390, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await seed();

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: DashboardScreen(repository: repository),
      ));
      await flushFontsAndSettle(tester);

      final fab = find.byKey(const ValueKey('rules-apply-fab'));
      expect(fab, findsOneWidget);
      await tester.longPress(find.text('Slack'));
      await flushFontsAndSettle(tester);
      expect(fab, findsNothing, reason: 'hidden during multi-select');
      await tester.tap(find.byKey(const Key('select_all_checkbox')));
      await flushFontsAndSettle(tester);
      expect(fab, findsOneWidget);

      await tester.tap(fab);
      await flushFontsAndSettle(tester);
      expect(find.byType(BulkApplyScreen), findsOneWidget);

      final next = find.byKey(const ValueKey('bulk-next'));
      expect(tester.widget<FilledButton>(next).onPressed, isNull);
      await tester.tap(find.byKey(const ValueKey('bulk-rule-template_work_focus')));
      await tester.pumpAndSettle();
      expect(find.text('Block · 9:00 AM - 5:00 PM · Mon-Fri'), findsOneWidget);
      await tester.tap(next);
      await flushFontsAndSettle(tester);

      await tester.tap(find.byKey(const ValueKey('bulk-select-all')));
      await tester.pumpAndSettle();
      await tester.tap(next);
      await flushFontsAndSettle(tester);

      expect(find.text('1 rule → 2 apps'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('bulk-review-line'))).data,
        '2 new schedules',
      );
      expect(find.text('NEW'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('bulk-apply')));
      await flushFontsAndSettle(tester);

      expect(find.text('Rules applied'), findsOneWidget);
      expect(repository.schedules.length, 2);
      final mail = repository.managedApps.firstWhere((a) => a.packageName == 'com.mail');

      final slackRule = repository.getRulesForApp('app_slack').single;
      await tester.tap(find.byKey(ValueKey('bulk-result-remove-rule-${slackRule.id}')));
      await flushFontsAndSettle(tester);
      expect(find.text('Remove Focus Hours?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('bulk-result-confirm')));
      await pumpFor(tester, const Duration(milliseconds: 600));
      expect(repository.getRulesForApp('app_slack'), isEmpty);
      expect(repository.managedApps.any((a) => a.id == 'app_slack'), isTrue,
          reason: 'pre-existing app is kept');
      expect(find.text('Removed Focus Hours from Slack'), findsOneWidget);
      await pumpFor(tester, const Duration(seconds: 5));

      await tester.tap(find.byKey(const ValueKey('bulk-result-undo-all')));
      await flushFontsAndSettle(tester);
      await tester.tap(find.byKey(const ValueKey('bulk-result-confirm')));
      await pumpFor(tester, const Duration(milliseconds: 600));
      expect(repository.schedules, isEmpty);
      expect(repository.managedApps.any((a) => a.id == mail.id), isFalse,
          reason: 'app added by the batch is removed when empty');
      expect(find.text('Rules applied'), findsNothing);
      await pumpFor(tester, const Duration(seconds: 5));
    });

    testWidgets('step 1: New rule creates a saved rule and selects it', (tester) async {
      tester.view.physicalSize = const Size(390, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await seed();
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: BulkApplyScreen(repository: repository),
      ));
      await flushFontsAndSettle(tester);

      // Same schedule as Focus Hours: offered to use the existing rule.
      await tester.tap(find.byKey(const ValueKey('bulk-new-rule')));
      await flushFontsAndSettle(tester);
      expect(find.text('New Rule'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Copy');
      await tester.tap(find.byKey(const ValueKey('schedule-save-fab')));
      await flushFontsAndSettle(tester);
      await tester.tap(find.text('Use Focus Hours'));
      await pumpFor(tester, const Duration(milliseconds: 600));
      expect(repository.ruleTemplates.length, 1);
      expect(find.text('1 rule selected'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('bulk-new-rule')));
      await flushFontsAndSettle(tester);
      await tester.enterText(find.byType(TextField).first, 'Weekend calm');
      await tester.ensureVisible(find.text('Weekends'));
      await tester.tap(find.text('Weekends'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('schedule-save-fab')));
      await pumpFor(tester, const Duration(milliseconds: 600));

      final created = repository.ruleTemplates.firstWhere((t) => t.name == 'Weekend calm');
      expect(created.daysOfWeek, {6, 7});
      expect(find.byKey(ValueKey('bulk-rule-${created.id}')), findsOneWidget);
      expect(find.text('2 rules selected'), findsOneWidget);
      await pumpFor(tester, const Duration(seconds: 5));
    });

    testWidgets('tablet: panels side by side with review bar Apply', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await seed();

      BulkApplyResult? popped;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                popped = await Navigator.of(context).push<BulkApplyResult>(
                  MaterialPageRoute(
                      builder: (_) => BulkApplyScreen(repository: repository)),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await flushFontsAndSettle(tester);

      expect(find.byKey(const ValueKey('bulk-next')), findsNothing);
      expect(find.text('Choose rules and apps'), findsOneWidget);
      final rule = find.byKey(const ValueKey('bulk-rule-template_work_focus'));
      final app = find.byKey(const ValueKey('bulk-app-com.mail'));
      expect(tester.getCenter(rule).dx, lessThan(tester.getCenter(app).dx));

      await tester.tap(rule);
      await tester.tap(app);
      await tester.pumpAndSettle();
      expect(find.text('1 rule → 1 app'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('bulk-apply')));
      await flushFontsAndSettle(tester);
      expect(popped?.addedCount, 1);
      expect(repository.managedApps.any((a) => a.packageName == 'com.mail'), isTrue);
    });
  });
}
