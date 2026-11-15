import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/repositories/schedule_repository.dart';
import 'presentation/screens/splash_screen.dart';
import 'presentation/theme/app_theme.dart';

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
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final savedTheme = prefs.getString('pref_theme_mode') ?? 'system';
  if (savedTheme == 'light') {
    themeModeNotifier.value = ThemeMode.light;
  } else if (savedTheme == 'dark') {
    themeModeNotifier.value = ThemeMode.dark;
  } else {
    themeModeNotifier.value = ThemeMode.system;
  }

  final repository = ScheduleRepository();

  runApp(NotificationHandlerApp(repository: repository));
}

class NotificationHandlerApp extends StatelessWidget {
  final ScheduleRepository repository;

  const NotificationHandlerApp({super.key, required this.repository});

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
          home: SplashScreen(repository: repository),
        );
      },
    );
  }
}
