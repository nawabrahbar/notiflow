import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/repositories/schedule_repository.dart';
import '../../domain/models/managed_app.dart';
import '../../domain/models/schedule_rule.dart';
import '../../platform/notification_platform_interface.dart';
import '../../platform/platform_factory.dart';
import '../theme/app_theme.dart';
import '../widgets/stitch_switch.dart';
import 'add_apps_screen.dart';
import 'app_details_screen.dart';
import 'permission_screen.dart';

/// Dashboard Screen (Rules Page) adhering strictly to Botanical Sanctuary / Nocturne design:
/// - Responsive layout: Single column on phone (< 600dp), 2-Column Bento Split (5 : 7) on tablet (>= 600dp)
/// - Editorial Greeting card with Newsreader serif typography and curated quotes
/// - Bento metrics (Intercepted & Permitted)
/// - Quick Overrides panel (15m, 1h, and call bypass info pill)
/// - Managed Apps catalog with real native app icons from PackageManager
class DashboardScreen extends StatefulWidget {
  final ScheduleRepository repository;
  final VoidCallback? onAddAppTap;
  final bool initialShowRestorationBanner;

  const DashboardScreen({
    super.key,
    required this.repository,
    this.onAddAppTap,
    this.initialShowRestorationBanner = false,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  late final NotificationPlatformInterface _platform;
  bool _isPermissionGranted = true;
  late bool _showRestorationBanner;
  final Set<String> _selectedAppIds = <String>{};

  @override
  void initState() {
    super.initState();
    _showRestorationBanner = widget.initialShowRestorationBanner;
    WidgetsBinding.instance.addObserver(this);
    _platform = PlatformFactory.createPlatformService();
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermission();
    }
  }

  Future<void> _checkPermission() async {
    final granted = await _platform.isNotificationAccessGranted();
    if (mounted) {
      setState(() => _isPermissionGranted = granted);
    }
  }

  String _getTimeBasedQuote() {
    final hour = DateTime.now().hour;
    final minute = DateTime.now().minute;
    if (hour >= 5 && hour < 12) {
      const morningQuotes = [
        'Guard your attention — clarity lives in the quiet.',
        'Begin your day with purpose; let silence shape your thoughts.',
        'A calm morning sets the tone for a deliberate day.',
      ];
      return morningQuotes[(minute ~/ 10) % morningQuotes.length];
    } else if (hour >= 12 && hour < 17) {
      const afternoonQuotes = [
        'Deep focus is a superpower in a world full of noise.',
        'Where your attention flows, your life grows.',
        'Distraction is the enemy of craft and deep work.',
      ];
      return afternoonQuotes[(minute ~/ 10) % afternoonQuotes.length];
    } else if (hour >= 17 && hour < 21) {
      const eveningQuotes = [
        'Disconnect to reconnect with what truly matters tonight.',
        'Leave the day\'s chatter behind and reclaim your peace.',
        'Quiet moments in the evening replenish the creative soul.',
      ];
      return eveningQuotes[(minute ~/ 10) % eveningQuotes.length];
    } else {
      const nightQuotes = [
        'Rest is sacred. Let the world wait until tomorrow.',
      ];
      return nightQuotes[0];
    }
  }

  ({String text, IconData icon, String sessionTag}) _getGreetingData() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return (
        text: 'Good morning',
        icon: Icons.light_mode_rounded,
        sessionTag: 'Botanical Calm · Morning Session',
      );
    } else if (hour >= 12 && hour < 17) {
      return (
        text: 'Good afternoon',
        icon: Icons.wb_sunny_rounded,
        sessionTag: 'Botanical Calm · Afternoon Session',
      );
    } else if (hour >= 17 && hour < 21) {
      return (
        text: 'Good evening',
        icon: Icons.bedtime_rounded,
        sessionTag: 'Botanical Calm · Evening Session',
      );
    } else {
      return (
        text: 'Good night',
        icon: Icons.nights_stay_rounded,
        sessionTag: 'Botanical Calm · Night Session',
      );
    }
  }

  IconData _getDefaultIconForApp(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('chat') ||
        lower.contains('whatsapp') ||
        lower.contains('telegram') ||
        lower.contains('message')) {
      return Icons.chat_bubble_rounded;
    }
    if (lower.contains('slack') ||
        lower.contains('team') ||
        lower.contains('meet')) {
      return Icons.workspaces_rounded;
    }
    if (lower.contains('mail') ||
        lower.contains('gmail') ||
        lower.contains('outlook')) {
      return Icons.mail_rounded;
    }
    if (lower.contains('insta') ||
        lower.contains('photo') ||
        lower.contains('camera')) {
      return Icons.photo_camera_rounded;
    }
    if (lower.contains('tweet') ||
        lower.contains('twitter') ||
        lower.contains('x')) {
      return Icons.tag_rounded;
    }
    return Icons.widgets_rounded;
  }

  Future<void> _deleteSelectedApps() async {
    final count = _selectedAppIds.length;
    if (count == 0) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark
              ? AppTheme.darkSurfaceContainerLow
              : AppTheme.lightSurfaceContainerLow,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Remove $count ${count == 1 ? 'App' : 'Apps'}?',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              color: isDark ? AppTheme.darkOnSurface : AppTheme.lightOnSurface,
            ),
          ),
          content: Text(
            'This will stop monitoring the selected ${count == 1 ? 'app' : 'apps'} and remove associated schedule rules from the Rules Page.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: isDark
                  ? AppTheme.darkOnSurfaceVariant
                  : AppTheme.lightOnSurfaceVariant,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? AppTheme.darkError : AppTheme.lightError,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      final ids = _selectedAppIds.toList();
      await widget.repository.deleteAppsAndRules(ids);
      setState(() => _selectedAppIds.clear());
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Removed $count apps from Rules page'),
              backgroundColor: AppTheme.toastWarning,
            ),
          );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkBackground : AppTheme.lightBackground;
    final container = isDark
        ? AppTheme.darkSurfaceContainer
        : AppTheme.lightSurfaceContainer;
    final containerLow = isDark
        ? AppTheme.darkSurfaceContainerLow
        : AppTheme.lightSurfaceContainerLow;
    final containerHigh = isDark
        ? AppTheme.darkSurfaceContainerHigh
        : AppTheme.lightSurfaceContainerHigh;
    final borderCol = isDark
        ? AppTheme.darkOutlineVariant.withOpacity(0.3)
        : AppTheme.lightOutlineVariant.withOpacity(0.35);
    final textMain = isDark ? AppTheme.darkOnSurface : AppTheme.lightOnSurface;
    final textMuted = isDark
        ? AppTheme.darkOnSurfaceVariant
        : AppTheme.lightOnSurfaceVariant;
    final primary = isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary;
    final secondary = isDark ? AppTheme.darkSecondary : AppTheme.lightSecondary;
    final secContainer = isDark
        ? AppTheme.darkSecondaryContainer
        : AppTheme.lightSecondaryContainer;
    final onSecContainer = isDark
        ? AppTheme.darkOnSecondaryContainer
        : AppTheme.lightOnSecondaryContainer;

    return ListenableBuilder(
      listenable: widget.repository,
      builder: (context, _) {
        final apps = widget.repository.managedApps;
        final summary = widget.repository.getSummary();
        final overrides = widget.repository.overrides;
        final activeOverride = overrides.isNotEmpty ? overrides.first : null;
        final greeting = _getGreetingData();

        return Scaffold(
          backgroundColor: bg,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isTablet = constraints.maxWidth >= 600;

                // LEFT PANEL WIDGET (Greeting + Metrics + Overrides)
                final leftColumnContent = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Restoration Banner (if access restored)
                    if (_showRestorationBanner) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: secContainer.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: secondary.withOpacity(0.4)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_rounded,
                                color: secondary, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Focus Shield Active',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: textMain,
                                    ),
                                  ),
                                  Text(
                                    'IPC Access Connected',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: secondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () => setState(
                                  () => _showRestorationBanner = false),
                              child: const Text('Dismiss'),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Permission Recovery Banner (if access lost)
                    if (!_isPermissionGranted) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF2E1A11)
                              : const Color(0xFFFFF1EB),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: primary.withOpacity(0.5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.warning_amber_rounded,
                                    color: primary, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Notification Access Required',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: textMain,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Schedules are paused until Android Notification Access is reconnected.',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12, color: textMuted),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primary,
                                  foregroundColor: isDark
                                      ? AppTheme.darkOnPrimary
                                      : AppTheme.lightOnPrimary,
                                ),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => PermissionScreen(
                                        repository: widget.repository,
                                        isInitialSetup: false,
                                      ),
                                    ),
                                  );
                                },
                                child: const Text('Reconnect Access'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Sanctuary Editorial Greeting Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: containerLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderCol, width: 1.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(greeting.icon, size: 22, color: primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  greeting.sessionTag,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: textMuted,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            greeting.text,
                            style: GoogleFonts.newsreader(
                              fontSize: isTablet ? 32 : 28,
                              fontWeight: FontWeight.w600,
                              color: textMain,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _getTimeBasedQuote(),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.5,
                              color: textMuted,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Key Metrics (Stacked Bento Split)
                    Row(
                      children: [
                        // Intercepted (Muted)
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: container,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: borderCol, width: 1.0),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: containerHigh,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.notifications_off_rounded,
                                          size: 18, color: textMuted),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: primary.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: primary.withOpacity(0.2)),
                                      ),
                                      child: Text(
                                        'MUTED',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: primary,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  '${summary.interceptedCount}',
                                  style: GoogleFonts.newsreader(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w600,
                                    color: textMain,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Intercepted',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Permitted (Alerts)
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: container,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: borderCol, width: 1.0),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: secContainer,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                          Icons.notifications_active_rounded,
                                          size: 18,
                                          color: onSecContainer),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: secContainer,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: secondary.withOpacity(0.2)),
                                      ),
                                      child: Text(
                                        'ALERTS',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: onSecContainer,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  '${summary.permittedCount}',
                                  style: GoogleFonts.newsreader(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w600,
                                    color: textMain,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Permitted',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Quick Session Overrides Panel
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: containerLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderCol, width: 1.0),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'OVERRIDES',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.0,
                                      color: textMuted,
                                    ),
                                  ),
                                  Text(
                                    'Tap to engage',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: textMain,
                                    ),
                                  ),
                                ],
                              ),
                              Icon(Icons.touch_app_outlined,
                                  size: 18, color: textMuted),
                            ],
                          ),
                          const SizedBox(height: 12),

                          if (activeOverride != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: primary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: primary),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.hourglass_top_rounded,
                                      color: primary, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Mute All Active (${activeOverride.remainingMinutes}m left)',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: textMain,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => widget.repository
                                        .clearOverride(activeOverride.appId),
                                    style: TextButton.styleFrom(
                                      foregroundColor: primary,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                    ),
                                    child: const Text('Restore'),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      widget.repository.setTemporaryMute(
                                        appId: 'global_mute',
                                        duration: const Duration(minutes: 15),
                                      );
                                    },
                                    icon: Icon(Icons.hourglass_top_rounded,
                                        size: 16, color: primary),
                                    label: Text(
                                      'Mute All (15m)',
                                      style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: textMain),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: container,
                                      side: BorderSide(color: borderCol),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      widget.repository.setTemporaryMute(
                                        appId: 'global_mute',
                                        duration: const Duration(hours: 1),
                                      );
                                    },
                                    icon: Icon(Icons.bedtime_rounded,
                                        size: 16, color: primary),
                                    label: Text(
                                      'Mute All (1h)',
                                      style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: textMain),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: container,
                                      side: BorderSide(color: borderCol),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 10),

                          // Permitted exception pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: secContainer.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: secondary.withOpacity(0.2)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.call_rounded,
                                    size: 16, color: onSecContainer),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Phone calls allowed unconditionally',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                      color: onSecContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );

                // RIGHT PANEL WIDGET (Managed Apps List)
                final rightColumnContent = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Selection Action Bar (when multiselect active)
                    if (_selectedAppIds.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: primary.withOpacity(0.5)),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.close_rounded,
                                  size: 20, color: textMain),
                              onPressed: () =>
                                  setState(() => _selectedAppIds.clear()),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${_selectedAppIds.length} Selected',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: textMain,
                              ),
                            ),
                            const Spacer(),
                            ElevatedButton.icon(
                              onPressed: _deleteSelectedApps,
                              icon: const Icon(Icons.delete_outline_rounded,
                                  size: 16),
                              label: const Text('Delete'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark
                                    ? AppTheme.darkError
                                    : AppTheme.lightError,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Managed Apps Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              'MANAGED APPS',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.0,
                                color: textMuted,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: secContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${apps.length}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: onSecContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: widget.onAddAppTap ??
                              () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => AddAppsScreen(
                                        repository: widget.repository),
                                  ),
                                );
                              },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: secContainer,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_rounded,
                                    size: 16, color: onSecContainer),
                                const SizedBox(width: 4),
                                Text(
                                  'Add App',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: onSecContainer,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Managed Apps Cards
                    if (apps.isEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 36, horizontal: 20),
                        decoration: BoxDecoration(
                          color: containerLow,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderCol),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.schedule_rounded,
                                size: 40, color: textMuted),
                            const SizedBox(height: 12),
                            Text(
                              'No apps managed yet',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: textMain,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Select installed apps to apply quiet schedules and silence distractions.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13, color: textMuted),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('Add Apps'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primary,
                                foregroundColor: isDark
                                    ? AppTheme.darkOnPrimary
                                    : AppTheme.lightOnPrimary,
                              ),
                              onPressed: widget.onAddAppTap ??
                                  () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => AddAppsScreen(
                                            repository: widget.repository),
                                      ),
                                    );
                                  },
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      ...apps.map((app) {
                        return _buildManagedAppCard(
                          context,
                          app: app,
                          isDark: isDark,
                          container: container,
                          containerHigh: containerHigh,
                          borderCol: borderCol,
                          textMain: textMain,
                          textMuted: textMuted,
                          primary: primary,
                          secondary: secondary,
                          secContainer: secContainer,
                          onSecContainer: onSecContainer,
                        );
                      }),
                    ],
                  ],
                );

                if (isTablet) {
                  // Tablet Mode: 2-Column Bento Split Grid (5 : 7)
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column (5 cols / ~42%)
                        Expanded(
                          flex: 5,
                          child: leftColumnContent,
                        ),
                        const SizedBox(width: 24),
                        // Right Column (7 cols / ~58%)
                        Expanded(
                          flex: 7,
                          child: rightColumnContent,
                        ),
                      ],
                    ),
                  );
                }

                // Phone Mode (< 600dp): Single column linear stack
                return ListView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  children: [
                    leftColumnContent,
                    const SizedBox(height: 24),
                    rightColumnContent,
                    const SizedBox(height: 32),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildManagedAppCard(
    BuildContext context, {
    required ManagedApp app,
    required bool isDark,
    required Color container,
    required Color containerHigh,
    required Color borderCol,
    required Color textMain,
    required Color textMuted,
    required Color primary,
    required Color secondary,
    required Color secContainer,
    required Color onSecContainer,
  }) {
    final rule = widget.repository.getRuleForApp(app.id);
    final decision = widget.repository.evaluateApp(app);
    final isBlocked = decision.isBlocked;
    final isSelected = _selectedAppIds.contains(app.id);
    final isSelectionMode = _selectedAppIds.isNotEmpty;

    String statusText;
    Color statusBg;
    Color statusFg;
    if (!app.enabled) {
      statusText = 'PAUSED';
      statusBg = containerHigh;
      statusFg = textMuted;
    } else if (isBlocked) {
      statusText = 'MUTED';
      statusBg = primary.withOpacity(0.18);
      statusFg = primary;
    } else {
      statusText = 'ALLOWED';
      statusBg = secContainer;
      statusFg = onSecContainer;
    }

    String detailText;
    if (!app.enabled) {
      detailText = 'Monitoring paused';
    } else if (rule != null) {
      final mode = rule.mode == ScheduleMode.blockDuring ? 'Block' : 'Allow';
      detailText =
          '$mode · ${widget.repository.formatTime(rule.startTime)} - ${widget.repository.formatTime(rule.endTime)}';
    } else {
      detailText = 'No active schedule rule';
    }

    return InkWell(
      onLongPress: () {
        setState(() {
          if (_selectedAppIds.contains(app.id)) {
            _selectedAppIds.remove(app.id);
          } else {
            _selectedAppIds.add(app.id);
          }
        });
      },
      onTap: () {
        if (isSelectionMode) {
          setState(() {
            if (_selectedAppIds.contains(app.id)) {
              _selectedAppIds.remove(app.id);
            } else {
              _selectedAppIds.add(app.id);
            }
          });
        } else {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AppDetailsScreen(
                repository: widget.repository,
                app: app,
              ),
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? primary.withOpacity(0.12) : container,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? primary : borderCol,
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.15 : 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Native App Icon from PackageManager
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: containerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: app.iconBytes != null
                  ? Image.memory(
                      app.iconBytes!,
                      width: 46,
                      height: 46,
                      fit: BoxFit.cover,
                    )
                  : Icon(
                      _getDefaultIconForApp(app.displayName),
                      color: textMain,
                      size: 24,
                    ),
            ),
            const SizedBox(width: 14),

            // App Name & Detail Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          app.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: textMain,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          statusText,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: statusFg,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded,
                          size: 13, color: textMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          detailText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Toggle Master Monitoring Switch
            StitchSwitch(
              value: app.enabled,
              onChanged: (val) {
                widget.repository.toggleApp(app.id, val);
              },
            ),
            const SizedBox(width: 4),

            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: textMuted.withOpacity(0.6),
            ),
          ],
        ),
      ),
    );
  }
}
