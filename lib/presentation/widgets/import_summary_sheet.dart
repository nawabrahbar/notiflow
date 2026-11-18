import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/repositories/schedule_repository.dart';
import '../../data/services/installed_apps_cache.dart';
import '../../domain/models/import_report.dart';
import '../theme/app_theme.dart';
import 'app_toast.dart';

/// Shows what a backup import did: imported apps, apps waiting for install,
/// skipped apps and saved rules. Resolves to true when the user taps View Rules.
/// Apps waiting for install can be removed from the vault via [repository].
Future<bool> showImportSummarySheet(
  BuildContext context,
  ImportReport report, {
  required ScheduleRepository repository,
}) async {
  final viewRules = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) => ImportSummarySheet(report: report, repository: repository),
  );
  return viewRules ?? false;
}

/// Confirms deleting a vaulted app and its saved rules. Resolves to true on Remove.
Future<bool> _confirmVaultRemoval(
  BuildContext context,
  ImportReportApp item,
) async {
  final name = item.app.displayName;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final textMain = isDark ? AppTheme.darkOnSurface : AppTheme.lightOnSurface;
  final textMuted = isDark
      ? AppTheme.darkOnSurfaceVariant
      : AppTheme.lightOnSurfaceVariant;
  final rules = item.ruleCount == 1
      ? 'its saved rule'
      : 'its ${item.ruleCount} saved rules';

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: isDark
          ? AppTheme.darkSurfaceContainerLow
          : AppTheme.lightSurfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(
        'Remove $name?',
        style: GoogleFonts.newsreader(
          fontWeight: FontWeight.w600,
          fontSize: 20,
          color: textMain,
        ),
      ),
      content: Text(
        '$name and $rules will be deleted from the vault. '
        'They won\'t turn on if you install $name later.',
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
          key: const ValueKey('import-summary-remove-confirm'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.signalError,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(
            'Remove',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
  return confirmed == true;
}

class ImportSummarySheet extends StatefulWidget {
  final ImportReport report;
  final ScheduleRepository repository;

  const ImportSummarySheet({
    super.key,
    required this.report,
    required this.repository,
  });

  @override
  State<ImportSummarySheet> createState() => _ImportSummarySheetState();
}

class _ImportSummarySheetState extends State<ImportSummarySheet> {
  late final List<ImportReportApp> _waiting = [...widget.report.waiting];

  /// Asks for confirmation, then deletes a vaulted app and its saved rules.
  Future<void> _removeWaiting(ImportReportApp item) async {
    final name = item.app.displayName;
    final confirmed = await _confirmVaultRemoval(context, item);
    if (!confirmed || !mounted) return;
    setState(() => _waiting.remove(item));
    await widget.repository.removeApp(item.app.id);
    if (!mounted) return;
    AppToast.show(context, message: 'Removed $name from the vault');
  }

  @override
  void initState() {
    super.initState();
    final missingIcons = [
      for (final a in widget.report.imported)
        if (a.app.iconBytes == null) a.app.packageName,
    ];
    if (missingIcons.isNotEmpty) {
      InstalledAppsCache.instance.loadIcons(missingIcons);
    }
  }

  String _plural(int n, String word) => '$n $word${n == 1 ? '' : 's'}';

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? AppTheme.darkSurfaceContainerLow
        : AppTheme.lightSurfaceContainerLow;
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
    final borderCol = isDark
        ? AppTheme.darkOutlineVariant.withValues(alpha: 0.3)
        : AppTheme.lightOutlineVariant.withValues(alpha: 0.35);

    final summary = [
      _plural(report.imported.length, 'app'),
      _plural(report.importedRuleCount, 'rule'),
      if (report.savedRules.isNotEmpty)
        _plural(report.savedRules.length, 'saved rule'),
    ].join(' · ');

    final palette = _SheetPalette(
      isDark: isDark,
      textMain: textMain,
      textMuted: textMuted,
      borderCol: borderCol,
    );

    final sections = <Widget>[
      if (report.imported.isNotEmpty)
        _SummarySection(
          key: const ValueKey('import-summary-imported'),
          palette: palette,
          icon: Icons.check_circle_rounded,
          iconColor: onSecContainer,
          title: 'Imported',
          count: report.imported.length,
          children: [
            for (final a in report.imported)
              _AppRow(
                palette: palette,
                item: a,
                subtitle: a.ruleCount == 0
                    ? 'No rules'
                    : '${_plural(a.ruleCount, 'rule')} active',
              ),
          ],
        ),
      if (_waiting.isNotEmpty)
        _SummarySection(
          key: const ValueKey('import-summary-waiting'),
          palette: palette,
          icon: Icons.hourglass_top_rounded,
          iconColor: primary,
          title: 'Waiting for install',
          count: _waiting.length,
          note:
              'Not installed on this device. Rules turn on automatically '
              'when you install these apps.',
          children: [
            for (final a in _waiting)
              _AppRow(
                key: ValueKey('import-summary-waiting-${a.app.id}'),
                palette: palette,
                item: a,
                dimmed: true,
                onRemove: () => _removeWaiting(a),
                subtitle: a.ruleCount == 0
                    ? 'No rules'
                    : '${_plural(a.ruleCount, 'rule')} saved',
              ),
          ],
        ),
      if (report.skipped.isNotEmpty)
        _SummarySection(
          key: const ValueKey('import-summary-skipped'),
          palette: palette,
          icon: Icons.remove_circle_outline_rounded,
          iconColor: textMuted,
          title: 'Skipped',
          count: report.skipped.length,
          note: 'Not imported. These apps aren\'t installed on this device.',
          children: [
            for (final a in report.skipped)
              _AppRow(
                palette: palette,
                item: a,
                dimmed: true,
                subtitle: a.ruleCount == 0
                    ? 'Not imported'
                    : '${_plural(a.ruleCount, 'rule')} not imported',
              ),
          ],
        ),
      if (report.savedRules.isNotEmpty)
        _SummarySection(
          key: const ValueKey('import-summary-saved'),
          palette: palette,
          icon: Icons.bookmark_rounded,
          iconColor: primary,
          title: 'Saved rules',
          count: report.savedRules.length,
          children: [
            for (final name in report.savedRules)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.bookmark_border_rounded,
                      size: 18,
                      color: textMuted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textMain,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
    ];

    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: borderCol),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppTheme.darkSurfaceContainerHigh
                              : AppTheme.lightSurfaceContainerHigh,
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
                          child: Icon(
                            Icons.check_rounded,
                            color: onSecContainer,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Import complete',
                                style: GoogleFonts.newsreader(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  color: textMain,
                                ),
                              ),
                              Text(
                                summary,
                                key: const ValueKey('import-summary-line'),
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
                    const SizedBox(height: 14),
                  ],
                ),
              ),
              Flexible(
                child: sections.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
                        child: Text(
                          'The backup didn\'t contain any apps or rules.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: textMuted,
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
                        itemCount: sections.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => sections[i],
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 10, 22, 18),
                child: Row(
                  children: [
                    if (report.imported.isNotEmpty) ...[
                      Expanded(
                        child: OutlinedButton(
                          key: const ValueKey('import-summary-view-rules'),
                          onPressed: () => Navigator.pop(context, true),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: textMain,
                            side: BorderSide(color: borderCol),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            'View Rules',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: FilledButton(
                        key: const ValueKey('import-summary-done'),
                        onPressed: () => Navigator.pop(context, false),
                        style: FilledButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: isDark
                              ? AppTheme.darkOnPrimary
                              : AppTheme.lightOnPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Done',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                          ),
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
  }
}

/// Lists apps whose rules are parked in the dormant vault (saved, but the app
/// isn't installed) and lets the user remove them one by one.
Future<void> showDormantVaultSheet(
  BuildContext context, {
  required ScheduleRepository repository,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) => DormantVaultSheet(repository: repository),
  );
}

class DormantVaultSheet extends StatelessWidget {
  final ScheduleRepository repository;

  const DormantVaultSheet({super.key, required this.repository});

  String _plural(int n, String word) => '$n $word${n == 1 ? '' : 's'}';

  Future<void> _remove(BuildContext context, ImportReportApp item) async {
    final name = item.app.displayName;
    final confirmed = await _confirmVaultRemoval(context, item);
    if (!confirmed || !context.mounted) return;
    await repository.removeApp(item.app.id);
    if (!context.mounted) return;
    AppToast.show(context, message: 'Removed $name from the vault');
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
    final borderCol = isDark
        ? AppTheme.darkOutlineVariant.withValues(alpha: 0.3)
        : AppTheme.lightOutlineVariant.withValues(alpha: 0.35);
    final palette = _SheetPalette(
      isDark: isDark,
      textMain: textMain,
      textMuted: textMuted,
      borderCol: borderCol,
    );
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    return ListenableBuilder(
      listenable: repository,
      builder: (context, _) {
        final schedules = repository.schedules;
        final items = [
          for (final a in repository.dormantVaultApps)
            ImportReportApp(
              app: a,
              ruleCount: schedules.where((r) => r.appId == a.id).length,
            ),
        ];
        final ruleTotal = items.fold<int>(0, (sum, i) => sum + i.ruleCount);
        final summary = items.isEmpty
            ? '0 apps · no uninstalled apps'
            : '${_plural(items.length, 'app')} · '
                  '${_plural(ruleTotal, 'saved rule')}';

        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Container(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: Border.all(color: borderCol),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppTheme.darkSurfaceContainerHigh
                                  : AppTheme.lightSurfaceContainerHigh,
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
                                color: primary.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.inventory_2_outlined,
                                color: primary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Dormant Vault',
                                    style: GoogleFonts.newsreader(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w600,
                                      color: textMain,
                                    ),
                                  ),
                                  Text(
                                    summary,
                                    key: const ValueKey('dormant-vault-line'),
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
                          items.isEmpty
                              ? 'When you import a backup and keep rules for apps '
                                    'that aren\'t installed, they\'re parked here.'
                              : 'These apps aren\'t installed on this device. Their '
                                    'rules turn on automatically when you install them.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            height: 1.4,
                            color: textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: items.isEmpty
                        ? Padding(
                            key: const ValueKey('dormant-vault-empty'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 24,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.inventory_2_outlined,
                                  size: 36,
                                  color: textMuted.withValues(alpha: 0.6),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No uninstalled apps in the vault',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: textMuted,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(horizontal: 22),
                            children: [
                              for (final a in items)
                                _AppRow(
                                  key: ValueKey('dormant-vault-${a.app.id}'),
                                  palette: palette,
                                  item: a,
                                  dimmed: true,
                                  onRemove: () => _remove(context, a),
                                  subtitle: a.ruleCount == 0
                                      ? 'No rules'
                                      : '${_plural(a.ruleCount, 'rule')} saved',
                                ),
                            ],
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
                    child: FilledButton(
                      key: const ValueKey('dormant-vault-done'),
                      onPressed: () => Navigator.pop(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: isDark
                            ? AppTheme.darkOnPrimary
                            : AppTheme.lightOnPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Done',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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

class _SheetPalette {
  final bool isDark;
  final Color textMain;
  final Color textMuted;
  final Color borderCol;

  const _SheetPalette({
    required this.isDark,
    required this.textMain,
    required this.textMuted,
    required this.borderCol,
  });
}

/// A category card with a count and a chevron; starts expanded.
class _SummarySection extends StatefulWidget {
  final _SheetPalette palette;
  final IconData icon;
  final Color iconColor;
  final String title;
  final int count;
  final String? note;
  final List<Widget> children;

  const _SummarySection({
    super.key,
    required this.palette,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.count,
    required this.children,
    this.note,
  });

  @override
  State<_SummarySection> createState() => _SummarySectionState();
}

class _SummarySectionState extends State<_SummarySection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    return Container(
      decoration: BoxDecoration(
        color:
            (p.isDark
                    ? AppTheme.darkSurfaceContainer
                    : AppTheme.lightSurfaceContainer)
                .withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.borderCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  Icon(widget.icon, color: widget.iconColor, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: p.textMain,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: widget.iconColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${widget.count}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: p.textMain,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: p.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.note != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              widget.note!,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                height: 1.35,
                                color: p.textMuted,
                              ),
                            ),
                          ),
                        ...widget.children,
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _AppRow extends StatelessWidget {
  final _SheetPalette palette;
  final ImportReportApp item;
  final String subtitle;
  final bool dimmed;
  final VoidCallback? onRemove;

  const _AppRow({
    super.key,
    required this.palette,
    required this.item,
    required this.subtitle,
    this.dimmed = false,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final app = item.app;
    final placeholderBg = p.isDark
        ? AppTheme.darkSurfaceContainerHigh
        : AppTheme.lightSurfaceContainerHigh;
    final initial = app.displayName.isEmpty
        ? '?'
        : app.displayName[0].toUpperCase();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Opacity(
              opacity: dimmed ? 0.65 : 1,
              child: Row(
                children: [
                  ListenableBuilder(
                    listenable: InstalledAppsCache.instance,
                    builder: (context, _) {
                      final icon =
                          app.iconBytes ??
                          (dimmed
                              ? null
                              : InstalledAppsCache.instance.iconFor(
                                  app.packageName,
                                ));
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: SizedBox(
                          width: 32,
                          height: 32,
                          child: icon != null
                              ? Image.memory(
                                  icon,
                                  fit: BoxFit.cover,
                                  gaplessPlayback: true,
                                )
                              : Container(
                                  color: placeholderBg,
                                  alignment: Alignment.center,
                                  child: Text(
                                    initial,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: p.textMuted,
                                    ),
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          app.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: p.textMain,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            color: p.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (onRemove != null)
            IconButton(
              key: ValueKey('import-summary-remove-${app.id}'),
              tooltip: 'Remove ${app.displayName}',
              onPressed: onRemove,
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.close_rounded, size: 20, color: p.textMuted),
            ),
        ],
      ),
    );
  }
}
