import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/repositories/schedule_repository.dart';
import '../../domain/models/managed_app.dart';
import '../../domain/models/schedule_rule.dart';
import '../widgets/stitch_header.dart';
import '../widgets/stitch_switch.dart';
import 'main_navigation_shell.dart';
import 'schedule_editor_screen.dart';

/// App Details Screen matching Stitch Obsidian Signal redesign.
/// Features App profile, Master Switch, Real-Time Triage simulator card,
/// Quick Temporary Block override pills, and Active Schedule Rules list.
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
      listenable: repository,
      builder: (context, _) {
        final currentApp = repository.managedApps.firstWhere(
          (a) => a.id == app.id,
          orElse: () => app,
        );

        final rule = repository.getRuleForApp(app.id);
        final override = repository.getOverrideForApp(app.id);
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
            appBar: const StitchHeader(title: 'App Details'),
            body: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            children: [
              // Top Profile Card: App Icon, Name, Category, Master Switch
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderCol),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF27272A) : const Color(0xFFEEEEF0),
                        borderRadius: BorderRadius.circular(14),
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
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: textMain,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            currentApp.category ?? 'Applications',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11.5,
                              color: textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    StitchSwitch(
                      value: currentApp.enabled,
                      onChanged: (val) {
                        repository.toggleAppMonitoring(currentApp.id, val);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Real-Time Triage Status Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isSilenced
                      ? (isDark ? const Color(0xFF272014) : const Color(0xFFFEF3C7))
                      : (isDark ? const Color(0xFF052E16) : const Color(0xFFDCFCE7)),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSilenced ? amber : const Color(0xFF22C55E),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isSilenced ? Icons.shield_rounded : Icons.check_circle_rounded,
                              color: isSilenced ? amber : const Color(0xFF22C55E),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isSilenced ? 'CURRENT STATUS: SILENCED' : 'CURRENT STATUS: ALLOWED',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: isSilenced ? amber : const Color(0xFF16A34A),
                              ),
                            ),
                          ],
                        ),
                        if (override != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: amber,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'OVERRIDE',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF09090B),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isSilenced
                          ? 'Alerts strictly held in offline vault. Reason: ${decision.reason}.'
                          : 'Incoming notifications pass through. Reason: ${decision.reason}.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: isDark ? const Color(0xFFFAFAFA) : const Color(0xFF1A1C1D),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Quick Temporary Block (Instant Override Pills)
              Text(
                'QUICK TEMPORARY BLOCK · INSTANT OVERRIDE',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
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
                    onTap: () => repository.setTemporaryMute(appId: currentApp.id, duration: const Duration(minutes: 15)),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildOverridePill(
                    label: '30m Mute',
                    isActive: override?.durationMinutes == 30,
                    onTap: () => repository.setTemporaryMute(appId: currentApp.id, duration: const Duration(minutes: 30)),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildOverridePill(
                    label: '1h Mute',
                    isActive: override?.durationMinutes == 60,
                    onTap: () => repository.setTemporaryMute(appId: currentApp.id, duration: const Duration(hours: 1)),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildOverridePill(
                    label: 'Today 24h',
                    isActive: override?.durationMinutes == 1440,
                    onTap: () => repository.setTemporaryMute(appId: currentApp.id, duration: const Duration(hours: 24)),
                    isDark: isDark,
                  ),
                ],
              ),
              if (override != null) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => repository.clearOverride(currentApp.id),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Clear Temporary Override'),
                  style: TextButton.styleFrom(foregroundColor: amber),
                ),
              ],

              const SizedBox(height: 28),

              // Active Schedule Rules Header & List
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    rule != null ? 'Active Schedule Rules (1)' : 'Active Schedule Rules (0)',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textMain,
                    ),
                  ),
                  TextButton(
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (rule != null) ...[
                          Icon(Icons.edit_rounded, size: 16, color: amber),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          rule != null ? 'Edit Rule' : '+ Add Schedule',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: amber, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (rule == null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderCol),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.event_busy_rounded, color: textMuted, size: 36),
                      const SizedBox(height: 10),
                      Text(
                        'No schedule rules configured',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: textMain, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Set active focus hours to automatically quiet notifications.',
                        style: GoogleFonts.inter(fontSize: 12.5, color: textMuted),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await repository.deleteAppsAndRules([currentApp.id]);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Removed "${currentApp.displayName}" from Rules page!'),
                              backgroundColor: const Color(0xFFF59E0B),
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
                        icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                        label: const Text('Remove from Rules Page', style: TextStyle(color: Color(0xFFEF4444))),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFEF4444)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
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
                            rule.mode == ScheduleMode.blockDuring ? 'Block Schedule Window' : 'Allow Schedule Window',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: textMain,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: rule.mode == ScheduleMode.blockDuring
                                  ? (isDark ? const Color(0xFF272014) : const Color(0xFFFEF3C7))
                                  : (isDark ? const Color(0xFF052E16) : const Color(0xFFDCFCE7)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              rule.mode == ScheduleMode.blockDuring ? 'BLOCK MODE' : 'ALLOW MODE',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: rule.mode == ScheduleMode.blockDuring ? amber : const Color(0xFF22C55E),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Time range
                      Row(
                        children: [
                          Icon(Icons.schedule_rounded, size: 16, color: amber),
                          const SizedBox(width: 6),
                          Text(
                            '${rule.startTime.format12Hour()} — ${rule.endTime.format12Hour()}',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: textMain,
                            ),
                          ),
                          if (rule.isOvernight) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF27272A) : const Color(0xFFEEEEF0),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '+1 DAY',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: amber,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Day pills
                      Row(
                        children: [
                          _buildDayChip('M', rule.daysOfWeek.contains(1), isDark),
                          const SizedBox(width: 6),
                          _buildDayChip('T', rule.daysOfWeek.contains(2), isDark),
                          const SizedBox(width: 6),
                          _buildDayChip('W', rule.daysOfWeek.contains(3), isDark),
                          const SizedBox(width: 6),
                          _buildDayChip('T', rule.daysOfWeek.contains(4), isDark),
                          const SizedBox(width: 6),
                          _buildDayChip('F', rule.daysOfWeek.contains(5), isDark),
                          const SizedBox(width: 6),
                          _buildDayChip('S', rule.daysOfWeek.contains(6), isDark),
                          const SizedBox(width: 6),
                          _buildDayChip('S', rule.daysOfWeek.contains(7), isDark),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Delete rule button
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () async {
                            await repository.deleteRule(rule.id);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Rule deleted and "${currentApp.displayName}" removed from Rules page!',
                                ),
                                backgroundColor: const Color(0xFFF59E0B),
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
                          icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                          label: Text(
                            'Delete Rule',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFEF4444),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Bottom Return / Done Action
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: amber,
                    foregroundColor: const Color(0xFF09090B),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text(
                    'Done',
                    style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      );
    },
  );
}

  Widget _buildOverridePill({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final amber = const Color(0xFFF59E0B);
    final cardBg = isDark ? const Color(0xFF18181B) : Colors.white;
    final borderCol = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E2E4);
    final textMain = isDark ? const Color(0xFFFAFAFA) : const Color(0xFF1A1C1D);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive
                ? (isDark ? const Color(0xFF272014) : const Color(0xFFFEF3C7))
                : cardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive ? amber : borderCol,
              width: isActive ? 1.5 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isActive ? amber : textMain,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDayChip(String label, bool isSelected, bool isDark) {
    final amber = const Color(0xFFF59E0B);
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: isSelected
            ? amber
            : (isDark ? const Color(0xFF27272A) : const Color(0xFFEEEEF0)),
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isSelected ? const Color(0xFF09090B) : (isDark ? const Color(0xFFA1A1AA) : const Color(0xFF77767B)),
        ),
      ),
    );
  }
}
