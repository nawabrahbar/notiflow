import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:google_fonts/google_fonts.dart';
import '../../data/repositories/schedule_repository.dart';
import '../../data/services/installed_apps_cache.dart';
import '../../domain/engine/activity_grouping.dart';
import '../../domain/models/digest_window.dart';
import '../../domain/models/managed_app.dart';
import '../../platform/android_notification_platform.dart';
import '../theme/app_theme.dart';
import '../widgets/stitch_header.dart';
import '../widgets/app_toast.dart';
import '../widgets/animated_fab_label.dart';
import 'add_apps_screen.dart';

/// Activity Screen (Audit Trail) adhering strictly to Botanical Sanctuary / Nocturne design:
/// - Responsive: Multi-column tablet layout (>= 600dp) with top 3-metric bento spread and wide audit cards
/// - Filter bar (All, Digest, History, Silenced, Allowed) & Clear Log action
/// - Digest: one card per finished rule window with the unique notifications it silenced
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
  String _selectedFilter = 'all';
  bool _historyFabExtended = true;
  final List<Map<String, dynamic>> _events = [];
  final List<DigestWindow> _digest = [];
  final Map<int, List<Map<String, dynamic>>> _digestEvents = {};
  final Set<int> _expandedDigest = {};
  final Set<String> _expandedGroups = {};
  static const double _uninstalledOpacity = 0.55;
  List<Map<String, dynamic>> _rawLogs = const [];
  List<DigestWindow> _rawDigest = const [];
  // Swiped away but not yet deleted natively (Undo is still possible), or
  // deleted natively and waiting for the reload that no longer has them.
  final Set<String> _hiddenEventIds = {};
  final Set<int> _hiddenWindowIds = {};
  final InstalledAppsCache _appsCache = InstalledAppsCache.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.repository.addListener(_onRepositoryChanged);
    _appsCache.addListener(_onAppsCacheChanged);
    AndroidNotificationPlatform.addActivityUpdatedListener(_loadNativeEvents);
    _loadNativeEvents();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.repository.removeListener(_onRepositoryChanged);
    _appsCache.removeListener(_onAppsCacheChanged);
    AndroidNotificationPlatform.removeActivityUpdatedListener(_loadNativeEvents);
    super.dispose();
  }

  void _onRepositoryChanged() {
    _loadNativeEvents();
  }

  void _onAppsCacheChanged() {
    if (mounted) setState(_rebuildDisplay);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadNativeEvents();
    }
  }

  Future<void> refreshLogs() => _loadNativeEvents();

  /// Switches to the Digest filter (used by the Dashboard "review now" card).
  void showDigest() {
    if (!mounted) return;
    setState(() => _selectedFilter = 'digest');
    _loadNativeEvents();
  }

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

  /// Formats as "12 Sept, 11:40 PM" (or "12 Sept, 23:40" in 24-hour mode).
  String _formatShortTime(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sept', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]}, ${_formatClock(dt)}';
  }

  String _formatClock(DateTime dt) {
    final mm = dt.minute.toString().padLeft(2, '0');
    if (widget.repository.use24HourFormat) {
      return '${dt.hour.toString().padLeft(2, '0')}:$mm';
    }
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    return '$hour12:$mm ${dt.hour >= 12 ? 'PM' : 'AM'}';
  }

  /// "12 Sept, 9:00 AM – 5:00 PM", or both dates when the window crosses midnight.
  String _formatWindowRange(DateTime start, DateTime end) {
    final sameDay = start.year == end.year &&
        start.month == end.month &&
        start.day == end.day;
    return sameDay
        ? '${_formatShortTime(start)} – ${_formatClock(end)}'
        : '${_formatShortTime(start)} – ${_formatShortTime(end)}';
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
    // Log and digest load together; app names and icons come from the shared
    // cache so the list shows without waiting for the installed-apps scan.
    final results = await Future.wait<Object>([
      AndroidNotificationPlatform.fetchNativeActivityLog(),
      AndroidNotificationPlatform.fetchDigest(),
    ]);
    if (!mounted) return;
    _rawLogs = results[0] as List<Map<String, dynamic>>;
    _rawDigest = results[1] as List<DigestWindow>;
    setState(_rebuildDisplay);
    _loadAppDetails();
  }

  Future<void> _loadAppDetails() async {
    final packages = <String>{
      for (final e in _rawLogs)
        if (e['packageName'] is String) e['packageName'] as String,
      for (final w in _rawDigest)
        for (final e in w.events)
          if (e['packageName'] is String) e['packageName'] as String,
    };
    if (packages.isEmpty) return;
    await _appsCache.ensureLoaded();
    await Future.wait([
      _appsCache.loadIcons(packages),
      _appsCache.checkInstalled(packages),
    ]);
  }

  void _rebuildDisplay() {
    final Map<String, ManagedApp> appsByPkg = {
      for (final a in widget.repository.allManagedApps) a.packageName: a,
    };

    Map<String, dynamic> toDisplay(Map<String, dynamic> raw) {
      final pkg = raw['packageName'] as String? ?? 'Unknown App';
      final managedApp = appsByPkg[pkg];
      final installedApp = _appsCache.appFor(pkg);
      final rawAppName = (raw['appName'] as String?)?.trim() ?? '';
      final displayName = managedApp?.displayName ??
          installedApp?.displayName ??
          (rawAppName.isNotEmpty ? rawAppName : pkg);
      final iconBytes = _appsCache.iconFor(pkg) ?? managedApp?.iconBytes;

      final tsMs = (raw['timestampMs'] as num?)?.toInt() ?? 0;
      final dt = DateTime.fromMillisecondsSinceEpoch(tsMs);

      final isBlocked = raw['isBlocked'] as bool? ?? false;
      final reason = (raw['reason'] as String?)?.trim() ??
          (isBlocked ? 'Silenced while app was muted' : 'Allowed by schedule');

      return <String, dynamic>{
        'id': raw['id']?.toString() ?? '',
        'packageName': pkg,
        'icon': _getDefaultIconForApp(displayName),
        'iconBytes': iconBytes,
        'appName': displayName,
        'isUninstalled': _appsCache.isUninstalled(pkg),
        'notifTitle': (raw['title'] as String?)?.trim() ?? '',
        'notifMessage': (raw['message'] as String?)?.trim() ?? '',
        'subText': (raw['subText'] as String?)?.trim() ?? '',
        'conversationKey': (raw['conversationKey'] as String?)?.trim() ?? '',
        'time': _formatShortTime(dt),
        'fullDateTime': _formatFullDateTime(dt),
        'timestampMs': tsMs,
        'isBlocked': isBlocked,
        'isHistoryOnly': raw['isHistoryOnly'] == true,
        'reason': reason,
      };
    }

    bool visible(Map<String, dynamic> raw) =>
        !_hiddenEventIds.contains(raw['id']?.toString());

    _events
      ..clear()
      ..addAll(_rawLogs.where(visible).map(toDisplay));
    _digestEvents
      ..clear()
      ..addAll({
        for (final w in _rawDigest)
          if (!_hiddenWindowIds.contains(w.id))
            w.id: [
              for (final e in w.events)
                if (visible(e))
                  toDisplay({...e, 'appName': e['appName'] ?? w.appName}),
            ],
      });
    // A window whose messages were all deleted leaves the digest.
    _digestEvents.removeWhere((_, events) => events.isEmpty);
    _digest
      ..clear()
      ..addAll(DigestWindow.sorted(
          _rawDigest.where((w) => _digestEvents.containsKey(w.id)).toList()));
    _expandedDigest.retainWhere(_digestEvents.containsKey);
  }

  int get _silencedCount => _events.where((e) => e['isBlocked'] == true).length;
  int get _allowedCount => _events.where((e) => e['isBlocked'] == false).length;
  int get _historyCount => _events.where((e) => e['isHistoryOnly'] == true).length;

  List<Map<String, dynamic>> get _filteredEvents {
    if (_selectedFilter == 'history') {
      return _events.where((e) => e['isHistoryOnly'] == true).toList();
    } else if (_selectedFilter == 'silenced') {
      return _events.where((e) => e['isBlocked'] == true).toList();
    } else if (_selectedFilter == 'allowed') {
      return _events.where((e) => e['isBlocked'] == false).toList();
    }
    return _events;
  }

  void _selectFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
      _historyFabExtended = true;
    });
  }

  bool _onActivityScroll(UserScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical ||
        notification.direction == ScrollDirection.idle) {
      return false;
    }
    final extended = notification.direction == ScrollDirection.forward;
    if (extended != _historyFabExtended) {
      setState(() => _historyFabExtended = extended);
    }
    return false;
  }

  Future<void> _manageHistoryApps() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AddAppsScreen(
        repository: widget.repository,
        historyManagement: true,
      ),
    ));
    if (mounted) await _loadNativeEvents();
  }

  Widget _eventStatusBadge({
    required bool isBlocked,
    required bool isHistoryOnly,
    required bool isDark,
  }) {
    final background = isHistoryOnly
        ? (isDark
            ? AppTheme.darkSecondaryContainer
            : AppTheme.lightSecondaryContainer)
        : isBlocked
            ? (isDark
                ? AppTheme.darkSecondaryContainer.withOpacity(0.6)
                : AppTheme.lightSecondaryContainer)
            : isDark
                ? AppTheme.darkPrimaryContainer.withOpacity(0.2)
                : const Color(0xFFFFDCBD);
    final foreground = isHistoryOnly || !isBlocked
        ? (isDark
            ? isHistoryOnly
                ? AppTheme.darkOnSecondaryContainer
                : AppTheme.darkPrimary
            : isHistoryOnly
                ? AppTheme.lightOnSecondaryContainer
                : const Color(0xFF623F18))
        : (isDark
            ? AppTheme.darkOnSecondaryContainer
            : AppTheme.lightOnSecondaryContainer);
    final border = isHistoryOnly
        ? Colors.transparent
        : isBlocked
            ? (isDark
                ? AppTheme.darkOnSecondaryContainer.withOpacity(0.2)
                : Colors.transparent)
            : (isDark
                ? AppTheme.darkPrimaryContainer.withOpacity(0.3)
                : Colors.transparent);
    final dot = isHistoryOnly
        ? (isDark
            ? AppTheme.darkOnSecondaryContainer
            : AppTheme.lightOnSecondaryContainer)
        : isBlocked
            ? (isDark
                ? AppTheme.darkPrimaryContainer
                : AppTheme.lightPrimaryContainer)
            : (isDark ? const Color(0xFFA7D4A3) : AppTheme.lightSecondary);

    return Container(
      key: const ValueKey('activity-event-status-badge'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            isHistoryOnly ? 'HISTORY' : isBlocked ? 'SILENCED' : 'ALLOWED',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: foreground,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmClearActivity() {
    if (_events.isEmpty) {
      AppToast.show(
        context,
        message: 'Activity log is already empty.',
        type: AppToastType.info,
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
              AppToast.show(context, message: 'Triage activity log cleared.');
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  /// Ids of every message a (possibly grouped) log card stands for.
  List<String> _eventIds(Map<String, dynamic> evt) {
    final group = (evt['groupEvents'] as List?)?.cast<Map<String, dynamic>>();
    return [
      for (final e in group ?? [evt])
        if ((e['id'] as String? ?? '').isNotEmpty) e['id'] as String,
    ];
  }

  void _deleteLogCard(Map<String, dynamic> evt) {
    final ids = _eventIds(evt);
    if (ids.isEmpty) return;
    final count = ids.length;
    _deleteWithUndo(
      eventIds: ids,
      message: count > 1 ? '$count messages deleted' : 'Message deleted',
    );
  }

  void _deleteDigestWindow(DigestWindow window) {
    final events = _digestEvents[window.id] ?? const [];
    final count = events.length;
    _deleteWithUndo(
      eventIds: [for (final e in events) e['id'] as String? ?? ''],
      windowIds: [window.id],
      message: 'Digest deleted · $count message${count == 1 ? '' : 's'}',
    );
  }

  /// Hides the items at once and deletes them natively when the toast
  /// closes without Undo. Showing another toast closes (and commits) the
  /// previous one.
  void _deleteWithUndo({
    required List<String> eventIds,
    List<int> windowIds = const [],
    required String message,
  }) {
    final ids = eventIds.where((id) => id.isNotEmpty).toList();
    setState(() {
      _hiddenEventIds.addAll(ids);
      _hiddenWindowIds.addAll(windowIds);
      _rebuildDisplay();
    });

    AppToast.show(
      context,
      message: message,
      type: AppToastType.info,
      actionLabel: 'Undo',
    ).then((reason) async {
      if (reason == AppToastClosedReason.action) {
        if (!mounted) return;
        setState(() {
          _hiddenEventIds.removeAll(ids);
          _hiddenWindowIds.removeAll(windowIds);
          _rebuildDisplay();
        });
        return;
      }
      await Future.wait([
        AndroidNotificationPlatform.deleteActivityEvents(ids),
        AndroidNotificationPlatform.deleteDigestWindows(windowIds),
      ]);
      if (!mounted) return;
      await _loadNativeEvents();
      // Reloaded data no longer has them, so they can leave the hidden sets.
      _hiddenEventIds.removeAll(ids);
      _hiddenWindowIds.removeAll(windowIds);
    });
  }

  /// Swipe-right-to-delete wrapper shared by log and digest cards.
  Widget _swipeToDelete({
    required Key key,
    required VoidCallback onDelete,
    required BorderRadius radius,
    required Widget child,
    double bottomGap = 0,
  }) =>
      Padding(
        key: key,
        padding: EdgeInsets.only(bottom: bottomGap),
        child: _SwipeToDelete(
          dismissKey: key,
          radius: radius,
          onDelete: onDelete,
          child: child,
        ),
      );

  /// Card time, plus the message count when the card groups several messages.
  String _timeWithCount(Map<String, dynamic> evt) {
    final time = evt['time'] as String? ?? '';
    final count = evt['groupCount'] as int? ?? 1;
    return count > 1 ? '$time · $count messages' : time;
  }

  /// Stable id of a grouped card: its app and oldest message, which stay the
  /// same while newer messages join the card.
  String _groupId(Map<String, dynamic> evt) {
    final group = (evt['groupEvents'] as List?)?.cast<Map<String, dynamic>>();
    final oldest = group?.last ?? evt;
    return '${evt['packageName']}|${oldest['timestampMs']}';
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
    final bool isHistoryOnly = evt['isHistoryOnly'] == true;
    final String reason = evt['reason'] as String? ?? '';
    final List<Map<String, dynamic>> groupEvents =
        (evt['groupEvents'] as List?)?.cast<Map<String, dynamic>>() ??
            [evt];

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
                  _eventStatusBadge(
                    isBlocked: isBlocked,
                    isHistoryOnly: isHistoryOnly,
                    isDark: isDark,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (groupEvents.length > 1) ...[
                Text(
                  notifTitle.isNotEmpty
                      ? '$notifTitle · ${groupEvents.length} messages'
                      : '${groupEvents.length} messages',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textMain,
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.45,
                  ),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: containerHigh.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(14),
                      // Oldest first so the conversation reads top to bottom.
                      itemCount: groupEvents.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final e = groupEvents[groupEvents.length - 1 - i];
                        final msg = (e['notifMessage'] as String? ?? '').trim();
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                msg.isNotEmpty
                                    ? msg
                                    : 'No preview content available.',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  color: textMain,
                                  height: 1.4,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              e['time'] as String? ?? '',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: textMuted,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ] else
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
              if (_eventIds(evt).isNotEmpty) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          isDark ? AppTheme.darkError : AppTheme.lightError,
                      side: BorderSide(
                          color: (isDark
                                  ? AppTheme.darkError
                                  : AppTheme.lightError)
                              .withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _deleteLogCard(evt);
                    },
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: Text(groupEvents.length > 1
                        ? 'Delete ${groupEvents.length} messages'
                        : 'Delete'),
                  ),
                ),
              ],
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

    final events = groupActivityEvents(_filteredEvents);

    return Scaffold(
      backgroundColor: bg,
      appBar:
          widget.isEmbedded ? null : const StitchHeader(title: 'Activity Log'),
      floatingActionButton: _selectedFilter != 'history'
          ? null
          : FloatingActionButton.extended(
              key: const ValueKey('history-manage-apps-fab'),
              heroTag: 'history-manage-apps-fab',
              onPressed: _manageHistoryApps,
              tooltip: 'Manage history apps',
              backgroundColor: primary,
              foregroundColor:
                  isDark ? AppTheme.darkOnPrimary : AppTheme.lightOnPrimary,
              extendedIconLabelSpacing: 0,
              extendedPadding: const EdgeInsets.symmetric(horizontal: 18),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              icon: const Icon(Icons.apps_rounded),
              label: AnimatedFabLabel(
                  extended: _historyFabExtended, label: 'Manage apps'),
            ),
      body: NotificationListener<UserScrollNotification>(
        onNotification: _onActivityScroll,
        child: SafeArea(
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
                  child: !isTablet
                      ? _buildPhoneLayout(isDark, events)
                      : Column(
                    children: [
                      // Bento Metrics (Intercepted, Permitted)
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
                                    _buildFilterPill('digest', 'Digest',
                                        _digest.length, isDark),
                                    const SizedBox(width: 6),
                                    _buildFilterPill('history', 'History',
                                        _historyCount, isDark),
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
                        child: _selectedFilter == 'digest'
                            ? _buildDigestList(isDark, textMain, textMuted)
                            : events.isEmpty
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
                                      _selectedFilter == 'history'
                                          ? 'Use Manage apps to choose apps to record. Quick Mute still applies.'
                                          : 'Notifications intercepted or permitted will appear here in real-time.',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12.5,
                                        color: textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : HeaderScrollTransition(
                              child: ListView.builder(
                                padding: EdgeInsets.only(
                                    top: 4,
                                    bottom: _selectedFilter == 'history' ? 96 : 24),
                                itemCount: events.length,
                                itemBuilder: (context, index) {
                                  final evt = events[index];
                                  final isBlocked =
                                      evt['isBlocked'] as bool? ?? false;
                                  final Uint8List? iconBytes =
                                      evt['iconBytes'] as Uint8List?;

                                  final uninstalled =
                                      evt['isUninstalled'] == true;

                                  return _swipeToDelete(
                                    key: ValueKey('log-${_groupId(evt)}'),
                                    radius: BorderRadius.circular(14),
                                    bottomGap: 10,
                                    onDelete: () => _deleteLogCard(evt),
                                    child: InkWell(
                                    onTap: () => _showNotificationDetailsSheet(
                                        evt, isDark),
                                    borderRadius: BorderRadius.circular(14),
                                    child: Opacity(
                                      opacity: uninstalled
                                          ? _uninstalledOpacity
                                          : 1,
                                      child: Container(
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
                                                      uninstalled
                                                          ? 'Uninstalled · ${_timeWithCount(evt)}'
                                                          : _timeWithCount(evt),
                                                      style: GoogleFonts
                                                          .plusJakartaSans(
                                                        fontSize: 11,
                                                        color: textMuted,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (evt['isHistoryOnly'] == true) ...[
                                                  const SizedBox(height: 4),
                                                  _eventStatusBadge(
                                                    isBlocked: isBlocked,
                                                    isHistoryOnly: true,
                                                    isDark: isDark,
                                                  ),
                                                ],
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
                                    ),
                                    ),
                                  );
                                },
                              ),
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
      ),
    );
  }

  Widget _buildPhoneLayout(bool isDark, List<Map<String, dynamic>> events) {
    final textMain =
        isDark ? const Color(0xFFF3F4F1) : AppTheme.lightOnSurface;
    final textMuted = isDark
        ? AppTheme.darkOnSurfaceVariant
        : AppTheme.lightOnSurfaceVariant;
    final chipBg =
        isDark ? const Color(0xFF1E2621) : AppTheme.lightSurfaceContainer;
    final chipBorder = isDark ? const Color(0xFF2A362F) : Colors.transparent;
    final isDigest = _selectedFilter == 'digest';

    Widget filterPill(String key, String label, int count) {
      final selected = _selectedFilter == key;
      return GestureDetector(
        key: ValueKey('activity-filter-$key'),
        onTap: () => _selectFilter(key),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? (isDark
                    ? AppTheme.darkPrimaryContainer
                    : AppTheme.lightPrimaryContainer)
                : chipBg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? Colors.transparent : chipBorder),
          ),
          child: Text(
            '$label $count',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected
                  ? (isDark
                      ? const Color(0xFF2B1700)
                      : AppTheme.lightOnPrimaryContainer)
                  : (isDark ? const Color(0xFFE0E3E0) : textMuted),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          // Let chips scroll under the page padding up to the screen edges.
          clipBehavior: Clip.none,
          child: Row(
            children: [
              filterPill('all', 'All', _events.length),
              const SizedBox(width: 8),
              filterPill('digest', 'Digest', _digest.length),
              const SizedBox(width: 8),
              filterPill('history', 'History', _historyCount),
              const SizedBox(width: 8),
              filterPill('silenced', 'Silenced', _silencedCount),
              const SizedBox(width: 8),
              filterPill('allowed', 'Allowed', _allowedCount),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Text(
              isDigest ? 'Catch-up' : 'Recorded',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textMain,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: textMuted.withOpacity(0.6),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                isDigest
                    ? '${_digest.length} ${_digest.length == 1 ? 'Window' : 'Windows'}'
                    : '${events.length} ${events.length == 1 ? 'Event' : 'Events'}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: textMuted,
                ),
              ),
            ),
            GestureDetector(
              onTap: _confirmClearActivity,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: chipBg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: chipBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.delete_sweep_outlined,
                        size: 15,
                        color: isDark
                            ? AppTheme.darkPrimary
                            : AppTheme.lightPrimary),
                    const SizedBox(width: 6),
                    Text(
                      'Clear Log',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppTheme.darkPrimary
                            : AppTheme.lightPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: isDigest
              ? _buildDigestList(isDark, textMain, textMuted)
              : events.isEmpty
              ? _buildPhoneEmptyState(
                  isDark, textMain, textMuted,
                  message: _selectedFilter == 'history'
                      ? 'No history recorded yet. Use Manage apps to choose apps. '
                          'Quick Mute still applies.'
                      : 'No notifications matching this filter or the log was recently refreshed.',
                )
              : HeaderScrollTransition(
                child: ListView.separated(
                  padding: EdgeInsets.only(
                      bottom: _selectedFilter == 'history' ? 96 : 24),
                  itemCount: events.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) => _swipeToDelete(
                    key: ValueKey('log-${_groupId(events[index])}'),
                    radius: BorderRadius.circular(12),
                    onDelete: () => _deleteLogCard(events[index]),
                    child: _buildPhoneEventCard(
                        events[index], isDark, textMain, textMuted),
                  ),
                ),
                ),
        ),
      ],
    );
  }

  int get unreviewedDigestCount =>
      _digest.where((w) => !w.reviewed).fold(0, (sum, w) => sum + _windowCount(w));

  int _windowCount(DigestWindow w) => _digestEvents[w.id]?.length ?? 0;

  void _toggleDigestWindow(DigestWindow window) {
    final wasExpanded = _expandedDigest.contains(window.id);
    // A window still running can't be reviewed yet, so its end-of-rule
    // notification still covers everything silenced in it.
    final markReviewed = !window.reviewed && !window.end.isAfter(DateTime.now());
    setState(() {
      if (wasExpanded) {
        _expandedDigest.remove(window.id);
      } else {
        _expandedDigest.add(window.id);
      }
      if (markReviewed) {
        final index = _digest.indexWhere((w) => w.id == window.id);
        if (index >= 0) _digest[index] = window.copyWith(reviewed: true);
        _rawDigest = [
          for (final w in _rawDigest)
            w.id == window.id ? w.copyWith(reviewed: true) : w,
        ];
      }
    });
    if (markReviewed) {
      AndroidNotificationPlatform.markDigestReviewed([window.id]);
    }
  }

  Widget _buildDigestList(bool isDark, Color textMain, Color textMuted) {
    if (_digest.isEmpty) {
      return _buildPhoneEmptyState(
        isDark,
        textMain,
        textMuted,
        message:
            'Nothing to catch up on. When a rule ends, the notifications it silenced are grouped here by app.',
      );
    }
    return HeaderScrollTransition(
      child: ListView.separated(
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      itemCount: _digest.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _swipeToDelete(
        key: ValueKey('digest-${_digest[index].id}'),
        radius: BorderRadius.circular(12),
        onDelete: () => _deleteDigestWindow(_digest[index]),
        child: _buildDigestCard(_digest[index], isDark, textMain, textMuted),
      ),
    ));
  }

  Widget _buildDigestCard(DigestWindow window, bool isDark, Color textMain,
      Color textMuted) {
    final events = _digestEvents[window.id] ?? const [];
    final header = events.isNotEmpty ? events.first : null;
    final iconBytes = header?['iconBytes'] as Uint8List?;
    final appName = header?['appName'] as String? ?? window.displayName;
    final expanded = _expandedDigest.contains(window.id);
    final unreviewed = !window.reviewed;
    final accent = isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary;
    final cardBg =
        isDark ? const Color(0xFF1A211D) : AppTheme.lightSurfaceContainerLow;
    final cardBorder = unreviewed
        ? accent.withValues(alpha: isDark ? 0.5 : 0.35)
        : (isDark ? const Color(0xFF2A362F) : Colors.transparent);
    final countBg = isDark
        ? AppTheme.darkSecondaryContainer.withValues(alpha: 0.6)
        : AppTheme.lightSecondaryContainer;
    final countFg = isDark
        ? AppTheme.darkOnSecondaryContainer
        : AppTheme.lightOnSecondaryContainer;

    return Container(
      key: ValueKey('digest_window_${window.id}'),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => _toggleDigestWindow(window),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.darkSurfaceContainerHigh
                          : AppTheme.lightSurfaceContainerHigh,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: iconBytes != null
                        ? Image.memory(iconBytes,
                            width: 34, height: 34, fit: BoxFit.cover)
                        : Icon(_getDefaultIconForApp(appName),
                            size: 18, color: textMain),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                appName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: textMain,
                                  height: 1.3,
                                ),
                              ),
                            ),
                            if (unreviewed) ...[
                              const SizedBox(width: 6),
                              Container(
                                key: ValueKey('digest_unreviewed_${window.id}'),
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: accent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          _formatWindowRange(window.start, window.end),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: textMuted,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: countBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${_windowCount(window)} silenced',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: countFg,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 20,
                    color: textMuted,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            Divider(
              height: 1,
              color: isDark
                  ? const Color(0xFF2A362F)
                  : AppTheme.lightOutlineVariant.withValues(alpha: 0.5),
            ),
            for (final evt in events)
              _buildDigestEventRow(window, evt, textMain, textMuted),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }

  Widget _buildDigestEventRow(DigestWindow window, Map<String, dynamic> evt,
      Color textMain, Color textMuted) {
    final title = (evt['notifTitle'] as String? ?? '').trim();
    final message = (evt['notifMessage'] as String? ?? '').trim();
    return InkWell(
      onTap: () => AndroidNotificationPlatform.openApp(window.packageName),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(60, 10, 16, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title.isNotEmpty)
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textMain,
                        height: 1.4,
                      ),
                    ),
                  if (message.isNotEmpty)
                    Text(
                      message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: textMain,
                        height: 1.4,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _formatClock(DateTime.fromMillisecondsSinceEpoch(
                  evt['timestampMs'] as int? ?? 0)),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: textMuted,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneEmptyState(bool isDark, Color textMain, Color textMuted,
      {String message =
          'No notifications matching this filter or the log was recently refreshed.'}) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1A211D)
              : AppTheme.lightSurfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isDark ? const Color(0xFF2A362F) : Colors.transparent),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.darkSecondaryContainer
                    : AppTheme.lightSecondaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.notifications_paused_outlined,
                  size: 24,
                  color: isDark
                      ? AppTheme.darkOnSecondaryContainer
                      : AppTheme.lightOnSecondaryContainer),
            ),
            const SizedBox(height: 12),
            Text(
              'All caught up',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textMain,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: textMuted,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneEventCard(Map<String, dynamic> evt, bool isDark,
      Color textMain, Color textMuted) {
    final isBlocked = evt['isBlocked'] as bool? ?? false;
    final isHistoryOnly = evt['isHistoryOnly'] == true;
    final iconBytes = evt['iconBytes'] as Uint8List?;
    final title = (evt['notifTitle'] as String? ?? '').trim();
    final message = (evt['notifMessage'] as String? ?? '').trim();
    final reason = (evt['reason'] as String? ?? '').trim();
    final group = (evt['groupEvents'] as List?)?.cast<Map<String, dynamic>>() ??
        [evt];
    final isGroup = group.length > 1;
    final groupId = _groupId(evt);
    final expanded = isGroup && _expandedGroups.contains(groupId);

    final uninstalled = evt['isUninstalled'] == true;

    return InkWell(
      onTap: () => _showNotificationDetailsSheet(evt, isDark),
      borderRadius: BorderRadius.circular(12),
      child: Opacity(
        opacity: uninstalled ? _uninstalledOpacity : 1,
        child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1A211D)
              : AppTheme.lightSurfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isDark ? const Color(0xFF2A362F) : Colors.transparent),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.darkSurfaceContainerHigh
                        : AppTheme.lightSurfaceContainerHigh,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: iconBytes != null
                      ? Image.memory(iconBytes,
                          width: 34, height: 34, fit: BoxFit.cover)
                      : Icon(evt['icon'] as IconData? ?? Icons.notifications,
                          size: 18, color: textMain),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        evt['appName'] as String? ?? 'App',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: textMain,
                          height: 1.3,
                        ),
                      ),
                      Text(
                        uninstalled
                            ? 'Uninstalled · ${_timeWithCount(evt)}'
                            : _timeWithCount(evt),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: textMuted,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _eventStatusBadge(
                  isBlocked: isBlocked,
                  isHistoryOnly: isHistoryOnly,
                  isDark: isDark,
                ),
              ],
            ),
            if (title.isNotEmpty || message.isNotEmpty || reason.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF222B25)
                      : AppTheme.lightSurfaceContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF2A362F).withOpacity(0.5)
                        : Colors.transparent,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title.isNotEmpty || isGroup)
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: textMain,
                              ),
                            ),
                          ),
                          if (isGroup)
                            InkResponse(
                              radius: 20,
                              onTap: () => setState(() => expanded
                                  ? _expandedGroups.remove(groupId)
                                  : _expandedGroups.add(groupId)),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  expanded
                                      ? Icons.expand_less_rounded
                                      : Icons.expand_more_rounded,
                                  size: 22,
                                  color: textMuted,
                                ),
                              ),
                            ),
                        ],
                      ),
                    if (expanded) ...[
                      // Oldest first so the conversation reads top to bottom.
                      for (final e in group.reversed) ...[
                        const SizedBox(height: 6),
                        Text(
                          (e['notifMessage'] as String? ?? '').trim(),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: textMuted,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ] else if (message.isNotEmpty || title.isEmpty) ...[
                      if (title.isNotEmpty) const SizedBox(height: 2),
                      Text(
                        message.isNotEmpty ? message : reason,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: textMuted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
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
      key: ValueKey('activity-filter-$key'),
      onTap: () => _selectFilter(key),
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

/// Dismissible clips its own background to a straight-edged strip, which
/// shows the page behind the card's rounded corners. This paints the soft red
/// under the whole card instead, only while it is being swiped, and clips
/// both to the card's rounded shape.
class _SwipeToDelete extends StatefulWidget {
  const _SwipeToDelete({
    required this.dismissKey,
    required this.radius,
    required this.onDelete,
    required this.child,
  });

  final Key dismissKey;
  final BorderRadius radius;
  final VoidCallback onDelete;
  final Widget child;

  @override
  State<_SwipeToDelete> createState() => _SwipeToDeleteState();
}

class _SwipeToDeleteState extends State<_SwipeToDelete> {
  bool _swiping = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onColor =
        isDark ? AppTheme.darkOnErrorContainer : AppTheme.lightOnErrorContainer;
    return ClipRRect(
      borderRadius: widget.radius,
      child: Stack(
        children: [
          if (_swiping)
            Positioned.fill(
              child: Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 24),
                color: isDark
                    ? AppTheme.darkErrorContainer
                    : AppTheme.lightErrorContainer,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.delete_outline_rounded, color: onColor),
                    const SizedBox(width: 6),
                    Text('Delete',
                        style: GoogleFonts.plusJakartaSans(
                            color: onColor, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          Dismissible(
            key: widget.dismissKey,
            direction: DismissDirection.startToEnd,
            onUpdate: (details) {
              final swiping = details.progress > 0;
              if (swiping != _swiping) setState(() => _swiping = swiping);
            },
            onDismissed: (_) => widget.onDelete(),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
