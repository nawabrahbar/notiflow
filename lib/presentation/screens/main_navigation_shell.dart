import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/repositories/schedule_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/stitch_header.dart';
import 'activity_screen.dart';
import 'add_apps_screen.dart';
import 'dashboard_screen.dart';
import 'settings_screen.dart';

/// Main navigation shell housing responsive navigation:
/// - Tablet (>= 600dp): Left persistent Navigation Rail (w-22 / 88dp)
/// - Phone (< 600dp): Bottom Navigation Bar
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
  final GlobalKey<ActivityScreenState> _activityKey =
      GlobalKey<ActivityScreenState>();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void switchTab(int index) {
    if (index >= 0 && index < 4) {
      setState(() => _currentIndex = index);
      if (index == 2) {
        _activityKey.currentState?.refreshLogs();
      }
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkBackground : AppTheme.lightBackground;
    final railBg = isDark
        ? AppTheme.darkSurfaceContainerLow
        : AppTheme.lightSurfaceContainerLow;
    final borderCol = isDark
        ? AppTheme.darkOutlineVariant.withOpacity(0.3)
        : AppTheme.lightOutlineVariant.withOpacity(0.35);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth >= 600;

        final screens = [
          DashboardScreen(
            repository: widget.repository,
            onAddAppTap: () => switchTab(1),
            initialShowRestorationBanner: widget.showRestorationBanner,
          ),
          AddAppsScreen(repository: widget.repository, isEmbedded: true),
          ActivityScreen(
            key: _activityKey,
            repository: widget.repository,
            isEmbedded: true,
          ),
          SettingsScreen(repository: widget.repository),
        ];

        if (isTablet) {
          return Scaffold(
            backgroundColor: bg,
            body: Row(
              children: [
                // Persistent Left Navigation Rail (Tablet Mode)
                Container(
                  width: 88,
                  decoration: BoxDecoration(
                    color: railBg,
                    border: Border(
                      right: BorderSide(color: borderCol, width: 1.0),
                    ),
                  ),
                  child: SafeArea(
                    right: false,
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        // Top Emblem Medallion
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black
                                    .withOpacity(isDark ? 0.3 : 0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              'assets/icon/app_icon.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Navigation Destinations
                        _TabletNavRailItem(
                          icon: Icons.tune_rounded,
                          label: 'Rules',
                          isSelected: _currentIndex == 0,
                          onTap: () => switchTab(0),
                        ),
                        const SizedBox(height: 12),
                        _TabletNavRailItem(
                          icon: Icons.apps_rounded,
                          label: 'Apps',
                          isSelected: _currentIndex == 1,
                          onTap: () => switchTab(1),
                        ),
                        const SizedBox(height: 12),
                        _TabletNavRailItem(
                          icon: Icons.notifications_active_rounded,
                          label: 'Activity',
                          isSelected: _currentIndex == 2,
                          onTap: () => switchTab(2),
                        ),
                        const SizedBox(height: 12),
                        _TabletNavRailItem(
                          icon: Icons.settings_rounded,
                          label: 'Settings',
                          isSelected: _currentIndex == 3,
                          onTap: () => switchTab(3),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),

                // Main Content Area with Seamless Header
                Expanded(
                  child: Column(
                    children: [
                      StitchHeader(
                        title: _getTitle(),
                        showEmblem: false,
                        onProfileTap: () => switchTab(3),
                      ),
                      Expanded(
                        child: IndexedStack(
                          index: _currentIndex,
                          children: screens,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        // Phone Layout (< 600dp)
        return Scaffold(
          backgroundColor: bg,
          appBar: StitchHeader(
            title: _getTitle(),
            showEmblem: true,
            onProfileTap: () => switchTab(3),
          ),
          body: IndexedStack(
            index: _currentIndex,
            children: screens,
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.darkSurfaceContainerLow
                  : AppTheme.lightSurfaceContainerLow,
              border: Border(
                top: BorderSide(color: borderCol, width: 1.0),
              ),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 64,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _PhoneBottomNavItem(
                      icon: Icons.tune_rounded,
                      label: 'Rules',
                      isSelected: _currentIndex == 0,
                      onTap: () => switchTab(0),
                    ),
                    _PhoneBottomNavItem(
                      icon: Icons.apps_rounded,
                      label: 'Apps',
                      isSelected: _currentIndex == 1,
                      onTap: () => switchTab(1),
                    ),
                    _PhoneBottomNavItem(
                      icon: Icons.notifications_active_rounded,
                      label: 'Activity',
                      isSelected: _currentIndex == 2,
                      onTap: () => switchTab(2),
                    ),
                    _PhoneBottomNavItem(
                      icon: Icons.settings_rounded,
                      label: 'Settings',
                      isSelected: _currentIndex == 3,
                      onTap: () => switchTab(3),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TabletNavRailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabletNavRailItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedBg = isDark
        ? AppTheme.darkSecondaryContainer
        : AppTheme.lightSecondaryContainer;
    final selectedText = isDark
        ? AppTheme.darkOnSecondaryContainer
        : AppTheme.lightOnSecondaryContainer;
    final unselectedText = isDark
        ? AppTheme.darkOnSurfaceVariant
        : AppTheme.lightOnSurfaceVariant;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 70,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? selectedBg : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: isSelected
              ? Border.all(
                  color: (isDark
                          ? AppTheme.darkSecondary
                          : AppTheme.lightSecondary)
                      .withOpacity(0.2),
                  width: 1.0,
                )
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? selectedText : unselectedText,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? selectedText : unselectedText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhoneBottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PhoneBottomNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedBg = isDark
        ? AppTheme.darkSecondaryContainer
        : AppTheme.lightSecondaryContainer;
    final selectedText = isDark
        ? AppTheme.darkOnSecondaryContainer
        : AppTheme.lightOnSecondaryContainer;
    final unselectedText = isDark
        ? AppTheme.darkOnSurfaceVariant
        : AppTheme.lightOnSurfaceVariant;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected ? selectedBg : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              size: 22,
              color: isSelected ? selectedText : unselectedText,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? selectedText : unselectedText,
            ),
          ),
        ],
      ),
    );
  }
}
