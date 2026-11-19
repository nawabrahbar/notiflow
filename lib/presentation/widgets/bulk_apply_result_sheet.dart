import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/repositories/schedule_repository.dart';
import '../../data/services/installed_apps_cache.dart';
import '../../domain/models/bulk_apply.dart';
import '../../domain/models/schedule_rule.dart';
import '../theme/app_theme.dart';
import 'app_toast.dart';

/// Shows what an Apply Rules batch added, with per-rule ×, per-app × and
/// Undo all. Every removal touches only schedules this batch created.
Future<void> showBulkApplyResultSheet(
  BuildContext context,
  BulkApplyResult result, {
  required ScheduleRepository repository,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) => BulkApplyResultSheet(result: result, repository: repository),
  );
}

class BulkApplyResultSheet extends StatefulWidget {
  final BulkApplyResult result;
  final ScheduleRepository repository;

  const BulkApplyResultSheet({
    super.key,
    required this.result,
    required this.repository,
  });

  @override
  State<BulkApplyResultSheet> createState() => _BulkApplyResultSheetState();
}

class _BulkApplyResultSheetState extends State<BulkApplyResultSheet> {
  late final Set<String> _addedAppIds = {
    for (final a in widget.result.apps)
      if (a.appAdded) a.app.id,
  };
  late final Set<String> _historyAppIds = {
    for (final a in widget.result.apps)
      if (a.wasHistoryOnly) a.app.id,
  };

  @override
  void initState() {
    super.initState();
    final missing = [
      for (final a in widget.result.apps)
        if (a.app.iconBytes == null) a.app.packageName,
    ];
    if (missing.isNotEmpty) InstalledAppsCache.instance.loadIcons(missing);
  }

  String _plural(int n, String word) => '$n $word${n == 1 ? '' : 's'}';

  /// Batch schedules for [app] that still exist (they may have been removed
  /// here or elsewhere).
  List<ScheduleRule> _live(BulkApplyAppResult app) {
    final ids = {for (final r in widget.repository.schedules) r.id};
    return [
      for (final r in app.addedRules)
        if (ids.contains(r.id)) r,
    ];
  }

  Future<bool> _confirm(String title, String body, String action) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMain = isDark ? AppTheme.darkOnSurface : AppTheme.lightOnSurface;
    final textMuted = isDark
        ? AppTheme.darkOnSurfaceVariant
        : AppTheme.lightOnSurfaceVariant;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark
            ? AppTheme.darkSurfaceContainerLow
            : AppTheme.lightSurfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          title,
          style: GoogleFonts.newsreader(
            fontWeight: FontWeight.w600,
            fontSize: 20,
            color: textMain,
          ),
        ),
        content: Text(
          body,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            height: 1.45,
            color: textMuted,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(
                color: textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            key: const ValueKey('bulk-result-confirm'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.signalError,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              action,
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _removeRule(BulkApplyAppResult app, ScheduleRule rule) async {
    final name = app.app.displayName;
    final ruleName = rule.name ?? 'this rule';
    final lastOfAdded = app.appAdded && _live(app).length == 1;
    final ok = await _confirm(
      'Remove $ruleName?',
      lastOfAdded
          ? '$ruleName will be removed from $name. $name was added by this '
                'batch, so it will be removed from Notiflow too.'
          : '$ruleName will be removed from $name. Its other schedules stay.',
      'Remove',
    );
    if (!ok || !mounted) return;
    await widget.repository.removeBulkAppliedRules(
      [rule.id],
      addedAppIds: _addedAppIds,
      historyAppIds: _historyAppIds,
    );
    if (!mounted) return;
    AppToast.show(context, message: 'Removed $ruleName from $name');
  }

  Future<void> _undoApp(BulkApplyAppResult app) async {
    final name = app.app.displayName;
    final live = _live(app);
    final ok = await _confirm(
      'Undo for $name?',
      app.appAdded
          ? 'Removes the ${_plural(live.length, 'schedule')} this batch '
                'added and removes $name from Notiflow, since it was added by '
                'this batch.'
          : 'Removes the ${_plural(live.length, 'schedule')} this batch added '
                'to $name. Schedules it already had stay.',
      'Undo',
    );
    if (!ok || !mounted) return;
    await widget.repository.removeBulkAppliedRules(
      live.map((r) => r.id),
      addedAppIds: _addedAppIds,
      historyAppIds: _historyAppIds,
    );
    if (!mounted) return;
    AppToast.show(context, message: 'Undid changes to $name');
  }

  Future<void> _undoAll() async {
    final live = [for (final a in widget.result.apps) ..._live(a)];
    if (live.isEmpty) return;
    final ok = await _confirm(
      'Undo everything?',
      'Removes all ${_plural(live.length, 'schedule')} this batch added. '
          'Schedules your apps already had are not touched.',
      'Undo all',
    );
    if (!ok || !mounted) return;
    await widget.repository.removeBulkAppliedRules(
      live.map((r) => r.id),
      addedAppIds: _addedAppIds,
      historyAppIds: _historyAppIds,
    );
    if (!mounted) return;
    AppToast.show(
      context,
      message: 'Undid ${_plural(live.length, 'schedule')}',
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? AppTheme.darkSurfaceContainerLow
        : AppTheme.lightSurfaceContainerLow;
    final textMain = isDark ? AppTheme.darkOnSurface : AppTheme.lightOnSurface;
    final textMuted = isDark
        ? AppTheme.darkOnSurfaceVariant
        : AppTheme.lightOnSurfaceVariant;
    final primary = isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary;
    final onPrimary = isDark ? AppTheme.darkOnPrimary : AppTheme.lightOnPrimary;
    final secContainer = isDark
        ? AppTheme.darkSecondaryContainer
        : AppTheme.lightSecondaryContainer;
    final onSecContainer = isDark
        ? AppTheme.darkOnSecondaryContainer
        : AppTheme.lightOnSecondaryContainer;
    final rowBg = (isDark
            ? AppTheme.darkSurfaceContainer
            : AppTheme.lightSurfaceContainer)
        .withValues(alpha: 0.7);
    final high = isDark
        ? AppTheme.darkSurfaceContainerHigh
        : AppTheme.lightSurfaceContainerHigh;
    final borderCol = isDark
        ? AppTheme.darkOutlineVariant.withValues(alpha: 0.3)
        : AppTheme.lightOutlineVariant.withValues(alpha: 0.35);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    return ListenableBuilder(
      listenable: Listenable.merge(
        [widget.repository, InstalledAppsCache.instance],
      ),
      builder: (context, _) {
        final rows = [
          for (final a in widget.result.apps)
            (app: a, live: _live(a)),
        ];
        final liveTotal = rows.fold<int>(0, (s, r) => s + r.live.length);
        final appsTouched = rows.where((r) => r.live.isNotEmpty).length;
        final skipped = widget.result.skippedCount;
        final summary = [
          _plural(liveTotal, 'new schedule'),
          _plural(appsTouched, 'app'),
          if (skipped > 0) '$skipped already applied',
        ].join(' · ');
        final visible = rows
            .where((r) => r.live.isNotEmpty || r.app.skipped.isNotEmpty)
            .toList();

        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Container(
            decoration: BoxDecoration(
              color: bg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: borderCol),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 16, 22, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: high,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: secContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.check_rounded,
                                  color: onSecContainer, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Rules applied',
                                    style: GoogleFonts.newsreader(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w600,
                                      color: textMain,
                                    ),
                                  ),
                                  Text(
                                    summary,
                                    key: const ValueKey('bulk-result-line'),
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
                        const SizedBox(height: 10),
                        Text(
                          'Tap × to remove a rule from one app, or undo a '
                          'whole app. Only schedules added just now are removed.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            height: 1.4,
                            color: textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: visible.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 22, vertical: 20),
                            child: Text(
                              'Nothing from this batch is left.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: textMuted,
                              ),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
                            itemCount: visible.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final row = visible[i];
                              final a = row.app;
                              final icon = a.app.iconBytes ??
                                  InstalledAppsCache.instance
                                      .iconFor(a.app.packageName);
                              final subtitle = [
                                if (a.appAdded) 'Added to Notiflow',
                                if (row.live.isNotEmpty)
                                  '${row.live.length} new',
                                if (a.skipped.isNotEmpty)
                                  '${a.skipped.length} already applied',
                              ].join(' · ');
                              return Container(
                                key: ValueKey('bulk-result-app-${a.app.id}'),
                                padding:
                                    const EdgeInsets.fromLTRB(14, 10, 6, 12),
                                decoration: BoxDecoration(
                                  color: rowBg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: borderCol),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(9),
                                          child: SizedBox(
                                            width: 32,
                                            height: 32,
                                            child: icon != null
                                                ? Image.memory(icon,
                                                    fit: BoxFit.cover,
                                                    gaplessPlayback: true)
                                                : Container(
                                                    color: high,
                                                    alignment: Alignment.center,
                                                    child: Text(
                                                      a.app.displayName.isEmpty
                                                          ? '?'
                                                          : a.app.displayName[0]
                                                              .toUpperCase(),
                                                      style: GoogleFonts
                                                          .plusJakartaSans(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: textMuted,
                                                      ),
                                                    ),
                                                  ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                a.app.displayName,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: textMain,
                                                ),
                                              ),
                                              Text(
                                                subtitle,
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                  fontSize: 11.5,
                                                  color: textMuted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (row.live.isNotEmpty)
                                          IconButton(
                                            key: ValueKey(
                                                'bulk-result-remove-app-${a.app.id}'),
                                            tooltip:
                                                'Undo for ${a.app.displayName}',
                                            visualDensity:
                                                VisualDensity.compact,
                                            onPressed: () => _undoApp(a),
                                            icon: Icon(Icons.close_rounded,
                                                size: 20, color: textMuted),
                                          ),
                                      ],
                                    ),
                                    if (row.live.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: [
                                          for (final r in row.live)
                                            _RuleChip(
                                              key: ValueKey(
                                                  'bulk-result-rule-${r.id}'),
                                              label: r.name ?? 'Rule',
                                              bg: primary.withValues(
                                                  alpha: isDark ? 0.18 : 0.1),
                                              fg: textMain,
                                              iconColor: textMuted,
                                              removeKey: ValueKey(
                                                  'bulk-result-remove-rule-${r.id}'),
                                              onRemove: () =>
                                                  _removeRule(a, r),
                                            ),
                                        ],
                                      ),
                                    ],
                                    if (a.skipped.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        'Already had: ${a.skipped.map((t) => t.name).join(', ')}',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11.5,
                                          fontStyle: FontStyle.italic,
                                          color: textMuted,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 10, 22, 18),
                    child: Row(
                      children: [
                        if (liveTotal > 0) ...[
                          Expanded(
                            child: OutlinedButton(
                              key: const ValueKey('bulk-result-undo-all'),
                              onPressed: _undoAll,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: textMain,
                                side: BorderSide(color: borderCol),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                'Undo all',
                                style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: FilledButton(
                            key: const ValueKey('bulk-result-done'),
                            onPressed: () => Navigator.pop(context),
                            style: FilledButton.styleFrom(
                              backgroundColor: primary,
                              foregroundColor: onPrimary,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              'Done',
                              style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RuleChip extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  final Color iconColor;
  final Key removeKey;
  final VoidCallback onRemove;

  const _RuleChip({
    super.key,
    required this.label,
    required this.bg,
    required this.fg,
    required this.iconColor,
    required this.removeKey,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
          InkResponse(
            key: removeKey,
            onTap: onRemove,
            radius: 16,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 8, 6),
              child: Icon(Icons.close_rounded, size: 15, color: iconColor),
            ),
          ),
        ],
      ),
    );
  }
}
