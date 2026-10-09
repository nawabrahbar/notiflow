import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/repositories/schedule_repository.dart';
import '../../domain/models/schedule_rule.dart';
import '../../platform/notification_platform_interface.dart';
import '../../platform/platform_factory.dart';
import '../widgets/stitch_switch.dart';
import 'add_apps_screen.dart';
import 'app_details_screen.dart';
import 'permission_screen.dart';

/// Dashboard Screen faithfully matching the Stitch Obsidian Signal redesign.
/// Features dynamic time greetings, Intercepted/Permitted metrics cards,
/// quick session overrides, managed apps with amber status chips,
/// and batch delivery status.
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

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
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
    // Curated pool of 10 quotes switched according to time of day
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

  Future<void> _deleteSelectedApps() async {
    final count = _selectedAppIds.length;
    if (count == 0) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF18181B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Delete $count ${count == 1 ? 'Rule' : 'Rules'}?',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFFFAFAFA) : const Color(0xFF1A1C1D),
            ),
          ),
          content: Text(
            'This will stop monitoring the selected ${count == 1 ? 'app' : 'apps'} and remove all associated schedule rules.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF47464B),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
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
      setState(() {
        _selectedAppIds.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed $count ${count == 1 ? 'app and its rules' : 'apps and their rules'}'),
            backgroundColor: const Color(0xFFF59E0B),
          ),
        );
      }
    }
  }

  ({String text, IconData icon, Color color}) _getGreetingData() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return (
        text: 'Good morning',
        icon: Icons.wb_twilight_rounded,
        color: const Color(0xFFF59E0B),
      );
    } else if (hour >= 12 && hour < 17) {
      return (
        text: 'Good afternoon',
        icon: Icons.wb_sunny_rounded,
        color: const Color(0xFFEAB308),
      );
    } else if (hour >= 17 && hour < 21) {
      return (
        text: 'Good evening',
        icon: Icons.brightness_medium_rounded,
        color: const Color(0xFFF97316),
      );
    } else {
      return (
        text: 'Good night',
        icon: Icons.bedtime_rounded,
        color: const Color(0xFF38BDF8),
      );
    }
  }

  IconData _getDefaultIconForApp(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('chat') || lower.contains('whatsapp') || lower.contains('telegram') || lower.contains('message')) {
      return Icons.chat_bubble_rounded;
    }
    if (lower.contains('slack') || lower.contains('team') || lower.contains('meet')) {
      return Icons.workspaces_rounded;
    }
    if (lower.contains('mail') || lower.contains('gmail') || lower.contains('outlook')) {
      return Icons.mail_rounded;
    }
    if (lower.contains('insta') || lower.contains('photo') || lower.contains('camera')) {
      return Icons.photo_camera_rounded;
    }
    if (lower.contains('tweet') || lower.contains('twitter') || lower.contains('x')) {
      return Icons.tag_rounded;
    }
    return Icons.apps_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF09090B) : const Color(0xFFF9F9FB);
    final cardBg = isDark ? const Color(0xFF18181B) : Colors.white;
    final borderCol = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E2E4);
    final textMain = isDark ? const Color(0xFFFAFAFA) : const Color(0xFF1A1C1D);
    final textMuted = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF47464B);
    final amber = const Color(0xFFF59E0B);

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
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              children: [
                // Dynamic Time-Based Greeting
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(greeting.icon, size: 28, color: greeting.color),
                    const SizedBox(width: 10),
                    Text(
                      greeting.text,
                      style: GoogleFonts.inter(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: textMain,
                        letterSpacing: -0.6,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _getTimeBasedQuote(),
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    color: textMuted,
                  ),
                ),
                const SizedBox(height: 20),

                // Restoration Banner (if access restored)
                if (_showRestorationBanner) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF052E16) : const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Focus Shield Online',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: textMain,
                                ),
                              ),
                              Text(
                                'ACCESS RESTORED',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF22C55E),
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _showRestorationBanner = false),
                          child: const Text('Audit Health'),
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
                      color: isDark ? const Color(0xFF272014) : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: amber.withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: amber, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Notification Access Required',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: textMain,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Schedules are currently paused until Android Notification Access is reconnected.',
                          style: GoogleFonts.inter(fontSize: 12, color: textMuted),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: amber,
                              foregroundColor: const Color(0xFF09090B),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PermissionScreen(
                                    repository: widget.repository,
                                  ),
                                ),
                              );
                            },
                            child: Text(
                              'Reconnect Permission',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // -------------------------------------------------------------
                // 2 Metric Cards: Intercepted & Permitted
                // -------------------------------------------------------------
                Row(
                  children: [
                    // Intercepted Card
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderCol),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Intercepted',
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: textMuted,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF272014) : const Color(0xFFFEF3C7),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.notifications_off_outlined, size: 16, color: amber),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  '${summary.blocked}',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: textMain,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: amber.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'MUTED',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: amber,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Permitted Card
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderCol),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Permitted',
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: textMuted,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF052E16) : const Color(0xFFDCFCE7),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.notifications_active_outlined, size: 16, color: Color(0xFF22C55E)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  '${summary.allowed}',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: textMain,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'ALERTS',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF22C55E),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // -------------------------------------------------------------
                // Quick Session Overrides
                // -------------------------------------------------------------
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'QUICK SESSION OVERRIDES · Tap to engage',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Overrides Horizontal Actions
                if (activeOverride != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF272014) : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: amber),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.hourglass_top_rounded, color: amber, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            activeOverride.type == 'mute_all'
                                ? 'Mute All Active (${activeOverride.remainingMinutes}m left)'
                                : 'Pass Calls Active',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: textMain,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => widget.repository.clearOverride(activeOverride.appId),
                          style: TextButton.styleFrom(
                            foregroundColor: amber,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          ),
                          child: Text(
                            'Restore',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            widget.repository.setTemporaryMute(
                              appId: 'global_mute',
                              duration: const Duration(minutes: 15),
                            );
                          },
                          icon: const Icon(Icons.volume_off_rounded, size: 16),
                          label: Text(
                            'Mute All (15m)',
                            style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: textMain,
                            side: BorderSide(color: borderCol),
                            backgroundColor: cardBg,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () {
                            widget.repository.setTemporaryMute(
                              appId: 'global_mute',
                              duration: const Duration(hours: 1),
                            );
                          },
                          icon: const Icon(Icons.volume_off_rounded, size: 16),
                          label: Text(
                            'Mute All (1h)',
                            style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: textMain,
                            side: BorderSide(color: borderCol),
                            backgroundColor: cardBg,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () {
                            widget.repository.setTemporaryAllow(
                              appId: 'global_allow',
                              duration: const Duration(hours: 1),
                            );
                          },
                          icon: const Icon(Icons.phone_in_talk_rounded, size: 16),
                          label: Text(
                            'Pass Calls',
                            style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: textMain,
                            side: BorderSide(color: borderCol),
                            backgroundColor: cardBg,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 28),

                // -------------------------------------------------------------
                // Managed Apps Section
                // -------------------------------------------------------------
                if (_selectedAppIds.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF272014) : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: amber.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.close_rounded, size: 20, color: textMain),
                          onPressed: () => setState(() => _selectedAppIds.clear()),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${_selectedAppIds.length} Selected',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: textMain,
                          ),
                        ),
                        const Spacer(),
                        Tooltip(
                          message: _selectedAppIds.length == apps.length ? 'Deselect all' : 'Select all',
                          child: Checkbox(
                            key: const Key('select_all_checkbox'),
                            value: _selectedAppIds.length == apps.length,
                            activeColor: amber,
                            checkColor: const Color(0xFF09090B),
                            side: BorderSide(
                              color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            onChanged: (bool? checked) {
                              setState(() {
                                if (_selectedAppIds.length == apps.length) {
                                  _selectedAppIds.clear();
                                } else {
                                  _selectedAppIds.addAll(apps.map((a) => a.id));
                                }
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _deleteSelectedApps,
                          icon: const Icon(Icons.delete_outline_rounded, size: 16),
                          label: const Text('Delete'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          'MANAGED APPS',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                            color: textMuted,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF27272A) : const Color(0xFFEEEEF0),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${apps.length}',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: amber,
                            ),
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: widget.onAddAppTap ??
                          () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => AddAppsScreen(repository: widget.repository),
                              ),
                            );
                          },
                      child: Text(
                        '+ Add App',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: amber,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Managed Apps List
                if (apps.isEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderCol),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 40,
                          color: textMuted,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No apps managed yet',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: textMain,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Select installed apps to apply quiet schedules and silence distractions.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(fontSize: 13, color: textMuted),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Add Apps'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: amber,
                            foregroundColor: const Color(0xFF09090B),
                          ),
                          onPressed: widget.onAddAppTap ??
                              () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => AddAppsScreen(repository: widget.repository),
                                  ),
                                );
                              },
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  ...apps.map((app) {
                    final rule = widget.repository.getRuleForApp(app.id);
                    final decision = widget.repository.evaluateApp(app);
                    final isBlocked = decision.isBlocked;
                    final isSelected = _selectedAppIds.contains(app.id);
                    final isSelectionMode = _selectedAppIds.isNotEmpty;

                    String statusText;
                    Color statusColor;
                    if (!app.enabled) {
                      statusText = 'PAUSED';
                      statusColor = textMuted;
                    } else if (isBlocked) {
                      statusText = 'MUTED';
                      statusColor = amber;
                    } else {
                      statusText = 'ALLOWED';
                      statusColor = const Color(0xFF22C55E);
                    }

                    String detailText;
                    if (!app.enabled) {
                      detailText = 'Monitoring disabled';
                    } else if (rule != null) {
                      final mode = rule.mode == ScheduleMode.blockDuring ? 'Block' : 'Allow';
                      detailText = '$mode · ${rule.startTime.format12Hour()} - ${rule.endTime.format12Hour()}';
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
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark ? const Color(0xFF272014) : const Color(0xFFFEF3C7))
                              : cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? amber : borderCol,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF27272A) : const Color(0xFFEEEEF0),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _getDefaultIconForApp(app.displayName),
                                color: textMain,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          app.displayName,
                                          style: GoogleFonts.inter(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: textMain,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(5),
                                        ),
                                        child: Text(
                                          statusText,
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: statusColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    detailText,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: textMuted,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            if (isSelectionMode)
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: isSelected ? amber : Colors.transparent,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected ? amber : textMuted,
                                    width: 2,
                                  ),
                                ),
                                child: isSelected
                                    ? const Icon(Icons.check, size: 16, color: Colors.black)
                                    : null,
                              )
                            else
                              StitchSwitch(
                                value: app.enabled,
                                onChanged: (val) {
                                  widget.repository.toggleAppMonitoring(app.id, val);
                                },
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],

                const SizedBox(height: 24),

                // Zero-Leak Guarantee Footer Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF121214) : const Color(0xFFF3F3F5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderCol),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.verified_user_rounded, size: 16, color: amber),
                      const SizedBox(width: 8),
                      Text(
                        'Zero-Leak Guarantee · 100% On-Device Protection',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}
