import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/repositories/schedule_repository.dart';
import '../../domain/models/managed_app.dart';
import '../../domain/models/schedule_rule.dart';
import '../../domain/models/temporary_override.dart';
import '../theme/app_theme.dart';
import '../widgets/stitch_header.dart';
import '../widgets/stitch_switch.dart';
import '../widgets/app_toast.dart';
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
    return Icons.apps_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkBackground : AppTheme.lightBackground;
    final cardBg = isDark
        ? AppTheme.darkSurfaceContainerLow
        : AppTheme.lightSurfaceContainerLow;
    final cardBgHighest = isDark
        ? AppTheme.darkSurfaceContainerHighest
        : AppTheme.lightSurfaceContainer;
    final borderCol = isDark
        ? AppTheme.darkOutlineVariant
        : AppTheme.lightOutlineVariant;
    final textMain = isDark ? AppTheme.darkOnSurface : AppTheme.lightOnSurface;
    final textMuted = isDark
        ? AppTheme.darkOnSurfaceVariant
        : AppTheme.lightOnSurfaceVariant;
    final primaryCol = isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary;
    final secondaryContainerCol = isDark
        ? AppTheme.darkSecondaryContainer
        : AppTheme.lightSecondaryContainer;
    final onSecondaryContainerCol = isDark
        ? AppTheme.darkOnSecondaryContainer
        : AppTheme.lightOnSecondaryContainer;

    return ListenableBuilder(
      listenable: repository,
      builder: (context, _) {
        final currentApp = repository.managedApps.firstWhere(
          (a) => a.id == app.id,
          orElse: () => app,
        );

        final rules = repository.getRulesForApp(currentApp.id);
        final override = repository.getOverrideForApp(currentApp.id);

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => MainNavigationShell(
                    repository: repository,
                    initialIndex: MainNavigationShell.rulesTab,
                  ),
                ),
              );
            }
          },
          child: Scaffold(
            backgroundColor: bg,
            floatingActionButton: FloatingActionButton.extended(
              key: const ValueKey('app-details-done-fab'),
              heroTag: 'app-details-done-fab',
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => MainNavigationShell(
                        repository: repository,
                        initialIndex: MainNavigationShell.rulesTab,
                      ),
                    ),
                  );
                }
              },
              backgroundColor: primaryCol,
              foregroundColor: isDark
                  ? AppTheme.darkOnPrimary
                  : AppTheme.lightOnPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              icon: const Icon(Icons.check_rounded, size: 20),
              label: Text(
                'Done',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: Container(
                color: bg,
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top,
                  left: 20,
                  right: 16,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'App Details',
                        style: AppTheme.headerTitleStyle(context, textMain),
                      ),
                    ),
                    const StitchThemeSwitch(),
                  ],
                ),
              ),
            ),
            body: HeaderScrollTransition(
              child: LayoutBuilder(
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
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.2 : 0.03,
                            ),
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
                              color: isDark
                                  ? AppTheme.darkSurfaceContainer
                                  : AppTheme.lightSurfaceContainer,
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
                                    _getDefaultIconForApp(
                                      currentApp.displayName,
                                    ),
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
                            onChanged: (val) => repository.toggleAppMonitoring(
                              currentApp.id,
                              val,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    // Quick Temporary Block
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'QUICK TEMPORARY BLOCK',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: textMuted,
                            ),
                          ),
                        ),
                        if (override != null && override.isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppTheme.signalHeld.withValues(alpha: 0.2)
                                  : const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: AppTheme.signalHeld.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                            ),
                            child: Text(
                              _formatRemainingBadge(override.remainingMinutes),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: AppTheme.signalHeld,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Builder(
                      builder: (context) {
                        final isStandardPill =
                            override != null &&
                            override.mode == OverrideMode.block &&
                            (override.durationMinutes == 15 ||
                                override.durationMinutes == 30 ||
                                override.durationMinutes == 60);

                        final isCustomActive =
                            override != null &&
                            override.mode == OverrideMode.block &&
                            !isStandardPill;

                        final customHours = isCustomActive
                            ? (override.durationMinutes / 60).round()
                            : null;
                        final customPillLabel = isCustomActive
                            ? (customHours != null && customHours >= 1
                                  ? '${customHours}h Mute'
                                  : '${override.durationMinutes}m Mute')
                            : '+ Custom';

                        return Row(
                          children: [
                            _buildOverridePill(
                              label: '15m Mute',
                              isActive:
                                  override?.mode == OverrideMode.block &&
                                  override?.durationMinutes == 15,
                              onTap: () {
                                if (override?.mode == OverrideMode.block &&
                                    override?.durationMinutes == 15) {
                                  repository.clearOverride(currentApp.id);
                                  AppToast.show(
                                    context,
                                    message:
                                        'Cleared temporary override for "${currentApp.displayName}"',
                                    type: AppToastType.info,
                                  );
                                } else {
                                  repository.setTemporaryMute(
                                    appId: currentApp.id,
                                    duration: const Duration(minutes: 15),
                                  );
                                  AppToast.show(context, message: 'Muted "${currentApp.displayName}" for 15 minutes');
                                }
                              },
                              isDark: isDark,
                              primaryCol: primaryCol,
                              cardBg: cardBg,
                              borderCol: borderCol,
                              textMain: textMain,
                            ),
                            const SizedBox(width: 8),
                            _buildOverridePill(
                              label: '30m Mute',
                              isActive:
                                  override?.mode == OverrideMode.block &&
                                  override?.durationMinutes == 30,
                              onTap: () {
                                if (override?.mode == OverrideMode.block &&
                                    override?.durationMinutes == 30) {
                                  repository.clearOverride(currentApp.id);
                                  AppToast.show(
                                    context,
                                    message:
                                        'Cleared temporary override for "${currentApp.displayName}"',
                                    type: AppToastType.info,
                                  );
                                } else {
                                  repository.setTemporaryMute(
                                    appId: currentApp.id,
                                    duration: const Duration(minutes: 30),
                                  );
                                  AppToast.show(context, message: 'Muted "${currentApp.displayName}" for 30 minutes');
                                }
                              },
                              isDark: isDark,
                              primaryCol: primaryCol,
                              cardBg: cardBg,
                              borderCol: borderCol,
                              textMain: textMain,
                            ),
                            const SizedBox(width: 8),
                            _buildOverridePill(
                              label: '1h Mute',
                              isActive:
                                  override?.mode == OverrideMode.block &&
                                  override?.durationMinutes == 60,
                              onTap: () {
                                if (override?.mode == OverrideMode.block &&
                                    override?.durationMinutes == 60) {
                                  repository.clearOverride(currentApp.id);
                                  AppToast.show(
                                    context,
                                    message:
                                        'Cleared temporary override for "${currentApp.displayName}"',
                                    type: AppToastType.info,
                                  );
                                } else {
                                  repository.setTemporaryMute(
                                    appId: currentApp.id,
                                    duration: const Duration(hours: 1),
                                  );
                                  AppToast.show(context, message: 'Muted "${currentApp.displayName}" for 1 hour');
                                }
                              },
                              isDark: isDark,
                              primaryCol: primaryCol,
                              cardBg: cardBg,
                              borderCol: borderCol,
                              textMain: textMain,
                            ),
                            const SizedBox(width: 8),
                            _buildOverridePill(
                              label: customPillLabel,
                              isActive: isCustomActive,
                              onTap: () {
                                if (isCustomActive) {
                                  repository.clearOverride(currentApp.id);
                                  AppToast.show(
                                    context,
                                    message:
                                        'Cleared temporary override for "${currentApp.displayName}"',
                                    type: AppToastType.info,
                                  );
                                } else {
                                  _showCustomMuteDialog(
                                    context,
                                    repository,
                                    currentApp,
                                    isDark: isDark,
                                    primaryCol: primaryCol,
                                    cardBg: cardBg,
                                    borderCol: borderCol,
                                    textMain: textMain,
                                    textMuted: textMuted,
                                  );
                                }
                              },
                              isDark: isDark,
                              primaryCol: primaryCol,
                              cardBg: cardBg,
                              borderCol: borderCol,
                              textMain: textMain,
                            ),
                          ],
                        );
                      },
                    ),
                    if (override != null) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () {
                          repository.clearOverride(currentApp.id);
                          AppToast.show(
                            context,
                            message:
                                'Cleared temporary override for "${currentApp.displayName}"',
                            type: AppToastType.info,
                          );
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Clear Temporary Override'),
                        style: TextButton.styleFrom(
                          foregroundColor: primaryCol,
                        ),
                      ),
                    ],
                  ],
                );

                final rightRulesColumn = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Active Schedule Rules (N) Section
                    Text(
                      'ACTIVE SCHEDULE RULES (${rules.length})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Multi-Schedule Rules List
                    if (rules.isEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 28,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderCol),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: isDark ? 0.2 : 0.03,
                              ),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.event_busy_rounded,
                              color: textMuted,
                              size: 36,
                            ),
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
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: textMuted,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      ...rules.map((rule) {
                        final isBlock =
                            rule.mode == ScheduleMode.blockDuring ||
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
                                color: Colors.black.withValues(
                                  alpha: isDark ? 0.2 : 0.03,
                                ),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                ScheduleEditorScreen(
                                                  repository: repository,
                                                  targetApp: currentApp,
                                                  existingRule: rule,
                                                ),
                                          ),
                                        );
                                      },
                                      behavior: HitTestBehavior.opaque,
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              color: secondaryContainerCol
                                                  .withValues(alpha: 0.7),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: onSecondaryContainerCol
                                                    .withValues(alpha: 0.25),
                                              ),
                                            ),
                                            child: Icon(
                                              rule.isOvernight
                                                  ? Icons.nights_stay_rounded
                                                  : Icons.schedule_rounded,
                                              size: 18,
                                              color: onSecondaryContainerCol,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  (rule.name != null &&
                                                          rule.name!
                                                              .trim()
                                                              .isNotEmpty)
                                                      ? rule.name!.trim()
                                                      : (isBlock
                                                            ? 'Silent Hold Window'
                                                            : 'Allow Window'),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style:
                                                      GoogleFonts.plusJakartaSans(
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: textMain,
                                                      ),
                                                ),
                                                const SizedBox(height: 2),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.schedule_rounded,
                                                      size: 13,
                                                      color: textMuted,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Flexible(
                                                      child: Text(
                                                        '${repository.formatTime(rule.startTime)} → ${repository.formatTime(rule.endTime)}',
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style:
                                                            GoogleFonts.plusJakartaSans(
                                                              fontSize: 12.5,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                              color: textMuted,
                                                            ),
                                                      ),
                                                    ),
                                                    if (rule.isOvernight) ...[
                                                      const SizedBox(width: 6),
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 5,
                                                              vertical: 1,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: cardBgHighest,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                4,
                                                              ),
                                                        ),
                                                        child: Text(
                                                          '+1 DAY',
                                                          style:
                                                              GoogleFonts.plusJakartaSans(
                                                                fontSize: 9,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                color:
                                                                    primaryCol,
                                                              ),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  StitchSwitch(
                                    value: rule.enabled,
                                    onChanged: (val) => repository
                                        .toggleRuleEnabled(rule.id, val),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isBlock
                                                ? secondaryContainerCol
                                                : (isDark
                                                      ? const Color(0xFF052E16)
                                                      : const Color(
                                                          0xFFDCFCE7,
                                                        )),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
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
                                                isBlock
                                                    ? 'Silent Hold'
                                                    : 'Allow Window',
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
                                        Flexible(
                                          child: Text(
                                            _formatDaysSummary(rule.daysOfWeek),
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
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          Icons.edit_outlined,
                                          size: 18,
                                          color: textMuted,
                                        ),
                                        tooltip: 'Edit Schedule',
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  ScheduleEditorScreen(
                                                    repository: repository,
                                                    targetApp: currentApp,
                                                    existingRule: rule,
                                                  ),
                                            ),
                                          );
                                        },
                                        constraints: const BoxConstraints(
                                          minWidth: 32,
                                          minHeight: 32,
                                        ),
                                        padding: EdgeInsets.zero,
                                        style: const ButtonStyle(
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
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
                                          AppToast.show(
                                            context,
                                            message: 'Schedule rule removed.',
                                          );
                                        },
                                        constraints: const BoxConstraints(
                                          minWidth: 32,
                                          minHeight: 32,
                                        ),
                                        padding: EdgeInsets.zero,
                                        alignment: Alignment.centerRight,
                                        style: const ButtonStyle(
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
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
                              color: Colors.black.withValues(
                                alpha: isDark ? 0.2 : 0.03,
                              ),
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
                            Icon(
                              Icons.chevron_right_rounded,
                              color: textMuted,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );

                // Destructive "Remove from Rules Page" Button
                final removeFromRulesButton = OutlinedButton.icon(
                  onPressed: () async {
                    await repository.deleteAppsAndRules([currentApp.id]);
                    if (!context.mounted) return;
                    AppToast.show(
                      context,
                      message:
                          'Removed "${currentApp.displayName}" from Rules page!',
                    );
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    } else {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => MainNavigationShell(
                            repository: repository,
                            initialIndex: MainNavigationShell.rulesTab,
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(
                    Icons.delete_sweep_rounded,
                    size: 18,
                    color: Color(0xFFEF4444),
                  ),
                  label: const Text(
                    'Remove from Rules Page',
                    style: TextStyle(color: Color(0xFFEF4444)),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: Color(0xFFEF4444),
                      width: 1.0,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                );

                if (isTablet) {
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(28, 16, 28, 96),
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 5, child: leftCardColumn),
                          const SizedBox(width: 24),
                          Expanded(flex: 7, child: rightRulesColumn),
                        ],
                      ),
                      const SizedBox(height: 20),
                      removeFromRulesButton,
                    ],
                  );
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
                  children: [
                    leftCardColumn,
                    const SizedBox(height: 28),
                    rightRulesColumn,
                    const SizedBox(height: 20),
                    removeFromRulesButton,
                  ],
                );
              },
            ),
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

  String _formatRemainingBadge(int minutes) {
    if (minutes < 1) return '1m LEFT';
    if (minutes < 60) return '${minutes}m LEFT';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h LEFT' : '${h}h ${m}m LEFT';
  }

  Future<void> _showCustomMuteDialog(
    BuildContext context,
    ScheduleRepository repository,
    ManagedApp app, {
    required bool isDark,
    required Color primaryCol,
    required Color cardBg,
    required Color borderCol,
    required Color textMain,
    required Color textMuted,
  }) async {
    int selectedHours = 3;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final now = DateTime.now();
            final endTime = now.add(Duration(hours: selectedHours));
            final formattedEndTime = repository.formatTimeOfDay(
              endTime.hour,
              endTime.minute,
            );

            const quickPresets = [2, 3, 4, 8, 12, 24];

            return AlertDialog(
              backgroundColor: cardBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: borderCol),
              ),
              contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryCol.withValues(alpha: isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.hourglass_top_rounded,
                      color: primaryCol,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Custom Mute Duration',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: textMain,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Silence notifications for ${app.displayName}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      'QUICK SELECT',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: quickPresets.map((h) {
                        final isSelected = selectedHours == h;
                        final label = h == 8
                            ? '8h Work'
                            : (h == 24 ? '24h Day' : '${h}h');
                        return ChoiceChip(
                          label: Text(label),
                          labelStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: isSelected ? primaryCol : textMain,
                          ),
                          selected: isSelected,
                          onSelected: (_) =>
                              setDialogState(() => selectedHours = h),
                          backgroundColor: isDark
                              ? AppTheme.darkSurfaceContainerHigh
                              : AppTheme.lightSurfaceContainerHigh,
                          selectedColor: isDark
                              ? primaryCol.withValues(alpha: 0.25)
                              : primaryCol.withValues(alpha: 0.15),
                          side: BorderSide(
                            color: isSelected ? primaryCol : borderCol,
                            width: isSelected ? 1.5 : 1.0,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          showCheckmark: false,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.darkSurfaceContainerHigh
                            : AppTheme.lightSurfaceContainerHigh,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderCol),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: selectedHours > 2
                                ? () => setDialogState(() => selectedHours--)
                                : null,
                            icon: const Icon(
                              Icons.remove_circle_outline_rounded,
                            ),
                            color: primaryCol,
                            disabledColor: textMuted.withValues(alpha: 0.3),
                            tooltip: 'Decrease 1 hour',
                          ),
                          Flexible(
                            child: Column(
                              children: [
                                Text(
                                  '$selectedHours Hours',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: textMain,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Muted until $formattedEndTime',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: primaryCol,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: selectedHours < 24
                                ? () => setDialogState(() => selectedHours++)
                                : null,
                            icon: const Icon(Icons.add_circle_outline_rounded),
                            color: primaryCol,
                            disabledColor: textMuted.withValues(alpha: 0.3),
                            tooltip: 'Increase 1 hour',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                      color: textMuted,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.of(dialogContext).pop();
                    await repository.setTemporaryMute(
                      appId: app.id,
                      duration: Duration(hours: selectedHours),
                    );
                    if (!context.mounted) return;
                    AppToast.show(context, message: 'Muted "${app.displayName}" for $selectedHours hours');
                  },
                  icon: const Icon(Icons.do_not_disturb_on_rounded, size: 16),
                  label: Text(
                    'Mute for $selectedHours hrs',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryCol,
                    foregroundColor: isDark
                        ? AppTheme.darkBackground
                        : Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
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
    IconData? icon,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: isActive
                ? (isDark
                      ? primaryCol.withValues(alpha: 0.25)
                      : primaryCol.withValues(alpha: 0.15))
                : cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? primaryCol : borderCol,
              width: isActive ? 1.5 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: isActive ? primaryCol : textMain),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isActive ? primaryCol : textMain,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
