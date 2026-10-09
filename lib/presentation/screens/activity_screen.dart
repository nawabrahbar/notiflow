import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/repositories/schedule_repository.dart';
import '../widgets/stitch_header.dart';

/// Activity Log Screen matching Stitch Obsidian Signal redesign.
/// Displays audit trail of triaged notifications, 3 key metrics cards,
/// filter pills (All, Silenced, Allowed), and chronological events stream.
///
/// Starts completely clean with zero dummy activity, allowing users to
/// inspect live triaged notifications or purge the local session log at any time.
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

class ActivityScreenState extends State<ActivityScreen> {
  String _selectedFilter = 'all'; // 'all', 'silenced', 'allowed'
  final List<Map<String, dynamic>> _events = [];

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

  void _confirmClearActivity(BuildContext context, bool isDark, Color borderCol, Color textMain, Color textMuted) {
    if (_events.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Activity log is already empty.'),
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
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _events.clear();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Triage activity log cleared.'),
                  backgroundColor: Color(0xFFF59E0B),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF09090B) : const Color(0xFFF9F9FB);
    final cardBg = isDark ? const Color(0xFF18181B) : Colors.white;
    final borderCol = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E2E4);
    final textMain = isDark ? const Color(0xFFFAFAFA) : const Color(0xFF1A1C1D);
    final textMuted = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF47464B);
    final amber = const Color(0xFFF59E0B);

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
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            children: [
              Text(
                'Audit trail of triaged notifications',
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
                    subtitle: 'In last 24h',
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
                    _events.isEmpty ? 'Events' : 'Today · ${_filteredEvents.length} Events',
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
                          Icon(Icons.delete_sweep_rounded, size: 13, color: amber),
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
                        child: Icon(Icons.history_toggle_off_rounded, size: 28, color: amber),
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
                        'Triaged notifications will appear here in real time as your scheduled rules trigger.',
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
                        appIcon: evt['icon'] as IconData? ?? Icons.notifications_none_rounded,
                        appTitle: evt['title'] as String? ?? 'Notification',
                        time: evt['time'] as String? ?? 'Just now',
                        content: evt['content'] as String? ?? '',
                        isBlocked: evt['isBlocked'] as bool? ?? false,
                        reason: evt['reason'] as String? ?? 'Evaluated',
                        isDark: isDark,
                      ),
                    )),
              const SizedBox(height: 24),
            ],
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
    final amber = const Color(0xFFF59E0B);

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
    final amber = const Color(0xFFF59E0B);
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
    required IconData appIcon,
    required String appTitle,
    required String time,
    required String content,
    required bool isBlocked,
    required String reason,
    required bool isDark,
  }) {
    final cardBg = isDark ? const Color(0xFF18181B) : Colors.white;
    final borderCol = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E2E4);
    final textMain = isDark ? const Color(0xFFFAFAFA) : const Color(0xFF1A1C1D);
    final textMuted = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF47464B);
    final amber = const Color(0xFFF59E0B);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(appIcon, size: 18, color: textMain),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  appTitle,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: textMain,
                  ),
                ),
              ),
              Text(
                time,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  color: textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              color: textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isBlocked
                  ? (isDark ? const Color(0xFF272014) : const Color(0xFFFEF3C7))
                  : (isDark ? const Color(0xFF052E16) : const Color(0xFFDCFCE7)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isBlocked ? Icons.block_rounded : Icons.check_circle_rounded,
                  size: 12,
                  color: isBlocked ? amber : const Color(0xFF22C55E),
                ),
                const SizedBox(width: 5),
                Text(
                  reason,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isBlocked ? amber : const Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
