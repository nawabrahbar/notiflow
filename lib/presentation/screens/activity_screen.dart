import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/repositories/schedule_repository.dart';
import '../../domain/models/managed_app.dart';
import '../../platform/android_notification_platform.dart';
import '../widgets/stitch_header.dart';

/// Activity Log Screen matching Stitch Obsidian Signal redesign.
/// Displays audit trail of triaged and muted notifications with full details
/// (app icon, app name, notification title/sender, message body, subtext/channel,
/// timestamp, and rule/override reason), 3 key metrics cards,
/// filter pills (All, Silenced, Allowed), and interactive detail inspector.
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

class ActivityScreenState extends State<ActivityScreen> with WidgetsBindingObserver {
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

  /// Refreshes recorded notification events from the native store.
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
      return Icons.tag_rounded;
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
    if (lower.contains('phone') || lower.contains('call') || lower.contains('dialer')) {
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
    final hm = '${hour12.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $period';

    if (diffDays == 0) {
      return hm;
    } else if (diffDays == 1) {
      return 'Yesterday · $hm';
    } else {
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[dt.month - 1]} ${dt.day} · $hm';
    }
  }

  String _formatFullDateTime(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final hm = '${hour12.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')} $period';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} at $hm';
  }

  Future<void> _loadNativeEvents() async {
    final nativeLogs = await AndroidNotificationPlatform.fetchNativeActivityLog();
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
              (isBlocked ? 'Silenced while app was muted' : 'Allowed by schedule');

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

  void clearActivity([BuildContext? targetContext]) {
    final ctx = targetContext ?? context;
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    final borderCol = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E2E4);
    final textMain = isDark ? const Color(0xFFFAFAFA) : const Color(0xFF1A1C1D);
    final textMuted = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF47464B);
    _confirmClearActivity(ctx, isDark, borderCol, textMain, textMuted);
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

  void _confirmClearActivity(
    BuildContext context,
    bool isDark,
    Color borderCol,
    Color textMain,
    Color textMuted,
  ) {
    if (_events.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Activity log is already empty.',
            style: TextStyle(color: Color(0xFF09090B), fontWeight: FontWeight.w700),
          ),
          backgroundColor: Color(0xFFF59E0B),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF18181B) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderCol),
        ),
        title: Text(
          'Clear Activity Log?',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: textMain,
          ),
        ),
        content: Text(
          'Are you sure you want to clear all recorded notification triage events? This on-device audit history cannot be restored.',
          style: GoogleFonts.inter(fontSize: 13, color: textMuted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await AndroidNotificationPlatform.clearNativeActivityLog();
              if (!mounted) return;
              setState(() {
                _events.clear();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Triage activity log cleared.',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  backgroundColor: Color(0xFF22C55E),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  void _showNotificationDetailsSheet(Map<String, dynamic> evt, bool isDark) {
    final cardBg = isDark ? const Color(0xFF18181B) : Colors.white;
    final subBoxBg = isDark ? const Color(0xFF222226) : const Color(0xFFF4F4F6);
    final borderCol = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E2E4);
    final textMain = isDark ? const Color(0xFFFAFAFA) : const Color(0xFF1A1C1D);
    final textMuted = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF47464B);
    const amber = Color(0xFFF59E0B);
    const green = Color(0xFF22C55E);

    final String appName = evt['appName'] as String? ?? 'Application';
    final String packageName = evt['packageName'] as String? ?? '';
    final Uint8List? iconBytes = evt['iconBytes'] as Uint8List?;
    final IconData fallbackIcon = evt['icon'] as IconData? ?? Icons.notifications_paused_rounded;
    final String notifTitle = evt['notifTitle'] as String? ?? '';
    final String notifMessage = evt['notifMessage'] as String? ?? '';
    final String subText = evt['subText'] as String? ?? '';
    final String fullDateTime = evt['fullDateTime'] as String? ?? (evt['time'] as String? ?? '');
    final bool isBlocked = evt['isBlocked'] as bool? ?? false;
    final String reason = evt['reason'] as String? ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardBg,
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
                    color: borderCol,
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
                      color: subBoxBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderCol),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: iconBytes != null
                        ? Image.memory(iconBytes, width: 46, height: 46, fit: BoxFit.cover)
                        : Icon(fallbackIcon, color: textMain, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appName,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: textMain,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subText.isNotEmpty ? '$subText · $packageName' : packageName,
                          style: GoogleFonts.jetBrainsMono(
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isBlocked
                          ? amber.withValues(alpha: 0.15)
                          : green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isBlocked
                            ? amber.withValues(alpha: 0.4)
                            : green.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      isBlocked ? 'MUTED' : 'ALLOWED',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: isBlocked ? amber : green,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: subBoxBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderCol),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NOTIFICATION CONTENT',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: amber,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (notifTitle.isNotEmpty) ...[
                      SelectableText(
                        notifTitle,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: textMain,
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          notifMessage.isNotEmpty
                              ? notifMessage
                              : (notifTitle.isNotEmpty
                                  ? 'No additional message body.'
                                  : 'Notification intercepted while $appName was muted (no text content exposed by sender).'),
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            color: notifMessage.isNotEmpty ? textMain : textMuted,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: subBoxBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderCol),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded, size: 14, color: textMuted),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            fullDateTime,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11.5,
                              color: textMain,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          isBlocked ? Icons.block_rounded : Icons.check_circle_rounded,
                          size: 14,
                          color: isBlocked ? amber : green,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            reason,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: isBlocked ? amber : green,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textMain,
                        side: BorderSide(color: borderCol),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'Close',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  if (packageName.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final opened = await AndroidNotificationPlatform.openApp(packageName);
                          if (!opened && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Could not open $appName.',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                ),
                                backgroundColor: const Color(0xFFEF4444),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: Text(
                          'Open App',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: amber,
                          foregroundColor: const Color(0xFF09090B),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
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
    final bg = isDark ? const Color(0xFF09090B) : const Color(0xFFF9F9FB);
    final cardBg = isDark ? const Color(0xFF18181B) : Colors.white;
    final borderCol = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E2E4);
    final textMain = isDark ? const Color(0xFFFAFAFA) : const Color(0xFF1A1C1D);
    final textMuted = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF47464B);
    const amber = Color(0xFFF59E0B);

    final interceptedStr = '$_silencedCount';
    final focusGainStr = _silencedCount == 0
        ? '0m'
        : (_silencedCount * 4 >= 60
            ? '${((_silencedCount * 4) / 60).toStringAsFixed(1)}h'
            : '${_silencedCount * 4}m');

    return ListenableBuilder(
      listenable: widget.repository,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: bg,
          appBar: widget.isEmbedded
              ? null
              : const StitchHeader(
                  title: 'Activity Log',
                ),
          body: RefreshIndicator(
            color: amber,
            onRefresh: _loadNativeEvents,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              children: [
                Text(
                  'Notifications captured while apps are muted',
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    color: textMuted,
                  ),
                ),
                const SizedBox(height: 16),

                // 3 Metric Cards Grid
                Row(
                  children: [
                    _buildMetricTile(
                      title: 'Intercepted',
                      value: interceptedStr,
                      subtitle: 'Muted alerts held',
                      icon: Icons.shield_rounded,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _buildMetricTile(
                      title: 'Focus Gain',
                      value: focusGainStr,
                      subtitle: 'Deep focus saved',
                      icon: Icons.bolt_rounded,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _buildMetricTile(
                      title: 'Leak Rate',
                      value: '0%',
                      subtitle: 'Zero cloud sync',
                      icon: Icons.lock_outline_rounded,
                      isDark: isDark,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Filter Chips
                Row(
                  children: [
                    _buildFilterChip('All ${_events.length}', 'all', isDark),
                    const SizedBox(width: 8),
                    _buildFilterChip('Silenced $_silencedCount', 'silenced', isDark),
                    const SizedBox(width: 8),
                    _buildFilterChip('Allowed $_allowedCount', 'allowed', isDark),
                  ],
                ),
                const SizedBox(height: 20),

                // Events Section Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _events.isEmpty ? 'Events' : 'Recorded · ${_filteredEvents.length} Events',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: textMain,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _confirmClearActivity(context, isDark, borderCol, textMain, textMuted),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF272014) : const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.delete_sweep_rounded, size: 13, color: amber),
                            const SizedBox(width: 4),
                            Text(
                              'Clear Log',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: amber,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Events Stream or Clean Zero-State
                if (_events.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderCol),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF272014) : const Color(0xFFFEF3C7),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.history_toggle_off_rounded, size: 28, color: amber),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Activity Recorded',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: textMain,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Notifications that arrive while an app is muted will be recorded here with full message details.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: textMuted,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_filteredEvents.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderCol),
                    ),
                    child: Center(
                      child: Text(
                        'No $_selectedFilter events match the current filter.',
                        style: GoogleFonts.inter(fontSize: 13, color: textMuted),
                      ),
                    ),
                  )
                else
                  ..._filteredEvents.map((evt) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildEventCard(
                          evt: evt,
                          isDark: isDark,
                        ),
                      )),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required bool isDark,
  }) {
    final cardBg = isDark ? const Color(0xFF18181B) : Colors.white;
    final borderCol = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E2E4);
    final textMain = isDark ? const Color(0xFFFAFAFA) : const Color(0xFF1A1C1D);
    final textMuted = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF47464B);
    const amber = Color(0xFFF59E0B);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderCol),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: textMuted,
                  ),
                ),
                Icon(icon, size: 14, color: amber),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: textMain,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: textMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, bool isDark) {
    final isSelected = _selectedFilter == value;
    const amber = Color(0xFFF59E0B);
    final cardBg = isDark ? const Color(0xFF18181B) : Colors.white;
    final borderCol = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E2E4);
    final textMain = isDark ? const Color(0xFFFAFAFA) : const Color(0xFF1A1C1D);

    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? amber : cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? amber : borderCol),
        ),
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: isSelected ? const Color(0xFF09090B) : textMain,
          ),
        ),
      ),
    );
  }

  Widget _buildEventCard({
    required Map<String, dynamic> evt,
    required bool isDark,
  }) {
    final cardBg = isDark ? const Color(0xFF18181B) : Colors.white;
    final subBoxBg = isDark ? const Color(0xFF222226) : const Color(0xFFF4F4F6);
    final borderCol = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E2E4);
    final textMain = isDark ? const Color(0xFFFAFAFA) : const Color(0xFF1A1C1D);
    final textMuted = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF47464B);
    const amber = Color(0xFFF59E0B);
    const green = Color(0xFF22C55E);

    final IconData appIcon = evt['icon'] as IconData? ?? Icons.notifications_none_rounded;
    final Uint8List? iconBytes = evt['iconBytes'] as Uint8List?;
    final String appName = evt['appName'] as String? ?? 'Notification';
    final String subText = evt['subText'] as String? ?? '';
    final String notifTitle = evt['notifTitle'] as String? ?? '';
    final String notifMessage = evt['notifMessage'] as String? ?? '';
    final String time = evt['time'] as String? ?? 'Just now';
    final bool isBlocked = evt['isBlocked'] as bool? ?? false;
    final String reason = evt['reason'] as String? ?? 'Evaluated';

    final String headerLabel = subText.isNotEmpty ? '$appName · $subText' : appName;
    final String primaryLine = notifTitle.isNotEmpty
        ? (notifMessage.isNotEmpty ? '$notifTitle: $notifMessage' : notifTitle)
        : (notifMessage.isNotEmpty
            ? notifMessage
            : (isBlocked
                ? 'Notification silenced while $appName was muted'
                : 'Notification allowed for $appName'));

    return InkWell(
      onTap: () => _showNotificationDetailsSheet(evt, isDark),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderCol),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: App Icon + App Name/Subtext + Time + Status Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: subBoxBg,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: borderCol),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: iconBytes != null
                      ? Image.memory(
                          iconBytes,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                        )
                      : Icon(appIcon, size: 20, color: textMain),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        headerLabel,
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: textMain,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        time,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          color: textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: isBlocked
                        ? amber.withValues(alpha: 0.15)
                        : green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isBlocked
                          ? amber.withValues(alpha: 0.35)
                          : green.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isBlocked ? amber : green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isBlocked ? 'SILENCED' : 'ALLOWED',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: isBlocked ? amber : green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Middle: Notification Title & Message Details
            if (notifTitle.isNotEmpty && notifMessage.isNotEmpty) ...[
              Text(
                notifTitle,
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: textMain,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                notifMessage,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: textMuted,
                  height: 1.35,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ] else ...[
              Text(
                primaryLine,
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: textMain,
                  height: 1.35,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 10),

            // Bottom: Rule / Mute Reason Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: subBoxBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderCol),
              ),
              child: Row(
                children: [
                  Icon(
                    isBlocked ? Icons.block_rounded : Icons.check_circle_rounded,
                    size: 14,
                    color: isBlocked ? amber : green,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      reason,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: textMuted,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

