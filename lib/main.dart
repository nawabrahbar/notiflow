import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/repositories/schedule_repository.dart';
import 'platform/android_notification_platform.dart';
import 'platform/platform_factory.dart';
import 'presentation/screens/main_navigation_shell.dart';
import 'presentation/screens/onboarding_screen.dart';
import 'presentation/screens/permission_screen.dart';
import 'presentation/theme/app_theme.dart';
import 'presentation/widgets/app_toast.dart';

/// App-wide theme mode controller for real-time switching between
/// System, Light Mode, and Dark Mode.
final ValueNotifier<ThemeMode> themeModeNotifier =
    ValueNotifier<ThemeMode>(ThemeMode.system);

Future<void> updateAppThemeMode(ThemeMode mode) async {
  themeModeNotifier.value = mode;
  final prefs = await SharedPreferences.getInstance();
  final String key;
  switch (mode) {
    case ThemeMode.light:
      key = 'light';
      break;
    case ThemeMode.dark:
      key = 'dark';
      break;
    case ThemeMode.system:
      key = 'system';
      break;
  }
  await prefs.setString('pref_theme_mode', key);
  await AndroidNotificationPlatform.setAppThemeMode(key);
}

/// Phones (shortest side under 600dp) stay in portrait; tablets may rotate.
List<DeviceOrientation> allowedOrientations(double shortestSideDp) {
  if (shortestSideDp > 0 && shortestSideDp < 600) {
    return const [DeviceOrientation.portraitUp];
  }
  return DeviceOrientation.values;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final display = PlatformDispatcher.instance.displays.firstOrNull;
  if (display != null) {
    final logical = display.size / display.devicePixelRatio;
    unawaited(
      SystemChrome.setPreferredOrientations(
        allowedOrientations(logical.shortestSide),
      ).catchError((Object error, StackTrace stackTrace) {
        debugPrint('Could not set startup orientation: $error');
      }),
    );
  }
  GoogleFonts.config.allowRuntimeFetching = false;

  final prefs = await SharedPreferences.getInstance();
  final savedTheme = prefs.getString('pref_theme_mode') ?? 'system';
  if (savedTheme == 'light') {
    themeModeNotifier.value = ThemeMode.light;
  } else if (savedTheme == 'dark') {
    themeModeNotifier.value = ThemeMode.dark;
  } else {
    themeModeNotifier.value = ThemeMode.system;
  }
  unawaited(AndroidNotificationPlatform.setAppThemeMode(savedTheme));

  final repository = ScheduleRepository();
  final homeFuture = resolveStartScreen(repository, prefs);
  await repository.initialize(deferStartupMaintenance: true);
  final home = await homeFuture;

  runApp(NotificationHandlerApp(repository: repository, home: home));
}

/// Picks the first screen directly, with no intermediate splash screen.
Future<Widget> resolveStartScreen(
  ScheduleRepository repository,
  SharedPreferences prefs,
) async {
  if (!(prefs.getBool('pref_onboarding_completed') ?? false)) {
    return OnboardingScreen(repository: repository);
  }
  final isGranted =
      await PlatformFactory.createPlatformService().isNotificationAccessGranted();
  if (!isGranted) {
    return PermissionScreen(repository: repository, isInitialSetup: false);
  }
  return MainNavigationShell(repository: repository);
}

class NotificationHandlerApp extends StatelessWidget {
  final ScheduleRepository repository;
  final Widget home;

  const NotificationHandlerApp({
    super.key,
    required this.repository,
    required this.home,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: 'Notiflow',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentMode,
          home: home,
          builder: (context, child) => AppToastHost(child: child!),
        );
      },
    );
  }
}
