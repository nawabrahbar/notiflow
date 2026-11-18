import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/repositories/schedule_repository.dart';
import '../../data/services/installed_apps_cache.dart';
import '../../domain/models/managed_app.dart';
import '../../domain/models/schedule_rule.dart';
import '../../platform/android_notification_platform.dart';
import '../../platform/notification_platform_interface.dart';
import '../../platform/platform_factory.dart';
import '../theme/app_theme.dart';
import '../widgets/stitch_switch.dart';
import '../widgets/app_toast.dart';
import '../widgets/quick_mute_card.dart';
import 'add_apps_screen.dart';
import 'app_details_screen.dart';
import 'permission_screen.dart';

/// Which part of the home experience a [DashboardScreen] renders.
enum DashboardView {
  /// Dashboard tab: greeting, metrics, Quick Mute card and the digest overview.
  home,

  /// Rules tab: the managed apps catalog.
  rules,
}

/// Dashboard and Rules screens adhering strictly to Botanical Sanctuary / Nocturne design:
/// - Responsive layout: Single column on phone (< 600dp), 2-Column Bento Split (5 : 7) on tablet (>= 600dp)
/// - Home: Editorial Greeting card, Bento metrics (Intercepted & Permitted),
///   Quick Mute · All apps card and the Catch-Up Digest overview card
/// - Rules: Managed Apps catalog with real native app icons from PackageManager
class DashboardScreen extends StatefulWidget {
  final ScheduleRepository repository;
  final DashboardView view;
  final VoidCallback? onAddAppTap;
  final VoidCallback? onOpenDigest;
  final bool initialShowRestorationBanner;

  const DashboardScreen({
    super.key,
    required this.repository,
    this.view = DashboardView.rules,
    this.onAddAppTap,
    this.onOpenDigest,
    this.initialShowRestorationBanner = false,
  });

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  late final NotificationPlatformInterface _platform;
  bool _isPermissionGranted = true;
  late bool _showRestorationBanner;
  final Set<String> _selectedAppIds = <String>{};
  int _unreviewedDigestCount = 0;

  bool get _isHome => widget.view == DashboardView.home;

  @override
  void initState() {
    super.initState();
    _showRestorationBanner = widget.initialShowRestorationBanner;
    WidgetsBinding.instance.addObserver(this);
    _platform = PlatformFactory.createPlatformService();
    _checkPermission();
    InstalledAppsCache.instance.addListener(_onInstalledAppsChanged);
    if (_isHome) {
      AndroidNotificationPlatform.addActivityUpdatedListener(_loadDigestSummary);
      _loadDigestSummary();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    InstalledAppsCache.instance.removeListener(_onInstalledAppsChanged);
    AndroidNotificationPlatform.removeActivityUpdatedListener(_loadDigestSummary);
    super.dispose();
  }

  void _onInstalledAppsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermission();
      if (_isHome) _loadDigestSummary();
    }
  }

  /// Reloads the digest overview, e.g. when the Dashboard tab is reselected.
  Future<void> refreshDigest() => _loadDigestSummary();

  Future<void> _loadDigestSummary() async {
    final windows = await AndroidNotificationPlatform.fetchDigest();
    if (!mounted) return;
    final count = windows
        .where((w) => !w.reviewed)
        .fold<int>(0, (sum, w) => sum + w.count);
    setState(() => _unreviewedDigestCount = count);
  }

  Widget _buildDigestOverviewCard({
    required bool isDark,
    required Color containerLow,
    required Color borderCol,
    required Color textMain,
    required Color textMuted,
    required Color primary,
    required Color secContainer,
    required Color onSecContainer,
  }) {
    final count = _unreviewedDigestCount;
    final hasNew = count > 0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('digest_overview_card'),
        onTap: widget.onOpenDigest,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: containerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasNew ? primary.withValues(alpha: 0.5) : borderCol,
              width: 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CATCH-UP DIGEST',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: textMuted,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: hasNew
                          ? primary.withValues(alpha: isDark ? 0.2 : 0.12)
                          : secContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      hasNew
                          ? Icons.mark_email_unread_outlined
                          : Icons.done_all_rounded,
                      size: 20,
                      color: hasNew ? primary : onSecContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasNew
                              ? '$count silenced ${count == 1 ? 'notification' : 'notifications'}'
                              : 'All caught up',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: textMain,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasNew
                              ? 'Review now'
                              : 'When a rule ends, what it silenced is grouped here by app.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight:
                                hasNew ? FontWeight.w600 : FontWeight.w400,
                            color: hasNew ? primary : textMuted,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 22, color: textMuted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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

  ({String text, IconData icon}) _getGreetingData() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return (
        text: 'Good morning',
        icon: Icons.light_mode_rounded,
      );
    } else if (hour >= 12 && hour < 17) {
      return (
        text: 'Good afternoon',
        icon: Icons.wb_sunny_rounded,
      );
    } else if (hour >= 17 && hour < 21) {
      return (
        text: 'Good evening',
        icon: Icons.bedtime_rounded,
      );
    } else {
      return (
        text: 'Good night',
        icon: Icons.nights_stay_rounded,
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
            'Delete $count ${count == 1 ? 'Rule' : 'Rules'}?',
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
              child: const Text('Delete'),
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
        AppToast.show(context, message: 'Removed $count apps from Rules page');
      }
    }
  }

  Widget _buildMetricCards({
    required bool isDark,
    required bool isTablet,
    required int blocked,
    required int allowed,
  }) {
    final textMain = isDark ? AppTheme.darkOnSurface : AppTheme.lightOnSurface;
    final textMuted =
        isDark ? const Color(0xFF9AA79B) : AppTheme.lightOnSurfaceVariant;
    final mutedChipBg = isDark
        ? AppTheme.darkPrimaryContainer.withOpacity(0.2)
        : const Color(0xFFFFDCBD);
    final mutedChipFg =
        isDark ? AppTheme.darkPrimary : const Color(0xFF623F18);
    final mutedChipBorder = isDark
        ? AppTheme.darkPrimaryContainer.withOpacity(0.3)
        : Colors.transparent;
    final alertChipBg =
        isDark ? const Color(0xFF2E3B32) : AppTheme.lightSecondaryContainer;
    final alertChipFg =
        isDark ? const Color(0xFFA7D4A3) : AppTheme.lightOnSecondaryContainer;
    final alertChipBorder =
        isDark ? const Color(0xFF3A4B3F) : Colors.transparent;

    if (!isTablet) {
      final cardBg =
          isDark ? const Color(0xFF1A211D) : AppTheme.lightSurfaceContainer;
      final cardBorder = isDark ? const Color(0xFF2A362F) : Colors.transparent;

      Widget phoneCard({
        required String label,
        required String chip,
        required Color chipBg,
        required Color chipFg,
        required Color chipBorder,
        required int count,
        required String unit,
      }) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: isDark ? FontWeight.w600 : FontWeight.w700,
                  color: textMuted,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$count',
                    style: GoogleFonts.newsreader(
                      fontSize: 26,
                      height: 34 / 26,
                      fontWeight: FontWeight.w400,
                      color: textMain,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    unit,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: textMuted,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: chipBg,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: chipBorder),
                    ),
                    child: Text(
                      chip,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: chipFg,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }

      return Row(
        children: [
          Expanded(
            child: phoneCard(
              label: 'Intercepted',
              chip: 'MUTED',
              chipBg: mutedChipBg,
              chipFg: mutedChipFg,
              chipBorder: mutedChipBorder,
              count: blocked,
              unit: blocked == 1 ? 'item' : 'items',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: phoneCard(
              label: 'Permitted',
              chip: 'ALERTS',
              chipBg: alertChipBg,
              chipFg: alertChipFg,
              chipBorder: alertChipBorder,
              count: allowed,
              unit: allowed == 1 ? 'pass' : 'passes',
            ),
          ),
        ],
      );
    }

    final cardBg = isDark
        ? AppTheme.darkSurfaceContainer
        : AppTheme.lightSurfaceContainerLowest;
    final cardBorder = isDark
        ? AppTheme.darkSurfaceContainerHigh.withOpacity(0.3)
        : Colors.transparent;
    final iconMutedBg = isDark
        ? AppTheme.darkSurfaceContainerHigh
        : AppTheme.lightSurfaceContainerHigh;
    final iconMutedFg =
        isDark ? AppTheme.darkOnSurfaceVariant : AppTheme.lightOnSurfaceVariant;
    final secContainer = isDark
        ? AppTheme.darkSecondaryContainer
        : AppTheme.lightSecondaryContainer;
    final onSecContainer = isDark
        ? AppTheme.darkOnSecondaryContainer
        : AppTheme.lightOnSecondaryContainer;
    final primary = isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary;
    final secondary = isDark ? AppTheme.darkSecondary : AppTheme.lightSecondary;

    Widget tabletCard({
      required IconData icon,
      required Color iconBg,
      required Color iconFg,
      required String chip,
      required Color chipBg,
      required Color chipFg,
      required Color chipBorder,
      required int count,
      required String label,
      required Color accent,
    }) {
      return Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration:
                            BoxDecoration(color: iconBg, shape: BoxShape.circle),
                        child: Icon(icon, size: 20, color: iconFg),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: chipBg,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: chipBorder),
                        ),
                        child: Text(
                          chip,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: chipFg,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$count',
                    style: GoogleFonts.newsreader(
                      fontSize: 48,
                      height: 56 / 48,
                      fontWeight: FontWeight.w500,
                      color: textMain,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: iconMutedFg,
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 4, color: accent),
          ],
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: tabletCard(
            icon: Icons.notifications_off_outlined,
            iconBg: iconMutedBg,
            iconFg: iconMutedFg,
            chip: 'MUTED',
            chipBg: isDark
                ? AppTheme.darkPrimaryContainer.withOpacity(0.3)
                : const Color(0xFFFFDCBD),
            chipFg: isDark ? AppTheme.darkPrimary : const Color(0xFF623F18),
            chipBorder:
                isDark ? AppTheme.darkPrimary.withOpacity(0.2) : Colors.transparent,
            count: blocked,
            label: 'Intercepted',
            accent: primary.withOpacity(isDark ? 0.3 : 0.2),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: tabletCard(
            icon: Icons.notifications_active,
            iconBg: secContainer,
            iconFg: onSecContainer,
            chip: 'ALERTS',
            chipBg: secContainer,
            chipFg: isDark ? onSecContainer : const Color(0xFF171E06),
            chipBorder:
                isDark ? secondary.withOpacity(0.2) : Colors.transparent,
            count: allowed,
            label: 'Permitted',
            accent: secondary.withOpacity(0.3),
          ),
        ),
      ],
    );
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
        final greeting = _getGreetingData();

        return Scaffold(
          backgroundColor: bg,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isTablet = constraints.maxWidth >= 600;

                // Permission Recovery Banner (if access lost)
                final Widget? permissionBanner = _isPermissionGranted
                    ? null
                    : Container(
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
                      );

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
                                    'Focus Shield Online',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: textMain,
                                    ),
                                  ),
                                  Text(
                                    'ACCESS RESTORED',
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
                              child: const Text('Audit Health'),
                            ),
                          ],
                        ),
                      ),
                    ],

                    ?permissionBanner,

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
                              Flexible(
                                child: Text(
                                  greeting.text,
                                  style: GoogleFonts.newsreader(
                                    fontSize: isTablet ? 32 : 28,
                                    fontWeight: FontWeight.w600,
                                    color: textMain,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Icon(greeting.icon,
                                  size: isTablet ? 28 : 24, color: primary),
                            ],
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
                    _buildMetricCards(
                      isDark: isDark,
                      isTablet: isTablet,
                      blocked: summary.blocked,
                      allowed: summary.allowed,
                    ),
                    const SizedBox(height: 16),

                    QuickMuteAllCard(repository: widget.repository),
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
                            Checkbox(
                              key: const Key('select_all_checkbox'),
                              value: _selectedAppIds.length == widget.repository.managedApps.length,
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedAppIds.addAll(widget.repository.managedApps.map((a) => a.id));
                                  } else {
                                    _selectedAppIds.clear();
                                  }
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${_selectedAppIds.length} Selected',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: textMain,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              key: const ValueKey('rules-delete-selected'),
                              onPressed: _deleteSelectedApps,
                              tooltip: 'Delete selected',
                              icon: Icon(
                                Icons.delete_outline_rounded,
                                size: 24,
                                color: isDark
                                    ? AppTheme.darkError
                                    : AppTheme.lightError,
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
                        if (apps.isNotEmpty)
                          TextButton(
                          onPressed: widget.onAddAppTap ??
                              () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => AddAppsScreen(
                                        repository: widget.repository),
                                  ),
                                );
                              },
                          style: TextButton.styleFrom(
                            foregroundColor: primary,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            '+ Add App',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
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

                if (!_isHome) {
                  if (isTablet) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ?permissionBanner,
                          rightColumnContent,
                        ],
                      ),
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    children: [
                      ?permissionBanner,
                      rightColumnContent,
                      const SizedBox(height: 32),
                    ],
                  );
                }

                final digestCard = _buildDigestOverviewCard(
                  isDark: isDark,
                  containerLow: containerLow,
                  borderCol: borderCol,
                  textMain: textMain,
                  textMuted: textMuted,
                  primary: primary,
                  secContainer: secContainer,
                  onSecContainer: onSecContainer,
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
                          child: digestCard,
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
                    const SizedBox(height: 16),
                    digestCard,
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
    final allRules = widget.repository.getRulesForApp(app.id);
    final rule = widget.repository.getRuleForApp(app.id);
    final decision = widget.repository.evaluateApp(app);
    final isBlocked = decision.isBlocked;
    final isSelected = _selectedAppIds.contains(app.id);
    final isSelectionMode = _selectedAppIds.isNotEmpty;
    // Rules stay so the user can delete them; reinstalling restores the card.
    final isUninstalled =
        InstalledAppsCache.instance.isUninstalled(app.packageName);

    String statusText;
    Color statusBg;
    Color statusFg;
    if (isUninstalled) {
      statusText = 'UNINSTALLED';
      statusBg = containerHigh;
      statusFg = textMuted;
    } else if (!app.enabled) {
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
    if (isUninstalled) {
      detailText = 'App not installed';
    } else if (!app.enabled) {
      detailText = 'Monitoring paused';
    } else if (rule != null) {
      final isBlockRule = rule.mode == ScheduleMode.blockDuring ||
          rule.mode == ScheduleMode.allDayBlock;
      final mode = isBlockRule ? 'Block' : 'Allow';
      final isAllDay = rule.mode == ScheduleMode.allDayBlock ||
          rule.mode == ScheduleMode.allDayAllow;
      final windowStr = isAllDay
          ? 'All Day'
          : '${widget.repository.formatTime(rule.startTime)} - ${widget.repository.formatTime(rule.endTime)}';
      final extraCount = allRules.length > 1 ? ' (+${allRules.length - 1} more)' : '';
      detailText = '$mode · $windowStr$extraCount';
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
        child: Opacity(
          opacity: isUninstalled ? 0.55 : 1,
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
                      // Expanded keeps the status badge aligned at the right edge.
                      Expanded(
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
            IgnorePointer(
              ignoring: isUninstalled,
              child: StitchSwitch(
                value: app.enabled,
                onChanged: (val) {
                  widget.repository.toggleApp(app.id, val);
                },
              ),
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
      ),
    );
  }
}
