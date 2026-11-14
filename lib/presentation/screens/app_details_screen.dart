import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/repositories/schedule_repository.dart';
import '../../domain/models/managed_app.dart';
import '../../domain/models/schedule_rule.dart';
import '../theme/app_theme.dart';
import '../widgets/stitch_header.dart';
import '../widgets/stitch_switch.dart';
import 'main_navigation_shell.dart';
import 'schedule_editor_screen.dart';

/// App Details Screen matching Botanical Sanctuary & Nocturne specifications:
/// - Seamless header (no bottom border, integrated canvas)
/// - Top App Profile card with real native app icon from PackageManager
/// - Real-Time Triage simulator card (Silenced / Permitted status)
/// - Quick temporary override mute pills (15m, 30m, 1h, Today 24h)
/// - Multi-Schedule Rules support: Active Schedule Rules (N) with individual toggles & delete actions
/// - Dashed "+ Add Schedule Rule" button to configure multiple schedules per app
class AppDetailsScreen extends StatelessWidget {
  final ScheduleRepository repository;
  final ManagedApp app;

  const AppDetailsScreen({
    super.key,
    required this.repository,
    required this.app,
  });

  IconData _getDefaultIconForApp(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('chat') ||
        lower.contains('whatsapp') ||
        lower.contains('telegram') ||
        lower.contains('message')) {
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
    final bg = isDark ? AppTheme.darkBackground : AppTheme.lightBackground;
    final cardBg = isDark ? AppTheme.darkSurfaceContainerLow : AppTheme.lightSurfaceContainerLow;
    final cardBgHighest = isDark ? AppTheme.darkSurfaceContainerHighest : AppTheme.lightSurfaceContainer;
    final borderCol = isDark ? AppTheme.darkOutlineVariant : AppTheme.lightOutlineVariant;
    final textMain = isDark ? AppTheme.darkOnSurface : AppTheme.lightOnSurface;
    final textMuted = isDark ? AppTheme.darkOnSurfaceVariant : AppTheme.lightOnSurfaceVariant;
    final primaryCol = isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary;
    final primaryContainerCol = isDark ? AppTheme.darkPrimaryContainer : AppTheme.lightPrimaryContainer;
    final secondaryContainerCol = isDark ? AppTheme.darkSecondaryContainer : AppTheme.lightSecondaryContainer;
    final onSecondaryContainerCol = isDark ? AppTheme.darkOnSecondaryContainer : AppTheme.lightOnSecondaryContainer;

    return ListenableBuilder(
      listenable: repository,
      builder: (context, _) {
        final currentApp = repository.managedApps.firstWhere(
          (a) => a.id == app.id,
          orElse: () => app,
        );

        final rules = repository.getRulesForApp(currentApp.id);
        final override = repository.getOverrideForApp(currentApp.id);
        final decision = repository.evaluateApp(currentApp);
        final isSilenced = decision.isBlocked;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => MainNavigationShell(repository: repository),
                ),
              );
            }
          },
          child: Scaffold(
            backgroundColor: bg,
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: Container(
                color: bg,
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top,
                  left: 8,
                  right: 16,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        } else {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => MainNavigationShell(repository: repository),
                            ),
                          );
                        }
                      },
                      icon: Icon(Icons.arrow_back_rounded, color: textMain),
                      tooltip: 'Back',
                    ),
                    Expanded(
                      child: Text(
                        'App Details',
                        style: GoogleFonts.newsreader(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: textMain,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    const StitchThemeSwitch(),
                  ],
                ),
              ),
            ),
            body: LayoutBuilder(
              builder: (context, constraints) {
                final isTablet = constraints.maxWidth >= 600;

                final leftCardColumn = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top Profile Card: App Icon, Name, Category, Master Switch
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderCol),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.darkSurfaceContainer : AppTheme.lightSurfaceContainer,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: borderCol, width: 1.0),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: currentApp.iconBytes != null
                                ? Image.memory(
                                    currentApp.iconBytes!,
                                    width: 52,
                                    height: 52,
                                    fit: BoxFit.cover,
                                  )
                                : Icon(
                                    _getDefaultIconForApp(currentApp.displayName),
                                    color: textMain,
                                    size: 26,
                                  ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentApp.displayName,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: textMain,
                                    letterSpacing: -0.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  currentApp.category ?? 'Applications',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          StitchSwitch(
                            value: currentApp.enabled,
                            onChanged: (val) => repository.toggleAppMonitoring(currentApp.id, val),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Real-Time Triage Status Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSilenced
                            ? (isDark
                                ? AppTheme.signalHeld.withValues(alpha: 0.12)
                                : const Color(0xFFFEE2E2))
                            : (isDark
                                ? AppTheme.signalSuccess.withValues(alpha: 0.12)
                                : const Color(0xFFDCFCE7)),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSilenced
                              ? AppTheme.signalHeld.withValues(alpha: 0.4)
                              : AppTheme.signalSuccess.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSilenced ? Icons.do_not_disturb_on_rounded : Icons.check_circle_rounded,
                            color: isSilenced ? AppTheme.signalHeld : AppTheme.signalSuccess,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      isSilenced ? 'Currently Silenced' : 'Currently Permitted',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                        color: textMain,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isSilenced
                                            ? AppTheme.signalHeld.withValues(alpha: 0.2)
                                            : AppTheme.signalSuccess.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        isSilenced ? 'MUTED' : 'ALERTS',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
                                          color: isSilenced ? AppTheme.signalHeld : AppTheme.signalSuccess,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  decision.reason,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12.5,
                                    color: textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    // Quick Temporary Override Pills
                    Text(
                      'QUICK TEMPORARY OVERRIDE',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: textMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildOverridePill(
                          label: '15m Mute',
                          isActive: override?.durationMinutes == 15,
                          onTap: () => repository.setTemporaryMute(
                            appId: currentApp.id,
                            duration: const Duration(minutes: 15),
                          ),
                          isDark: isDark,
                          primaryCol: primaryCol,
                          cardBg: cardBg,
                          borderCol: borderCol,
                          textMain: textMain,
                        ),
                        const SizedBox(width: 8),
                        _buildOverridePill(
                          label: '30m Mute',
                          isActive: override?.durationMinutes == 30,
                          onTap: () => repository.setTemporaryMute(
                            appId: currentApp.id,
                            duration: const Duration(minutes: 30),
                          ),
                          isDark: isDark,
                          primaryCol: primaryCol,
                          cardBg: cardBg,
                          borderCol: borderCol,
                          textMain: textMain,
                        ),
                        const SizedBox(width: 8),
                        _buildOverridePill(
                          label: '1h Mute',
                          isActive: override?.durationMinutes == 60,
                          onTap: () => repository.setTemporaryMute(
                            appId: currentApp.id,
                            duration: const Duration(hours: 1),
                          ),
                          isDark: isDark,
                          primaryCol: primaryCol,
                          cardBg: cardBg,
                          borderCol: borderCol,
                          textMain: textMain,
                        ),
                        const SizedBox(width: 8),
                        _buildOverridePill(
                          label: 'Today 24h',
                          isActive: override?.durationMinutes == 1440,
                          onTap: () => repository.setTemporaryMute(
                            appId: currentApp.id,
                            duration: const Duration(hours: 24),
                          ),
                          isDark: isDark,
                          primaryCol: primaryCol,
                          cardBg: cardBg,
                          borderCol: borderCol,
                          textMain: textMain,
                        ),
                      ],
                    ),
                    if (override != null) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => repository.clearOverride(currentApp.id),
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Clear Temporary Override'),
                        style: TextButton.styleFrom(foregroundColor: primaryCol),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Destructive "Remove from Rules Page" Button
                    OutlinedButton.icon(
                      onPressed: () async {
                        await repository.deleteAppsAndRules([currentApp.id]);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            SnackBar(
                              content: Text(
                                'Removed "${currentApp.displayName}" from Rules page!',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              backgroundColor: AppTheme.signalWarning,
                            ),
                          );
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        } else {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => MainNavigationShell(repository: repository),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.delete_sweep_rounded, size: 18, color: Color(0xFFEF4444)),
                      label: const Text('Remove from Rules Page', style: TextStyle(color: Color(0xFFEF4444))),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFEF4444), width: 1.0),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ],
                );

                final rightRulesColumn = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Active Schedule Rules (N) Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Active Schedule Rules (${rules.length})',
                          style: GoogleFonts.newsreader(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: textMain,
                            letterSpacing: -0.2,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ScheduleEditorScreen(
                                  repository: repository,
                                  targetApp: currentApp,
                                  existingRule: null,
                                ),
                              ),
                            );
                          },
                          icon: Icon(Icons.add_rounded, size: 18, color: primaryCol),
                          label: Text(
                            'Add Rule',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              color: primaryCol,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Multi-Schedule Rules List
                    if (rules.isEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderCol),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.event_busy_rounded, color: textMuted, size: 36),
                            const SizedBox(height: 10),
                            Text(
                              'No schedule rules configured',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                color: textMain,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Define custom quiet hours to automatically silence notifications.',
                              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: textMuted),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      ...rules.map((rule) {
                        final isBlock = rule.mode == ScheduleMode.blockDuring ||
                            rule.mode == ScheduleMode.allDayBlock;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderCol),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ScheduleEditorScreen(
                                            repository: repository,
                                            targetApp: currentApp,
                                            existingRule: rule,
                                          ),
                                        ),
                                      );
                                    },
                                    behavior: HitTestBehavior.opaque,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.schedule_rounded,
                                          size: 18,
                                          color: primaryCol,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${repository.formatTime(rule.startTime)} → ${repository.formatTime(rule.endTime)}',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: textMain,
                                          ),
                                        ),
                                        if (rule.isOvernight) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: cardBgHighest,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '+1 DAY',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w700,
                                                color: primaryCol,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  StitchSwitch(
                                    value: rule.enabled,
                                    onChanged: (val) => repository.toggleRuleEnabled(rule.id, val),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isBlock
                                              ? secondaryContainerCol
                                              : (isDark
                                                  ? const Color(0xFF052E16)
                                                  : const Color(0xFFDCFCE7)),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 5,
                                              height: 5,
                                              decoration: BoxDecoration(
                                                color: isBlock
                                                    ? onSecondaryContainerCol
                                                    : const Color(0xFF22C55E),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              isBlock ? 'Silent Hold' : 'Allow Window',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w700,
                                                color: isBlock
                                                    ? onSecondaryContainerCol
                                                    : const Color(0xFF16A34A),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _formatDaysSummary(rule.daysOfWeek),
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          color: textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.edit_outlined, size: 18, color: textMuted),
                                        tooltip: 'Edit Schedule',
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => ScheduleEditorScreen(
                                                repository: repository,
                                                targetApp: currentApp,
                                                existingRule: rule,
                                              ),
                                            ),
                                          );
                                        },
                                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                        padding: EdgeInsets.zero,
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          size: 18,
                                          color: Color(0xFFEF4444),
                                        ),
                                        tooltip: 'Delete Rule',
                                        onPressed: () async {
                                          await repository.deleteRule(rule.id);
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(context)
                                            ..hideCurrentSnackBar()
                                            ..showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Schedule rule removed.',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                backgroundColor: AppTheme.signalSuccess,
                                              ),
                                            );
                                        },
                                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                        padding: EdgeInsets.zero,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                    ],

                    const SizedBox(height: 12),

                    // Dashed "+ Add Schedule Rule" Card Button
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ScheduleEditorScreen(
                              repository: repository,
                              targetApp: currentApp,
                              existingRule: null,
                            ),
                          ),
                        );
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: primaryCol.withValues(alpha: 0.5),
                            style: BorderStyle.solid,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: primaryCol.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.add_circle_outline_rounded,
                                color: primaryCol,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Add Schedule Rule',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                      color: textMain,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Define custom quiet hours & focus',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      color: textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded, color: textMuted, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                );

                if (isTablet) {
                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 5, child: leftCardColumn),
                          const SizedBox(width: 24),
                          Expanded(flex: 7, child: rightRulesColumn),
                        ],
                      ),
                      const SizedBox(height: 32),
                    ],
                  );
                }

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  children: [
                    leftCardColumn,
                    const SizedBox(height: 28),
                    rightRulesColumn,
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

  String _formatDaysSummary(Set<int> days) {
    if (days.length == 7) return 'Everyday';
    if (days.length == 5 &&
        days.contains(1) &&
        days.contains(2) &&
        days.contains(3) &&
        days.contains(4) &&
        days.contains(5)) {
      return 'Mon-Fri';
    }
    if (days.length == 2 && days.contains(6) && days.contains(7)) {
      return 'Weekends';
    }
    return '${days.length} days/wk';
  }

  Widget _buildOverridePill({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    required bool isDark,
    required Color primaryCol,
    required Color cardBg,
    required Color borderCol,
    required Color textMain,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive
                ? (isDark ? primaryCol.withValues(alpha: 0.25) : primaryCol.withValues(alpha: 0.15))
                : cardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive ? primaryCol : borderCol,
              width: isActive ? 1.5 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isActive ? primaryCol : textMain,
            ),
          ),
        ),
      ),
    );
  }
}
