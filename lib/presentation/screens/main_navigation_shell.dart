import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/repositories/schedule_repository.dart';
import '../../data/services/installed_apps_cache.dart';
import '../theme/app_theme.dart';
import '../widgets/app_toast.dart';
import '../widgets/stitch_header.dart';
import 'activity_screen.dart';
import 'add_apps_screen.dart';
import 'dashboard_screen.dart';
import 'settings_screen.dart';
import '../../platform/android_notification_platform.dart';

/// Main navigation shell housing responsive navigation:
/// - Tablet (>= 600dp): Left persistent Navigation Rail (w-22 / 88dp)
/// - Phone (< 600dp): Bottom Navigation Bar
/// Both show Dashboard, Rules, Activity and Settings. Add Apps opens as its own
/// page from the Rules tab.
class MainNavigationShell extends StatefulWidget {
  static const int dashboardTab = 0;
  static const int rulesTab = 1;
  static const int activityTab = 2;
  static const int settingsTab = 3;

  final ScheduleRepository repository;
  final int initialIndex;
  final bool showRestorationBanner;

  const MainNavigationShell({
    super.key,
    required this.repository,
    this.initialIndex = dashboardTab,
    this.showRestorationBanner = false,
  });

  static MainNavigationShellState? of(BuildContext context) =>
      context.findAncestorStateOfType<MainNavigationShellState>();

  @override
  State<MainNavigationShell> createState() => MainNavigationShellState();
}

class MainNavigationShellState extends State<MainNavigationShell>
    with WidgetsBindingObserver {
  late int _currentIndex;
  final GlobalKey<ActivityScreenState> _activityKey =
      GlobalKey<ActivityScreenState>();
  final GlobalKey<DashboardScreenState> _dashboardKey =
      GlobalKey<DashboardScreenState>();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    AndroidNotificationPlatform.addOpenDigestListener(_onOpenDigest);
    WidgetsBinding.instance.addObserver(this);
    widget.repository.addListener(_checkManagedAppsInstalled);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Load the shared app list in the background once the dashboard is visible.
      _warmInstalledApps();
      _startupChecks();
    });
  }

  @override
  void dispose() {
    AndroidNotificationPlatform.removeOpenDigestListener(_onOpenDigest);
    WidgetsBinding.instance.removeObserver(this);
    widget.repository.removeListener(_checkManagedAppsInstalled);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      InstalledAppsCache.instance.refreshChanges().then(
        (_) => _checkManagedAppsInstalled(force: true),
      );
    }
  }

  Future<void> _warmInstalledApps() async {
    await InstalledAppsCache.instance.ensureLoaded();
    await _checkManagedAppsInstalled();
  }

  Future<void> _checkManagedAppsInstalled({bool force = false}) =>
      InstalledAppsCache.instance.checkInstalled(
        widget.repository.managedApps.map((a) => a.packageName),
        force: force,
      );

  Future<void> _startupChecks() async {
    await _onOpenDigest();
    if (!mounted) return;
    await AndroidNotificationPlatform.requestNotificationPermissionOnStartup();
  }

  Future<void> _onOpenDigest() async {
    final pending =
        await AndroidNotificationPlatform.consumePendingDigestOpen();
    if (!pending || !mounted) return;
    openDigest();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _activityKey.currentState?.showDigest();
    });
  }

  void switchTab(int index) {
    if (index >= 0 && index <= MainNavigationShell.settingsTab) {
      setState(() => _currentIndex = index);
      if (index == MainNavigationShell.activityTab) {
        _activityKey.currentState?.refreshLogs();
      } else if (index == MainNavigationShell.dashboardTab) {
        _dashboardKey.currentState?.refreshDigest();
      }
    }
  }

  void _openAddApps() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddAppsScreen(repository: widget.repository),
      ),
    );
  }

  /// Opens the Activity tab with the Digest filter selected.
  void openDigest() {
    switchTab(MainNavigationShell.activityTab);
    _activityKey.currentState?.showDigest();
  }

  String _getTitle() {
    switch (_currentIndex) {
      case MainNavigationShell.dashboardTab:
        return 'Notiflow';
      case MainNavigationShell.rulesTab:
        return 'Rules';
      case MainNavigationShell.activityTab:
        return 'Activity Log';
      case MainNavigationShell.settingsTab:
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
            key: _dashboardKey,
            repository: widget.repository,
            view: DashboardView.home,
            onOpenDigest: openDigest,
            initialShowRestorationBanner: widget.showRestorationBanner,
          ),
          DashboardScreen(
            repository: widget.repository,
            view: DashboardView.rules,
            onAddAppTap: _openAddApps,
          ),
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
                                color: Colors.black.withOpacity(
                                  isDark ? 0.3 : 0.06,
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              isDark
                                  ? 'assets/icon/app_icon.png'
                                  : 'assets/icon/app_icon_light.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Navigation Destinations
                        _TabletNavRailItem(
                          icon: Icons.dashboard_outlined,
                          label: 'Dashboard',
                          isSelected:
                              _currentIndex == MainNavigationShell.dashboardTab,
                          onTap: () =>
                              switchTab(MainNavigationShell.dashboardTab),
                        ),
                        const SizedBox(height: 12),
                        _TabletNavRailItem(
                          icon: Icons.tune,
                          label: 'Rules',
                          isSelected:
                              _currentIndex == MainNavigationShell.rulesTab,
                          onTap: () => switchTab(MainNavigationShell.rulesTab),
                        ),
                        const SizedBox(height: 12),
                        _TabletNavRailItem(
                          icon: Icons.notifications_active_outlined,
                          label: 'Activity',
                          isSelected:
                              _currentIndex == MainNavigationShell.activityTab,
                          onTap: () =>
                              switchTab(MainNavigationShell.activityTab),
                        ),
                        const SizedBox(height: 12),
                        _TabletNavRailItem(
                          icon: Icons.settings_outlined,
                          label: 'Settings',
                          isSelected:
                              _currentIndex == MainNavigationShell.settingsTab,
                          onTap: () =>
                              switchTab(MainNavigationShell.settingsTab),
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
                      StitchHeader(title: _getTitle(), showEmblem: false),
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
        return PopScope(
          canPop: _currentIndex == MainNavigationShell.dashboardTab,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) switchTab(MainNavigationShell.dashboardTab);
          },
          child: Scaffold(
            backgroundColor: bg,
            appBar: StitchHeader(title: _getTitle(), showEmblem: false),
            body: IndexedStack(index: _currentIndex, children: screens),
            bottomNavigationBar: AppToastBottomBar(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F1312).withOpacity(0.9)
                      : AppTheme.lightSurface.withOpacity(0.9),
                  border: isDark
                      ? Border(
                          top: BorderSide(
                            color: const Color(0xFF2A362F).withOpacity(0.7),
                            width: 1.0,
                          ),
                        )
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withOpacity(0.5)
                          : const Color(0xFF2C2A29).withOpacity(0.05),
                      blurRadius: isDark ? 16 : 12,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    height: 64,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          _PhoneBottomNavItem(
                            svg: _NavSvgIcons.dashboard,
                            label: 'Dashboard',
                            isSelected:
                                _currentIndex ==
                                MainNavigationShell.dashboardTab,
                            onTap: () =>
                                switchTab(MainNavigationShell.dashboardTab),
                          ),
                          _PhoneBottomNavItem(
                            svg: _NavSvgIcons.rules,
                            label: 'Rules',
                            isSelected:
                                _currentIndex == MainNavigationShell.rulesTab,
                            onTap: () =>
                                switchTab(MainNavigationShell.rulesTab),
                          ),
                          _PhoneBottomNavItem(
                            svg: _NavSvgIcons.activity,
                            label: 'Activity',
                            isSelected:
                                _currentIndex ==
                                MainNavigationShell.activityTab,
                            onTap: () =>
                                switchTab(MainNavigationShell.activityTab),
                          ),
                          _PhoneBottomNavItem(
                            svg: _NavSvgIcons.settings,
                            label: 'Settings',
                            isSelected:
                                _currentIndex ==
                                MainNavigationShell.settingsTab,
                            onTap: () =>
                                switchTab(MainNavigationShell.settingsTab),
                          ),
                        ],
                      ),
                    ),
                  ),
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
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? selectedBg : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: isSelected
              ? Border.all(
                  color:
                      (isDark
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
              size: 24,
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

class _NavSvgIcons {
  static const _open =
      '<svg viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">';

  static const rules =
      '$_open'
      '<line x1="4" x2="4" y1="21" y2="14"/><line x1="4" x2="4" y1="10" y2="3"/>'
      '<line x1="12" x2="12" y1="21" y2="12"/><line x1="12" x2="12" y1="8" y2="3"/>'
      '<line x1="20" x2="20" y1="21" y2="16"/><line x1="20" x2="20" y1="12" y2="3"/>'
      '<line x1="1" x2="7" y1="14" y2="14"/><line x1="9" x2="15" y1="8" y2="8"/>'
      '<line x1="17" x2="23" y1="16" y2="16"/></svg>';

  static const activity = '$_open<path d="M22 12h-4l-3 9L9 3l-3 9H2"/></svg>';

  static const dashboard =
      '$_open'
      '<rect width="7" height="9" x="3" y="3" rx="1"/><rect width="7" height="5" x="14" y="3" rx="1"/>'
      '<rect width="7" height="9" x="14" y="12" rx="1"/><rect width="7" height="5" x="3" y="16" rx="1"/></svg>';

  static const settings =
      '$_open<circle cx="12" cy="12" r="3"/>'
      '<path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"/></svg>';
}

class _PhoneBottomNavItem extends StatelessWidget {
  final String svg;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PhoneBottomNavItem({
    required this.svg,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedColor = isDark
        ? AppTheme.darkPrimaryContainer
        : AppTheme.lightPrimaryContainer;
    final unselectedColor = isDark
        ? const Color(0xFF9AA79B)
        : AppTheme.lightOnSurfaceVariant;
    final color = isSelected ? selectedColor : unselectedColor;

    return Expanded(
      child: Semantics(
        selected: isSelected,
        button: true,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.string(
                    svg,
                    width: 20,
                    height: 20,
                    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      height: 16 / 11,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
