import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/repositories/schedule_repository.dart';
import '../../data/services/installed_apps_cache.dart';
import '../../domain/engine/app_category.dart';
import '../../domain/models/bulk_apply.dart';
import '../../domain/models/managed_app.dart';
import '../../domain/models/rule_template.dart';
import '../../domain/models/schedule_rule.dart';
import '../../platform/notification_platform_interface.dart';
import '../theme/app_theme.dart';
import 'schedule_editor_screen.dart';
import '../widgets/stitch_header.dart';

/// Short "Block · 9:00 AM - 5:00 PM · Mon-Fri" line for a saved rule.
String savedRuleSummary(ScheduleRepository repo, RuleTemplate t) {
  final days = switch (t.daysOfWeek) {
    final d when d.length == 7 => 'Everyday',
    final d when d.length == 5 && d.containsAll(const {1, 2, 3, 4, 5}) =>
      'Mon-Fri',
    final d when d.length == 2 && d.containsAll(const {6, 7}) => 'Weekends',
    final d => '${d.length} days/wk',
  };
  return switch (t.mode) {
    ScheduleMode.allDayBlock => 'Block all day · $days',
    ScheduleMode.allDayAllow => 'Allow all day · $days',
    ScheduleMode.blockDuring =>
      'Block · ${repo.formatTime(t.startTime)} - ${repo.formatTime(t.endTime)} · $days',
    ScheduleMode.allowDuring =>
      'Allow · ${repo.formatTime(t.startTime)} - ${repo.formatTime(t.endTime)} · $days',
  };
}

/// Apply Rules wizard: pick saved rules, pick apps, review, apply.
///
/// Phone runs the three steps one at a time. Tablet shows rules and apps side
/// by side with the review as a bottom bar. Pops with a [BulkApplyResult] after
/// applying, or null when cancelled.
class BulkApplyScreen extends StatefulWidget {
  final ScheduleRepository repository;

  const BulkApplyScreen({super.key, required this.repository});

  @override
  State<BulkApplyScreen> createState() => _BulkApplyScreenState();
}

class _Candidate {
  final String packageName;
  final String displayName;
  final ManagedApp? managed;
  final String category;

  const _Candidate({
    required this.packageName,
    required this.displayName,
    required this.managed,
    required this.category,
  });
}

class _BulkApplyScreenState extends State<BulkApplyScreen> {
  static const _categories = [
    ('all', 'ALL APPS'),
    ('messaging', 'MESSAGING'),
    ('social', 'SOCIAL'),
    ('productivity', 'PRODUCTIVITY'),
    ('other', 'OTHER'),
    ('system', 'SYSTEM'),
  ];

  final InstalledAppsCache _cache = InstalledAppsCache.instance;
  final TextEditingController _search = TextEditingController();
  final Set<String> _ruleIds = {};
  final Set<String> _packages = {};
  final Set<String> _pendingIcons = {};
  String _category = 'all';
  int _step = 0;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    _cache.addListener(_onChanged);
    widget.repository.addListener(_onChanged);
    _search.addListener(_onChanged);
    _cache.ensureLoaded();
  }

  @override
  void dispose() {
    _cache.removeListener(_onChanged);
    widget.repository.removeListener(_onChanged);
    _search.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  List<RuleTemplate> get _selectedTemplates => [
        for (final t in widget.repository.ruleTemplates)
          if (_ruleIds.contains(t.id)) t,
      ];

  /// Managed apps first, then every other installed app.
  List<_Candidate> _candidates() {
    final managed = [
      ...widget.repository.managedApps,
      ...widget.repository.historyApps.where((a) => !a.isDormantVault),
    ]
      ..sort((a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    final managedPkgs = {for (final a in managed) a.packageName};
    String categoryOf(String pkg) {
      final info = _cache.appFor(pkg);
      return info == null ? 'other' : appCategoryFor(info);
    }

    return [
      for (final a in managed)
        _Candidate(
          packageName: a.packageName,
          displayName: a.displayName,
          managed: a,
          category: categoryOf(a.packageName),
        ),
      for (final DiscoveredAppInfo a in _cache.apps)
        if (!managedPkgs.contains(a.packageName))
          _Candidate(
            packageName: a.packageName,
            displayName: a.displayName,
            managed: null,
            category: appCategoryFor(a),
          ),
    ];
  }

  List<_Candidate> _filtered(List<_Candidate> all) {
    final q = _search.text.trim().toLowerCase();
    return [
      for (final c in all)
        if ((_category == 'all' || c.category == _category) &&
            (q.isEmpty ||
                c.displayName.toLowerCase().contains(q) ||
                c.packageName.toLowerCase().contains(q)))
          c,
    ];
  }

  void _requestIcon(String pkg) {
    if (_pendingIcons.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final batch = _pendingIcons.toList();
        _pendingIcons.clear();
        _cache.loadIcons(batch);
      });
    }
    _pendingIcons.add(pkg);
  }

  Future<void> _apply(List<_Candidate> all) async {
    final templates = _selectedTemplates;
    final targets = [
      for (final c in all)
        if (_packages.contains(c.packageName))
          BulkApplyTarget(
            packageName: c.packageName,
            displayName: c.displayName,
            iconBytes: c.managed?.iconBytes ?? _cache.iconFor(c.packageName),
          ),
    ];
    if (templates.isEmpty || targets.isEmpty) return;
    setState(() => _applying = true);
    final result = await widget.repository.applyTemplatesToApps(
      templates: templates,
      targets: targets,
    );
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  String _plural(int n, String word) => '$n $word${n == 1 ? '' : 's'}';

  @override
  Widget build(BuildContext context) {
    final p = _Palette.of(context);
    final all = _candidates();
    final shown = _filtered(all);
    final preview = widget.repository
        .previewBulkApply(_selectedTemplates, _packages);

    return Scaffold(
      backgroundColor: p.bg,
      appBar: const StitchHeader(title: 'Apply Rules', showEmblem: false),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isTablet = constraints.maxWidth >= 600;
            if (isTablet) {
              return Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 2,
                            child: _panel(p, _buildRulesStep(p, step: 1)),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 3,
                            child: _panel(p, _buildAppsStep(p, all, shown, step: 2)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _buildTabletReviewBar(p, all, preview),
                ],
              );
            }
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: _StepIndicator(palette: p, step: _step),
                ),
                Expanded(
                  child: switch (_step) {
                    0 => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildRulesStep(p, step: 1),
                      ),
                    1 => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildAppsStep(p, all, shown, step: 2),
                      ),
                    _ => _buildReview(p, all, preview),
                  },
                ),
                _buildPhoneBottomBar(p, all, preview),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _panel(_Palette p, Widget child) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        color: p.containerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.border),
      ),
      child: child,
    );
  }

  Widget _stepHeading(_Palette p, int step, String title, String subtitle,
      {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'STEP $step',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: p.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: GoogleFonts.newsreader(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: p.textMain,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    color: p.textMuted,
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 1: saved rules
  // ---------------------------------------------------------------------------
  Future<void> _createRule() async {
    final created = await Navigator.of(context).push<RuleTemplate>(
      MaterialPageRoute(
        builder: (_) => ScheduleEditorScreen(
          repository: widget.repository,
          createTemplate: true,
        ),
      ),
    );
    if (created == null || !mounted) return;
    setState(() => _ruleIds.add(created.id));
  }

  Widget _newRuleTile(_Palette p) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('bulk-new-rule'),
        onTap: _createRule,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.primary.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: p.primary.withValues(alpha: p.isDark ? 0.18 : 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.add_rounded, size: 22, color: p.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'New rule',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: p.primary,
                      ),
                    ),
                    Text(
                      'Create a rule and select it',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
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
    );
  }

  Widget _buildRulesStep(_Palette p, {required int step}) {
    final templates = widget.repository.ruleTemplates;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepHeading(
          p,
          step,
          'Choose rules',
          _ruleIds.isEmpty
              ? 'Pick saved rules or create a new one.'
              : '${_plural(_ruleIds.length, 'rule')} selected',
        ),
        Expanded(
          child: HeaderScrollTransition(
            backgroundColor: MediaQuery.sizeOf(context).width >= 600
                ? p.containerLow
                : p.bg,
            child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: templates.length + 2,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              if (i == 0) return _newRuleTile(p);
              i--;
              if (i == templates.length) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'New rules are also saved to Settings → Saved Rules.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      color: p.textMuted,
                    ),
                  ),
                );
              }
              final t = templates[i];
              final selected = _ruleIds.contains(t.id);
              final isBlock = t.mode == ScheduleMode.blockDuring ||
                  t.mode == ScheduleMode.allDayBlock;
              return _SelectableTile(
                key: ValueKey('bulk-rule-${t.id}'),
                palette: p,
                selected: selected,
                onTap: () => setState(() {
                  if (!_ruleIds.remove(t.id)) _ruleIds.add(t.id);
                }),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: p.primary.withValues(alpha: p.isDark ? 0.18 : 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isBlock
                        ? Icons.do_not_disturb_on_outlined
                        : Icons.notifications_active_outlined,
                    size: 20,
                    color: p.primary,
                  ),
                ),
                title: t.name,
                subtitle: savedRuleSummary(widget.repository, t),
              );
            },
          ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Step 2: apps
  // ---------------------------------------------------------------------------
  Widget _buildAppsStep(
    _Palette p,
    List<_Candidate> all,
    List<_Candidate> shown, {
    required int step,
  }) {
    final allShownSelected =
        shown.isNotEmpty && shown.every((c) => _packages.contains(c.packageName));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepHeading(
          p,
          step,
          'Choose apps',
          _packages.isEmpty
              ? 'Apps you don\'t manage yet are added.'
              : '${_plural(_packages.length, 'app')} selected',
          trailing: shown.isEmpty
              ? null
              : TextButton(
                  key: const ValueKey('bulk-select-all'),
                  onPressed: () => setState(() {
                    if (allShownSelected) {
                      _packages.removeAll(shown.map((c) => c.packageName));
                    } else {
                      _packages.addAll(shown.map((c) => c.packageName));
                    }
                  }),
                  style: TextButton.styleFrom(
                    foregroundColor: p.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    allShownSelected ? 'Clear' : 'Select all',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
        ),
        Container(
          decoration: BoxDecoration(
            color: p.container,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: p.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            key: const ValueKey('bulk-search'),
            controller: _search,
            style: GoogleFonts.plusJakartaSans(fontSize: 14, color: p.textMain),
            decoration: InputDecoration(
              hintText: 'Search apps',
              hintStyle:
                  GoogleFonts.plusJakartaSans(fontSize: 14, color: p.textMuted),
              prefixIcon:
                  Icon(Icons.search_rounded, size: 20, color: p.textMuted),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 32, minHeight: 32),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      icon: Icon(Icons.close_rounded,
                          size: 18, color: p.textMuted),
                      onPressed: _search.clear,
                    ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              for (final (key, label) in _categories) ...[
                _CategoryChip(
                  palette: p,
                  label: label,
                  selected: _category == key,
                  onTap: () => setState(() => _category = key),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: HeaderScrollTransition(
            backgroundColor: MediaQuery.sizeOf(context).width >= 600
                ? p.containerLow
                : p.bg,
            child: !_cache.isLoaded && all.isEmpty
              ? Center(child: CircularProgressIndicator(color: p.primary))
              : shown.isEmpty
                  ? Center(
                      child: Text(
                        'No matching apps',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w600,
                          color: p.textMuted,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: shown.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final c = shown[i];
                        final selected = _packages.contains(c.packageName);
                        final icon =
                            c.managed?.iconBytes ?? _cache.iconFor(c.packageName);
                        if (icon == null) _requestIcon(c.packageName);
                        final ruleCount = c.managed == null
                            ? 0
                            : widget.repository
                                .getRulesForApp(c.managed!.id)
                                .length;
                        return _SelectableTile(
                          key: ValueKey('bulk-app-${c.packageName}'),
                          palette: p,
                          selected: selected,
                          dense: true,
                          onTap: () => setState(() {
                            if (!_packages.remove(c.packageName)) {
                              _packages.add(c.packageName);
                            }
                          }),
                          leading: _AppIcon(
                            palette: p,
                            icon: icon,
                            name: c.displayName,
                            size: 38,
                          ),
                          title: c.displayName,
                          subtitle: c.managed == null
                              ? 'Not managed yet'
                              : ruleCount == 0
                                  ? 'Managed · no rules'
                                  : 'Managed · ${_plural(ruleCount, 'rule')}',
                        );
                      },
                    ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Step 3: review (phone) / review bar (tablet)
  // ---------------------------------------------------------------------------
  String _reviewHeadline() =>
      '${_plural(_ruleIds.length, 'rule')} → ${_plural(_packages.length, 'app')}';

  String _reviewDetail(({int toAdd, int skipped}) preview) {
    final parts = [_plural(preview.toAdd, 'new schedule')];
    if (preview.skipped > 0) parts.add('${preview.skipped} already applied');
    return parts.join(' · ');
  }

  Widget _buildReview(
    _Palette p,
    List<_Candidate> all,
    ({int toAdd, int skipped}) preview,
  ) {
    final templates = _selectedTemplates;
    final apps = [
      for (final c in all)
        if (_packages.contains(c.packageName)) c,
    ];
    final newApps = apps.where((c) => c.managed == null).length;

    Widget section(String title, List<Widget> children) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: p.containerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: p.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: p.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      );
    }

    return HeaderScrollTransition(
      child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        _stepHeading(p, 3, 'Review', 'Check everything before applying.'),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: p.primary.withValues(alpha: p.isDark ? 0.14 : 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.primary.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _reviewHeadline(),
                style: GoogleFonts.newsreader(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: p.textMain,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _reviewDetail(preview),
                key: const ValueKey('bulk-review-line'),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: p.primary,
                ),
              ),
              if (preview.skipped > 0 || newApps > 0) ...[
                const SizedBox(height: 6),
                Text(
                  [
                    if (preview.skipped > 0)
                      'Apps that already have a rule are skipped for it.',
                    if (newApps > 0)
                      '${_plural(newApps, 'app')} will be added to Notiflow.',
                  ].join(' '),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    height: 1.4,
                    color: p.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        section('RULES', [
          for (final t in templates)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.name,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: p.textMain,
                    ),
                  ),
                  Text(
                    savedRuleSummary(widget.repository, t),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: p.textMuted,
                    ),
                  ),
                ],
              ),
            ),
        ]),
        const SizedBox(height: 12),
        section('APPS', [
          for (final c in apps)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  _AppIcon(
                    palette: p,
                    icon: c.managed?.iconBytes ?? _cache.iconFor(c.packageName),
                    name: c.displayName,
                    size: 30,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      c.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: p.textMain,
                      ),
                    ),
                  ),
                  if (c.managed == null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: p.secContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'NEW',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: p.onSecContainer,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ]),
      ],
    ));
  }

  Widget _applyButton(_Palette p, List<_Candidate> all,
      ({int toAdd, int skipped}) preview) {
    final ready = _ruleIds.isNotEmpty && _packages.isNotEmpty;
    final enabled = ready && preview.toAdd > 0 && !_applying;
    return FilledButton(
      key: const ValueKey('bulk-apply'),
      onPressed: enabled ? () => _apply(all) : null,
      style: _filledStyle(p),
      child: _applying
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: p.onPrimary),
            )
          : Text(
              ready && preview.toAdd == 0 ? 'Already applied' : 'Apply',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
            ),
    );
  }

  ButtonStyle _filledStyle(_Palette p) => FilledButton.styleFrom(
        backgroundColor: p.primary,
        foregroundColor: p.onPrimary,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      );

  Widget _buildPhoneBottomBar(_Palette p, List<_Candidate> all,
      ({int toAdd, int skipped}) preview) {
    final canNext = switch (_step) {
      0 => _ruleIds.isNotEmpty,
      1 => _packages.isNotEmpty,
      _ => false,
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: p.bg,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: Row(
        children: [
          if (_step > 0) ...[
            Expanded(
              child: OutlinedButton(
                key: const ValueKey('bulk-back'),
                onPressed: _applying ? null : () => setState(() => _step--),
                style: OutlinedButton.styleFrom(
                  foregroundColor: p.textMain,
                  side: BorderSide(color: p.border),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  'Back',
                  style:
                      GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: _step == 2
                ? _applyButton(p, all, preview)
                : FilledButton(
                    key: const ValueKey('bulk-next'),
                    onPressed: canNext ? () => setState(() => _step++) : null,
                    style: _filledStyle(p),
                    child: Text(
                      'Next',
                      style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletReviewBar(_Palette p, List<_Candidate> all,
      ({int toAdd, int skipped}) preview) {
    final ready = _ruleIds.isNotEmpty && _packages.isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 16),
      decoration: BoxDecoration(
        color: p.containerLow,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ready ? _reviewHeadline() : 'Choose rules and apps',
                  style: GoogleFonts.newsreader(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: p.textMain,
                  ),
                ),
                Text(
                  ready
                      ? _reviewDetail(preview)
                      : 'Pick at least one rule and one app to continue.',
                  key: const ValueKey('bulk-review-line'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: ready ? FontWeight.w600 : FontWeight.w400,
                    color: ready ? p.primary : p.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _applyButton(p, all, preview),
        ],
      ),
    );
  }
}

class _Palette {
  final bool isDark;
  final Color bg;
  final Color container;
  final Color containerLow;
  final Color containerHigh;
  final Color border;
  final Color textMain;
  final Color textMuted;
  final Color primary;
  final Color onPrimary;
  final Color secContainer;
  final Color onSecContainer;

  const _Palette({
    required this.isDark,
    required this.bg,
    required this.container,
    required this.containerLow,
    required this.containerHigh,
    required this.border,
    required this.textMain,
    required this.textMuted,
    required this.primary,
    required this.onPrimary,
    required this.secContainer,
    required this.onSecContainer,
  });

  factory _Palette.of(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    return _Palette(
      isDark: d,
      bg: d ? AppTheme.darkBackground : AppTheme.lightBackground,
      container:
          d ? AppTheme.darkSurfaceContainer : AppTheme.lightSurfaceContainer,
      containerLow: d
          ? AppTheme.darkSurfaceContainerLow
          : AppTheme.lightSurfaceContainerLow,
      containerHigh: d
          ? AppTheme.darkSurfaceContainerHigh
          : AppTheme.lightSurfaceContainerHigh,
      border: d
          ? AppTheme.darkOutlineVariant.withValues(alpha: 0.3)
          : AppTheme.lightOutlineVariant.withValues(alpha: 0.35),
      textMain: d ? AppTheme.darkOnSurface : AppTheme.lightOnSurface,
      textMuted:
          d ? AppTheme.darkOnSurfaceVariant : AppTheme.lightOnSurfaceVariant,
      primary: d ? AppTheme.darkPrimary : AppTheme.lightPrimary,
      onPrimary: d ? AppTheme.darkOnPrimary : AppTheme.lightOnPrimary,
      secContainer: d
          ? AppTheme.darkSecondaryContainer
          : AppTheme.lightSecondaryContainer,
      onSecContainer: d
          ? AppTheme.darkOnSecondaryContainer
          : AppTheme.lightOnSecondaryContainer,
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final _Palette palette;
  final int step;

  const _StepIndicator({required this.palette, required this.step});

  @override
  Widget build(BuildContext context) {
    final p = palette;
    const labels = ['Rules', 'Apps', 'Review'];
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 4,
                  decoration: BoxDecoration(
                    color: i <= step ? p.primary : p.containerHigh,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${i + 1}. ${labels[i]}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: i == step ? FontWeight.w700 : FontWeight.w500,
                    color: i == step ? p.textMain : p.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final _Palette palette;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.palette,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? p.primary : p.containerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? p.primary : p.border),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            letterSpacing: 0.5,
            color: selected ? p.onPrimary : p.textMuted,
          ),
        ),
      ),
    );
  }
}

class _SelectableTile extends StatelessWidget {
  final _Palette palette;
  final bool selected;
  final bool dense;
  final VoidCallback onTap;
  final Widget leading;
  final String title;
  final String subtitle;

  const _SelectableTile({
    super.key,
    required this.palette,
    required this.selected,
    required this.onTap,
    required this.leading,
    required this.title,
    required this.subtitle,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: dense ? 10 : 12),
          decoration: BoxDecoration(
            color: selected
                ? p.primary.withValues(alpha: p.isDark ? 0.14 : 0.08)
                : p.container,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? p.primary.withValues(alpha: 0.6) : p.border,
            ),
          ),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: p.textMain,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: p.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 22,
                color: selected ? p.primary : p.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppIcon extends StatelessWidget {
  final _Palette palette;
  final Uint8List? icon;
  final String name;
  final double size;

  const _AppIcon({
    required this.palette,
    required this.icon,
    required this.name,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final bytes = icon;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.25),
      child: SizedBox(
        width: size,
        height: size,
        child: bytes != null
            ? Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true)
            : Container(
                color: palette.containerHigh,
                alignment: Alignment.center,
                child: Text(
                  name.isEmpty ? '?' : name[0].toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: size * 0.4,
                    fontWeight: FontWeight.w700,
                    color: palette.textMuted,
                  ),
                ),
              ),
      ),
    );
  }
}
