import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/repositories/schedule_repository.dart';
import '../../domain/models/managed_app.dart';
import '../../platform/android_notification_platform.dart';
import '../theme/app_theme.dart';
import '../widgets/stitch_header.dart';

/// Activity Screen (Audit Trail) adhering strictly to Botanical Sanctuary / Nocturne design:
/// - Responsive: Multi-column tablet layout (>= 600dp) with top 3-metric bento spread and wide audit cards
/// - Filter bar (All, Silenced, Allowed) with count badges & Clear Log action
/// - Real native app icons from PackageManager
/// - Notification details inspector bottom sheet
class ActivityScreen extends StatefulWidget {
  final ScheduleRepository repository;
  final bool isEmbedded;

  const ActivityScreen({
    super.key,
    required this.repository,
    this.isEmbedded = false,
  });

  @override
  State<ActivityScreen> createState() => ActivityScreenState();
}

class ActivityScreenState extends State<ActivityScreen>
    with WidgetsBindingObserver {
  String _selectedFilter = 'all'; // 'all', 'silenced', 'allowed'
  final List<Map<String, dynamic>> _events = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.repository.addListener(_onRepositoryChanged);
    AndroidNotificationPlatform.setActivityUpdatedListener(_loadNativeEvents);
    _loadNativeEvents();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.repository.removeListener(_onRepositoryChanged);
    AndroidNotificationPlatform.setActivityUpdatedListener(null);
    super.dispose();
  }

  void _onRepositoryChanged() {
    _loadNativeEvents();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadNativeEvents();
    }
  }

  Future<void> refreshLogs() => _loadNativeEvents();

  IconData _getDefaultIconForApp(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('chat') ||
        lower.contains('whatsapp') ||
        lower.contains('telegram') ||
        lower.contains('signal') ||
        lower.contains('message')) {
      return Icons.chat_bubble_rounded;
    }
    if (lower.contains('slack') ||
        lower.contains('team') ||
        lower.contains('meet') ||
        lower.contains('discord')) {
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
    if (lower.contains('phone') ||
        lower.contains('call') ||
        lower.contains('dialer')) {
      return Icons.call_rounded;
    }
    return Icons.notifications_paused_rounded;
  }

  String _formatShortTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(dt.year, dt.month, dt.day);
    final diffDays = today.difference(eventDay).inDays;

    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final hm =
        '${hour12.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $period';

    if (diffDays == 0) {
      return hm;
    } else if (diffDays == 1) {
      return 'Yesterday · $hm';
    } else {
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return '${months[dt.month - 1]} ${dt.day} · $hm';
    }
  }

  String _formatFullDateTime(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final hm =
        '${hour12.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')} $period';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} at $hm';
  }

  Future<void> _loadNativeEvents() async {
    final nativeLogs =
        await AndroidNotificationPlatform.fetchNativeActivityLog();
    if (!mounted) return;

    final Map<String, ManagedApp> appsByPkg = {
      for (final a in widget.repository.managedApps) a.packageName: a,
    };

    setState(() {
      _events
        ..clear()
        ..addAll(nativeLogs.map((raw) {
          final pkg = raw['packageName'] as String? ?? 'Unknown App';
          final managedApp = appsByPkg[pkg];
          final rawAppName = (raw['appName'] as String?)?.trim() ?? '';
          final displayName = managedApp?.displayName ??
              (rawAppName.isNotEmpty ? rawAppName : pkg);
          final iconBytes = managedApp?.iconBytes;

          final tsMs = (raw['timestampMs'] as num?)?.toInt() ?? 0;
          final dt = DateTime.fromMillisecondsSinceEpoch(tsMs);
          final timeStr = _formatShortTime(dt);
          final fullDateTimeStr = _formatFullDateTime(dt);

          final isBlocked = raw['isBlocked'] as bool? ?? false;
          final notifTitle = (raw['title'] as String?)?.trim() ?? '';
          final notifMessage = (raw['message'] as String?)?.trim() ?? '';
          final subText = (raw['subText'] as String?)?.trim() ?? '';
          final reason = (raw['reason'] as String?)?.trim() ??
              (isBlocked
                  ? 'Silenced while app was muted'
                  : 'Allowed by schedule');

          return <String, dynamic>{
            'packageName': pkg,
            'icon': _getDefaultIconForApp(displayName),
            'iconBytes': iconBytes,
            'appName': displayName,
            'notifTitle': notifTitle,
            'notifMessage': notifMessage,
            'subText': subText,
            'time': timeStr,
            'fullDateTime': fullDateTimeStr,
            'timestampMs': tsMs,
            'isBlocked': isBlocked,
            'reason': reason,
          };
        }));
    });
  }

  int get _silencedCount => _events.where((e) => e['isBlocked'] == true).length;
  int get _allowedCount => _events.where((e) => e['isBlocked'] == false).length;

  List<Map<String, dynamic>> get _filteredEvents {
    if (_selectedFilter == 'silenced') {
      return _events.where((e) => e['isBlocked'] == true).toList();
    } else if (_selectedFilter == 'allowed') {
      return _events.where((e) => e['isBlocked'] == false).toList();
    }
    return _events;
  }

  void _confirmClearActivity() {
    if (_events.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('Activity log is already empty.'),
            backgroundColor: AppTheme.toastWarning,
          ),
        );
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark
            ? AppTheme.darkSurfaceContainerLow
            : AppTheme.lightSurfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Clear Activity Log?',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: isDark ? AppTheme.darkOnSurface : AppTheme.lightOnSurface,
          ),
        ),
        content: Text(
          'Are you sure you want to clear all recorded notification triage events? This on-device audit history cannot be restored.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: isDark
                ? AppTheme.darkOnSurfaceVariant
                : AppTheme.lightOnSurfaceVariant,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isDark ? AppTheme.darkError : AppTheme.lightError,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await AndroidNotificationPlatform.clearNativeActivityLog();
              if (!mounted) return;
              setState(() => _events.clear());
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: const Text('Triage activity log cleared.'),
                    backgroundColor: AppTheme.toastSuccess,
                  ),
                );
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  void _showNotificationDetailsSheet(
      Map<String, dynamic> evt, bool isDark) {
    final containerLow = isDark
        ? AppTheme.darkSurfaceContainerLow
        : AppTheme.lightSurfaceContainerLow;
    final containerHigh = isDark
        ? AppTheme.darkSurfaceContainerHigh
        : AppTheme.lightSurfaceContainerHigh;
    final textMain = isDark ? AppTheme.darkOnSurface : AppTheme.lightOnSurface;
    final textMuted = isDark
        ? AppTheme.darkOnSurfaceVariant
        : AppTheme.lightOnSurfaceVariant;
    final primary = isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary;
    final secContainer = isDark
        ? AppTheme.darkSecondaryContainer
        : AppTheme.lightSecondaryContainer;
    final onSecContainer = isDark
        ? AppTheme.darkOnSecondaryContainer
        : AppTheme.lightOnSecondaryContainer;

    final String appName = evt['appName'] as String? ?? 'Application';
    final String packageName = evt['packageName'] as String? ?? '';
    final Uint8List? iconBytes = evt['iconBytes'] as Uint8List?;
    final IconData fallbackIcon =
        evt['icon'] as IconData? ?? Icons.notifications_paused_rounded;
    final String notifTitle = evt['notifTitle'] as String? ?? '';
    final String notifMessage = evt['notifMessage'] as String? ?? '';
    final String subText = evt['subText'] as String? ?? '';
    final String fullDateTime =
        evt['fullDateTime'] as String? ?? (evt['time'] as String? ?? '');
    final bool isBlocked = evt['isBlocked'] as bool? ?? false;
    final String reason = evt['reason'] as String? ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: containerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: containerHigh,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: containerHigh,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: iconBytes != null
                        ? Image.memory(iconBytes,
                            width: 46, height: 46, fit: BoxFit.cover)
                        : Icon(fallbackIcon, color: textMain, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appName,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: textMain,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subText.isNotEmpty
                              ? '$subText · $packageName'
                              : packageName,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isBlocked ? primary.withOpacity(0.18) : secContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isBlocked ? 'MUTED' : 'ALLOWED',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: isBlocked ? primary : onSecContainer,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: containerHigh.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (notifTitle.isNotEmpty) ...[
                      Text(
                        notifTitle,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: textMain,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      notifMessage.isNotEmpty
                          ? notifMessage
                          : 'No preview content available.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: textMuted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(Icons.shield_outlined, size: 16, color: primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      reason,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.access_time_rounded, size: 16, color: textMuted),
                  const SizedBox(width: 6),
                  Text(
                    fullDateTime,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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

    final events = _filteredEvents;

    return Scaffold(
      backgroundColor: bg,
      appBar:
          widget.isEmbedded ? null : const StitchHeader(title: 'Activity Log'),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isTablet = constraints.maxWidth >= 600;

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isTablet ? 1200 : 600,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 24 : 16,
                    vertical: 8,
                  ),
                  child: Column(
                    children: [
                      // Top 3 Bento Metrics (Intercepted, Permitted, Leak Rate)
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard(
                              title: 'Intercepted',
                              count: '$_silencedCount',
                              tag: 'MUTED',
                              icon: Icons.notifications_off_rounded,
                              isDark: isDark,
                              container: container,
                              containerHigh: containerHigh,
                              borderCol: borderCol,
                              textMain: textMain,
                              textMuted: textMuted,
                              accent: primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMetricCard(
                              title: 'Permitted',
                              count: '$_allowedCount',
                              tag: 'ALERTS',
                              icon: Icons.notifications_active_rounded,
                              isDark: isDark,
                              container: container,
                              containerHigh: secContainer,
                              borderCol: borderCol,
                              textMain: textMain,
                              textMuted: textMuted,
                              accent: onSecContainer,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMetricCard(
                              title: 'Privacy Node',
                              count: '100%',
                              tag: 'LOCAL',
                              icon: Icons.shield_rounded,
                              isDark: isDark,
                              container: container,
                              containerHigh: secContainer,
                              borderCol: borderCol,
                              textMain: textMain,
                              textMuted: textMuted,
                              accent: secondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Filter Bar & Clear Action
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: containerLow,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderCol, width: 1.0),
                        ),
                        child: Row(
                          children: [
                            // Filter Pills
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _buildFilterPill('all', 'All',
                                        _events.length, isDark),
                                    const SizedBox(width: 6),
                                    _buildFilterPill('silenced', 'Silenced',
                                        _silencedCount, isDark),
                                    const SizedBox(width: 6),
                                    _buildFilterPill('allowed', 'Allowed',
                                        _allowedCount, isDark),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Clear Button
                            GestureDetector(
                              onTap: _confirmClearActivity,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: containerHigh,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.delete_sweep_rounded,
                                        size: 16, color: textMuted),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Clear Log',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11.5,
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
                      ),
                      const SizedBox(height: 12),

                      // Recorded Events List
                      Expanded(
                        child: events.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.history_toggle_off_rounded,
                                        size: 40, color: textMuted),
                                    const SizedBox(height: 10),
                                    Text(
                                      'No notification events recorded',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: textMain,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Notifications intercepted or permitted will appear here in real-time.',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12.5,
                                        color: textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.only(
                                    top: 4, bottom: 24),
                                itemCount: events.length,
                                itemBuilder: (context, index) {
                                  final evt = events[index];
                                  final isBlocked =
                                      evt['isBlocked'] as bool? ?? false;
                                  final Uint8List? iconBytes =
                                      evt['iconBytes'] as Uint8List?;

                                  return InkWell(
                                    onTap: () => _showNotificationDetailsSheet(
                                        evt, isDark),
                                    borderRadius: BorderRadius.circular(14),
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: containerLow,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                            color: borderCol, width: 1.0),
                                      ),
                                      child: Row(
                                        children: [
                                          // App Icon with Small Status Indicator
                                          Stack(
                                            children: [
                                              Container(
                                                width: 42,
                                                height: 42,
                                                decoration: BoxDecoration(
                                                  color: containerHigh,
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                clipBehavior: Clip.antiAlias,
                                                child: iconBytes != null
                                                    ? Image.memory(
                                                        iconBytes,
                                                        width: 42,
                                                        height: 42,
                                                        fit: BoxFit.cover,
                                                      )
                                                    : Icon(
                                                        evt['icon'] as IconData? ??
                                                            Icons.notifications,
                                                        size: 20,
                                                        color: textMain,
                                                      ),
                                              ),
                                              Positioned(
                                                bottom: 0,
                                                right: 0,
                                                child: Container(
                                                  width: 12,
                                                  height: 12,
                                                  decoration: BoxDecoration(
                                                    color: isBlocked
                                                        ? primary
                                                        : secondary,
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: containerLow,
                                                      width: 1.5,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(width: 12),

                                          // Content Details
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Text(
                                                      evt['appName'] as String? ??
                                                          'App',
                                                      style: GoogleFonts
                                                          .plusJakartaSans(
                                                        fontSize: 13.5,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: textMain,
                                                      ),
                                                    ),
                                                    if ((evt['notifTitle']
                                                                as String? ??
                                                            '')
                                                        .isNotEmpty) ...[
                                                      Text(
                                                        ' · ${evt['notifTitle']}',
                                                        style: GoogleFonts
                                                            .plusJakartaSans(
                                                          fontSize: 12.5,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: textMain,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ],
                                                    const Spacer(),
                                                    Text(
                                                      evt['time'] as String? ?? '',
                                                      style: GoogleFonts
                                                          .plusJakartaSans(
                                                        fontSize: 11,
                                                        color: textMuted,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  (evt['notifMessage']
                                                                  as String? ??
                                                              '')
                                                          .isNotEmpty
                                                      ? '“${evt['notifMessage']}”'
                                                      : evt['reason']
                                                              as String? ??
                                                          '',
                                                  style: GoogleFonts
                                                      .plusJakartaSans(
                                                    fontSize: 12,
                                                    fontStyle: FontStyle.italic,
                                                    color: textMuted,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String count,
    required String tag,
    required IconData icon,
    required bool isDark,
    required Color container,
    required Color containerHigh,
    required Color borderCol,
    required Color textMain,
    required Color textMuted,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: container,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderCol, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 16, color: accent),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: containerHigh,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  tag,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    color: accent,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            count,
            style: GoogleFonts.newsreader(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: textMain,
              letterSpacing: -0.4,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPill(
      String key, String label, int count, bool isDark) {
    final isSelected = _selectedFilter == key;
    final primary = isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary;
    final containerHigh = isDark
        ? AppTheme.darkSurfaceContainerHigh
        : AppTheme.lightSurfaceContainerHigh;
    final textMain = isDark ? AppTheme.darkOnSurface : AppTheme.lightOnSurface;
    final textMuted = isDark
        ? AppTheme.darkOnSurfaceVariant
        : AppTheme.lightOnSurfaceVariant;

    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected
                    ? (isDark
                        ? AppTheme.darkOnPrimary
                        : AppTheme.lightOnPrimary)
                    : textMuted,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark
                        ? AppTheme.darkOnPrimary.withOpacity(0.2)
                        : AppTheme.lightOnPrimary.withOpacity(0.2))
                    : containerHigh,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: isSelected
                      ? (isDark
                          ? AppTheme.darkOnPrimary
                          : AppTheme.lightOnPrimary)
                      : textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
