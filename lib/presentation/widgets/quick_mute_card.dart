import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/repositories/schedule_repository.dart';
import '../../domain/models/temporary_override.dart';
import '../theme/app_theme.dart';
import 'stitch_switch.dart';

/// "Quick Mute · All apps" dashboard section.
///
/// Mutes every app (managed and unmanaged, except paused ones) for a short
/// time through the shared `global_mute` override. While a mute runs, the
/// presets are replaced by a live status card with Extend and End now.
/// Used by both the phone and tablet dashboards.
class QuickMuteAllCard extends StatefulWidget {
  final ScheduleRepository repository;

  const QuickMuteAllCard({super.key, required this.repository});

  static const String overrideKey = 'global_mute';
  static const List<Duration> presets = [
    Duration(minutes: 15),
    Duration(minutes: 30),
    Duration(hours: 1),
  ];
  static const Duration extendStep = Duration(minutes: 15);

  @override
  State<QuickMuteAllCard> createState() => _QuickMuteAllCardState();
}

class _QuickMuteAllCardState extends State<QuickMuteAllCard> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && _activeMute != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  TemporaryOverride? get _activeMute => widget.repository.overrides
      .where((o) =>
          o.appId == QuickMuteAllCard.overrideKey &&
          o.mode == OverrideMode.block &&
          o.isActive)
      .firstOrNull;

  static String _presetLabel(Duration d) =>
      d.inMinutes >= 60 ? '${d.inHours}h' : '${d.inMinutes}m';

  static String _remainingLabel(DateTime end) {
    final secs = end.difference(DateTime.now()).inSeconds;
    if (secs < 60) return 'Less than a minute left';
    final mins = (secs / 60).ceil();
    if (mins < 60) return '$mins min left';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '${h}h left' : '${h}h ${m}m left';
  }

  static String _clock(BuildContext context, DateTime t) =>
      MaterialLocalizations.of(context).formatTimeOfDay(
        TimeOfDay.fromDateTime(t),
        alwaysUse24HourFormat: MediaQuery.of(context).alwaysUse24HourFormat,
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.repository,
      builder: (context, _) => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor =
        isDark ? AppTheme.darkOnSurfaceVariant : AppTheme.lightOnSurfaceVariant;
    final mute = _activeMute;

    return Column(
      key: const Key('quick_mute_all_card'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'QUICK MUTE · ALL APPS',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            color: labelColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Silences every app for a while, on top of your schedules.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: labelColor,
          ),
        ),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: mute == null
              ? _buildPresets(isDark)
              : _buildActive(context, isDark, mute),
        ),
        const SizedBox(height: 8),
        _buildRepeatCallerRow(isDark),
      ],
    );
  }

  Widget _buildPresets(bool isDark) {
    final children = <Widget>[];
    for (final d in QuickMuteAllCard.presets) {
      if (children.isNotEmpty) children.add(const SizedBox(width: 8));
      children.add(Expanded(
        child: _pill(
          isDark: isDark,
          key: Key('quick_mute_all_${d.inMinutes}'),
          icon: Icons.notifications_paused_outlined,
          label: _presetLabel(d),
          onTap: () => widget.repository.setTemporaryMute(
            appId: QuickMuteAllCard.overrideKey,
            duration: d,
          ),
        ),
      ));
    }
    return Row(key: const ValueKey('presets'), children: children);
  }

  Widget _buildActive(BuildContext context, bool isDark, TemporaryOverride mute) {
    final bg = isDark ? const Color(0xFF2E3B32) : AppTheme.lightSecondaryContainer;
    final fg = isDark ? const Color(0xFFC5D4BA) : AppTheme.lightOnSecondaryContainer;
    final strong = isDark ? AppTheme.darkOnSurface : AppTheme.lightOnSurface;
    final accent = isDark ? AppTheme.darkPrimaryContainer : AppTheme.lightPrimary;

    return Container(
      key: const ValueKey('active'),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: isDark ? Border.all(color: const Color(0xFF3A4B3F)) : null,
      ),
      child: Row(
        children: [
          Icon(Icons.notifications_paused_rounded, size: 22, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'All apps muted',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: strong,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_remainingLabel(mute.endDateTime)} · until ${_clock(context, mute.endDateTime)}',
                  key: const Key('quick_mute_all_remaining'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            key: const Key('quick_mute_all_extend'),
            onPressed: () => widget.repository.extendTemporaryMute(
              appId: QuickMuteAllCard.overrideKey,
              extra: QuickMuteAllCard.extendStep,
            ),
            style: TextButton.styleFrom(
              foregroundColor: accent,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 36),
            ),
            child: Text('+${_presetLabel(QuickMuteAllCard.extendStep)}',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, fontWeight: FontWeight.w700)),
          ),
          TextButton(
            key: const Key('quick_mute_all_end'),
            onPressed: () =>
                widget.repository.clearOverride(QuickMuteAllCard.overrideKey),
            style: TextButton.styleFrom(
              foregroundColor: strong,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 36),
            ),
            child: Text('End now',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildRepeatCallerRow(bool isDark) {
    final enabled = widget.repository.vipEmergencyBypass;
    // Soft green (secondary container) while on, neutral surface while off.
    final Color bg;
    final Color strong;
    final Color muted;
    final Color? border;
    if (isDark) {
      bg = enabled ? const Color(0xFF2E3B32) : const Color(0xFF1A211D);
      strong = enabled ? const Color(0xFFC5D4BA) : AppTheme.darkOnSurface;
      muted = enabled ? const Color(0xFFA7D4A3) : const Color(0xFF9AA79B);
      border = enabled ? const Color(0xFF3A4B3F) : const Color(0xFF2A362F);
    } else {
      bg = enabled ? AppTheme.lightSecondaryContainer : AppTheme.lightSurfaceContainer;
      strong = enabled ? AppTheme.lightSecondary : AppTheme.lightOnSurface;
      muted = enabled ? AppTheme.lightOnSecondaryContainer : AppTheme.lightOnSurfaceVariant;
      border = null;
    }

    return AnimatedContainer(
      key: const Key('quick_mute_all_repeat_callers_card'),
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: border == null ? null : Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(Icons.phone_callback_rounded, size: 18, color: muted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Let repeat callers ring through',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: strong,
                  ),
                ),
                Text(
                  'A 2nd call from the same person within 3 min rings',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: muted,
                  ),
                ),
              ],
            ),
          ),
          StitchSwitch(
            key: const Key('quick_mute_all_repeat_callers'),
            value: enabled,
            onChanged: (v) => widget.repository.setVipEmergencyBypass(v),
            activeTrackColor: isDark ? AppTheme.darkSecondary : AppTheme.lightSecondary,
          ),
        ],
      ),
    );
  }

  Widget _pill({
    required bool isDark,
    required Key key,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final bg = isDark ? const Color(0xFF1A211D) : AppTheme.lightSurfaceContainer;
    final fg = isDark ? const Color(0xFF9AA79B) : AppTheme.lightOnSurfaceVariant;
    return Material(
      key: key,
      color: bg,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: isDark
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF2A362F)),
                )
              : null,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
