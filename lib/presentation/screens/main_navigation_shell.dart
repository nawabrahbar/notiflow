import 'package:flutter/material.dart';
import '../../data/repositories/schedule_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/stitch_header.dart';
import 'activity_screen.dart';
import 'add_apps_screen.dart';
import 'dashboard_screen.dart';
import 'settings_screen.dart';

/// Main navigation shell housing the Stitch 4-tab bottom navigation:
/// 1. Rules (Dashboard)
/// 2. Apps (Manage Notification Flow)
/// 3. Activity (Event log)
/// 4. Settings
class MainNavigationShell extends StatefulWidget {
  final ScheduleRepository repository;
  final int initialIndex;
  final bool showRestorationBanner;

  const MainNavigationShell({
    super.key,
    required this.repository,
    this.initialIndex = 0,
    this.showRestorationBanner = false,
  });

  static MainNavigationShellState? of(BuildContext context) =>
      context.findAncestorStateOfType<MainNavigationShellState>();

  @override
  State<MainNavigationShell> createState() => MainNavigationShellState();
}

class MainNavigationShellState extends State<MainNavigationShell> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void switchTab(int index) {
    if (index >= 0 && index < 4) {
      setState(() => _currentIndex = index);
    }
  }

  String _getTitle() {
    switch (_currentIndex) {
      case 0:
        return 'Notiflow';
      case 1:
        return 'Add Apps';
      case 2:
        return 'Activity Log';
      case 3:
        return 'Settings';
      default:
        return 'Notiflow';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: StitchHeader(
        title: _getTitle(),
        onProfileTap: () => switchTab(3),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          DashboardScreen(
            repository: widget.repository,
            onAddAppTap: () => switchTab(1),
            initialShowRestorationBanner: widget.showRestorationBanner,
          ),
          AddAppsScreen(repository: widget.repository, isEmbedded: true),
          ActivityScreen(repository: widget.repository, isEmbedded: true),
          SettingsScreen(repository: widget.repository),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.darkSurface
              : Colors.white,
          border: const Border(
            top: BorderSide(color: AppTheme.outlineVariant, width: 0.8),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              offset: const Offset(0, -2),
              blurRadius: 10,
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: AppTheme.primaryTeal,
          unselectedItemColor: AppTheme.onSurfaceVariant,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.tune_rounded),
              label: 'Rules',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.apps_rounded),
              label: 'Apps',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_toggle_off_rounded),
              label: 'Activity',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
