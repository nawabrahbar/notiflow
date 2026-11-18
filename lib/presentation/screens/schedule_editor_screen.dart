import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/repositories/schedule_repository.dart';
import '../../domain/models/managed_app.dart';
import '../../domain/models/rule_template.dart';
import '../../domain/models/schedule_rule.dart';
import '../theme/app_theme.dart';
import '../widgets/stitch_header.dart';
import '../widgets/stitch_switch.dart';
import '../widgets/app_toast.dart';

/// Schedule Rule Editor matching Botanical Sanctuary & Nocturne specifications:
/// - Seamless header (no bottom border, integrated canvas)
/// - "QUICK LOAD TEMPLATE / SAVED RULE" dropdown with placeholder "Choose a rule"
/// - Autofills entire rule form upon template selection
/// - Block vs Allow radio cards with organic botanical accents
/// - Starts / Ends At time cards with duration math & overnight badge
/// - Recurrence day presets & 7 individual day toggle buttons
/// - Deduplicates and cycles newly saved custom rules into localDB templates
class ScheduleEditorScreen extends StatefulWidget {
  final ScheduleRepository repository;
  final ManagedApp? app;
  final ManagedApp? targetApp;
  final ScheduleRule? existingRule;

  /// When set, the screen edits this saved rule instead of an app's schedule.
  final RuleTemplate? editingTemplate;

  /// When true, the screen creates a new saved rule and pops with it.
  final bool createTemplate;

  const ScheduleEditorScreen({
    super.key,
    required this.repository,
    this.app,
    this.targetApp,
    this.existingRule,
    this.editingTemplate,
    this.createTemplate = false,
  });

  @override
  State<ScheduleEditorScreen> createState() => _ScheduleEditorScreenState();
}

class _ScheduleEditorScreenState extends State<ScheduleEditorScreen> {
  late final TextEditingController _nameController;
  late ScheduleMode _mode;
  late int _startHour;
  late int _startMinute;
  late int _endHour;
  late int _endMinute;
  late Set<int> _daysOfWeek;
  late bool _allowUrgent;
  String? _selectedTemplateId;
  bool _isSaving = false;

  bool get _isEditingTemplate =>
      widget.editingTemplate != null || widget.createTemplate;

  ManagedApp get _effectiveApp {
    final explicit = widget.app ?? widget.targetApp;
    if (explicit != null) return explicit;
    final apps = widget.repository.managedApps;
    if (apps.isNotEmpty) return apps.first;
    final now = DateTime.now();
    return ManagedApp(
      id: 'app_default',
      packageName: 'com.android.settings',
      displayName: 'Selected App',
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  void initState() {
    super.initState();
    final rule = widget.existingRule;
    final template = widget.editingTemplate;
    if (template != null) {
      _nameController = TextEditingController(text: template.name);
      _mode = template.mode;
      _startHour = template.startTime.hour;
      _startMinute = template.startTime.minute;
      _endHour = template.endTime.hour;
      _endMinute = template.endTime.minute;
      _daysOfWeek = Set<int>.from(template.daysOfWeek);
      _allowUrgent = template.allowVipContacts;
    } else if (rule != null) {
      _nameController = TextEditingController(
        text: (rule.name != null && rule.name!.trim().isNotEmpty)
            ? rule.name!
            : 'Focus Schedule',
      );
      _mode = rule.mode;
      _startHour = rule.startTime.hour;
      _startMinute = rule.startTime.minute;
      _endHour = rule.endTime.hour;
      _endMinute = rule.endTime.minute;
      _daysOfWeek = Set<int>.from(rule.daysOfWeek);
      _allowUrgent = rule.allowVipContacts;
    } else {
      _nameController = TextEditingController(
        text: widget.createTemplate ? '' : RuleTemplate.defaultWorkFocus.name,
      );
      _mode = ScheduleMode.blockDuring;
      _startHour = 9;
      _startMinute = 0;
      _endHour = 17;
      _endMinute = 0;
      _daysOfWeek = {1, 2, 3, 4, 5};
      _allowUrgent = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _onTemplateSelected(RuleTemplate template) {
    setState(() {
      _selectedTemplateId = template.id;
      _nameController.text = template.name;
      _mode = template.mode;
      _startHour = template.startTime.hour;
      _startMinute = template.startTime.minute;
      _endHour = template.endTime.hour;
      _endMinute = template.endTime.minute;
      _daysOfWeek = Set<int>.from(template.daysOfWeek);
      _allowUrgent = template.allowVipContacts;
    });
  }

  int _calculateSpanHours() {
    int startM = _startHour * 60 + _startMinute;
    int endM = _endHour * 60 + _endMinute;
    if (endM <= startM) {
      endM += 24 * 60;
    }
    return ((endM - startM) / 60).round();
  }

  bool get _isOvernight {
    final startM = _startHour * 60 + _startMinute;
    final endM = _endHour * 60 + _endMinute;
    return endM < startM;
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initialTime = TimeOfDay(
      hour: isStart ? _startHour : _endHour,
      minute: isStart ? _startMinute : _endMinute,
    );

    final time = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (time != null) {
      setState(() {
        _selectedTemplateId = null; // custom adjustment
        if (isStart) {
          _startHour = time.hour;
          _startMinute = time.minute;
        } else {
          _endHour = time.hour;
          _endMinute = time.minute;
        }
      });
    }
  }

  void _applyDayPreset(String preset) {
    setState(() {
      _selectedTemplateId = null;
      if (preset == 'everyday') {
        _daysOfWeek = {1, 2, 3, 4, 5, 6, 7};
      } else if (preset == 'weekdays') {
        _daysOfWeek = {1, 2, 3, 4, 5};
      } else if (preset == 'weekends') {
        _daysOfWeek = {6, 7};
      }
    });
  }

  void _toggleDay(int day) {
    setState(() {
      _selectedTemplateId = null;
      if (_daysOfWeek.contains(day)) {
        if (_daysOfWeek.length > 1) {
          _daysOfWeek.remove(day);
        }
      } else {
        _daysOfWeek.add(day);
      }
    });
  }

  Future<void> _handleSave() async {
    if (_isEditingTemplate) return _handleSaveTemplate();
    setState(() => _isSaving = true);
    final now = DateTime.now();
    final trimmedName = _nameController.text.trim();

    final rule = ScheduleRule(
      id:
          widget.existingRule?.id ??
          'rule_${widget.existingRule?.appId ?? _effectiveApp.id}_${now.millisecondsSinceEpoch}',
      appId: widget.existingRule?.appId ?? _effectiveApp.id,
      name: trimmedName.isNotEmpty ? trimmedName : 'Focus Schedule',
      enabled: widget.existingRule?.enabled ?? true,
      mode: _mode,
      startTime: TimeOfDayValue(hour: _startHour, minute: _startMinute),
      endTime: TimeOfDayValue(hour: _endHour, minute: _endMinute),
      daysOfWeek: _daysOfWeek,
      allowVipContacts: _allowUrgent,
      createdAt: widget.existingRule?.createdAt ?? now,
      updatedAt: now,
    );

    await widget.repository.saveRule(rule, autoSaveTemplate: true);
    setState(() => _isSaving = false);

    if (mounted) {
      AppToast.show(context, message: 'Schedule rule saved successfully!');
      Navigator.pop(context);
    }
  }

  void _showToast(String message, {bool error = false}) {
    AppToast.show(
      context,
      message: message,
      type: error ? AppToastType.error : AppToastType.success,
    );
  }

  Future<void> _handleSaveTemplate() async {
    if (widget.createTemplate) return _handleCreateTemplate();
    final original = widget.editingTemplate!;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showToast('Please enter a rule name.', error: true);
      return;
    }
    if (_daysOfWeek.isEmpty) {
      _showToast('Please choose at least one day.', error: true);
      return;
    }

    final updated = original.copyWith(
      name: name,
      mode: _mode,
      startTime: TimeOfDayValue(hour: _startHour, minute: _startMinute),
      endTime: TimeOfDayValue(hour: _endHour, minute: _endMinute),
      daysOfWeek: Set<int>.from(_daysOfWeek),
      allowVipContacts: _allowUrgent,
    );

    final duplicate = widget.repository.findDuplicateTemplate(updated);
    if (duplicate != null) {
      final saveAnyway = await _confirmDuplicate(duplicate.name);
      if (saveAnyway != true || !mounted) return;
    }

    setState(() => _isSaving = true);
    final saved = await widget.repository.updateRuleTemplate(updated);
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (!saved) {
      _showToast('Could not save this rule.', error: true);
      return;
    }
    _showToast('Saved rule updated.');
    Navigator.pop(context);
  }

  Future<void> _handleCreateTemplate() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showToast('Please enter a rule name.', error: true);
      return;
    }
    if (_daysOfWeek.isEmpty) {
      _showToast('Please choose at least one day.', error: true);
      return;
    }
    final created = RuleTemplate(
      id: 'template_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      mode: _mode,
      startTime: TimeOfDayValue(hour: _startHour, minute: _startMinute),
      endTime: TimeOfDayValue(hour: _endHour, minute: _endMinute),
      daysOfWeek: Set<int>.from(_daysOfWeek),
      allowVipContacts: _allowUrgent,
      createdAt: DateTime.now(),
    );

    // Saved rules can't share the same schedule, so offer the existing one.
    final duplicate = widget.repository.findDuplicateTemplate(created);
    if (duplicate != null) {
      final useExisting = await _confirmDuplicate(
        duplicate.name,
        message:
            '"${duplicate.name}" already has the same behaviour, times and days. Use it instead?',
        confirmLabel: 'Use ${duplicate.name}',
      );
      if (useExisting == true && mounted) Navigator.pop(context, duplicate);
      return;
    }

    setState(() => _isSaving = true);
    final saved = await widget.repository.saveRuleTemplate(created);
    if (!mounted) return;
    setState(() => _isSaving = false);
    _showToast('Saved rule created.');
    Navigator.pop(context, saved);
  }

  Future<bool?> _confirmDuplicate(
    String otherName, {
    String? message,
    String confirmLabel = 'Save anyway',
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMain = isDark ? AppTheme.darkOnSurface : AppTheme.lightOnSurface;
    final textMuted = isDark
        ? AppTheme.darkOnSurfaceVariant
        : AppTheme.lightOnSurfaceVariant;
    final primary = isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark
            ? AppTheme.darkSurfaceContainerLow
            : AppTheme.lightSurfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Same as another rule',
          style: GoogleFonts.newsreader(
            fontWeight: FontWeight.w600,
            fontSize: 20,
            color: textMain,
          ),
        ),
        content: Text(
          message ??
              '"$otherName" already has the same behaviour, times and days. Save anyway?',
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
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: isDark
                  ? AppTheme.darkOnPrimary
                  : AppTheme.lightOnPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              confirmLabel,
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeDisplay(int hour, int minute) {
    return widget.repository.formatTimeOfDay(hour, minute);
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
    final primaryContainerCol = isDark
        ? AppTheme.darkPrimaryContainer
        : AppTheme.lightPrimaryContainer;
    final secondaryContainerCol = isDark
        ? AppTheme.darkSecondaryContainer
        : AppTheme.lightSecondaryContainer;
    final onSecondaryContainerCol = isDark
        ? AppTheme.darkOnSecondaryContainer
        : AppTheme.lightOnSecondaryContainer;

    final spanHours = _calculateSpanHours();
    final templates = widget.repository.savedTemplates;

    return Scaffold(
      backgroundColor: bg,
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
                  widget.createTemplate
                      ? 'New Rule'
                      : _isEditingTemplate
                      ? 'Edit Saved Rule'
                      : 'Schedule Rule Editor',
                  style: AppTheme.headerTitleStyle(context, textMain),
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

          final templateAndNameColumn = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_isEditingTemplate) ...[
                // QUICK LOAD TEMPLATE / SAVED RULE Dropdown
                Text(
                  'QUICK LOAD TEMPLATE / SAVED RULE',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, box) {
                    final menuWidth = box.maxWidth;
                    RuleTemplate? selectedTemplate;
                    for (final t in templates) {
                      if (t.id == _selectedTemplateId) selectedTemplate = t;
                    }
                    return MenuAnchor(
                      alignmentOffset: const Offset(0, 6),
                      style: MenuStyle(
                        backgroundColor: WidgetStatePropertyAll(cardBg),
                        surfaceTintColor: const WidgetStatePropertyAll(
                          Colors.transparent,
                        ),
                        elevation: const WidgetStatePropertyAll(6),
                        minimumSize: WidgetStatePropertyAll(Size(menuWidth, 0)),
                        maximumSize: WidgetStatePropertyAll(
                          Size(menuWidth, 320),
                        ),
                        padding: const WidgetStatePropertyAll(
                          EdgeInsets.symmetric(vertical: 6),
                        ),
                        shape: WidgetStatePropertyAll(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(color: borderCol),
                          ),
                        ),
                      ),
                      menuChildren: templates.map((tmpl) {
                        final isSelected = tmpl.id == _selectedTemplateId;
                        return MenuItemButton(
                          key: ValueKey('template-menu-item-${tmpl.id}'),
                          onPressed: () => _onTemplateSelected(tmpl),
                          style: ButtonStyle(
                            minimumSize: WidgetStatePropertyAll(
                              Size(menuWidth, 52),
                            ),
                            padding: const WidgetStatePropertyAll(
                              EdgeInsets.symmetric(horizontal: 16),
                            ),
                            backgroundColor: WidgetStatePropertyAll(
                              isSelected
                                  ? primaryCol.withValues(alpha: 0.12)
                                  : Colors.transparent,
                            ),
                          ),
                          child: SizedBox(
                            width: menuWidth - 32,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    tmpl.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w600,
                                      color: textMain,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${widget.repository.formatTime(tmpl.startTime)} - ${widget.repository.formatTime(tmpl.endTime)}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                      builder: (context, controller, _) {
                        return GestureDetector(
                          key: const ValueKey('template-dropdown'),
                          behavior: HitTestBehavior.opaque,
                          onTap: templates.isEmpty
                              ? null
                              : () => controller.isOpen
                                    ? controller.close()
                                    : controller.open(),
                          child: Container(
                            height: 52,
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _selectedTemplateId != null
                                    ? primaryCol
                                    : borderCol,
                                width: _selectedTemplateId != null ? 1.5 : 1.0,
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
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.bookmark_border_rounded,
                                  color: primaryCol,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    selectedTemplate?.name ?? 'Choose a rule',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: selectedTemplate != null
                                          ? 14.5
                                          : 15,
                                      fontWeight: selectedTemplate != null
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      color: selectedTemplate != null
                                          ? textMain
                                          : textMuted,
                                    ),
                                  ),
                                ),
                                Icon(
                                  controller.isOpen
                                      ? Icons.expand_less_rounded
                                      : Icons.expand_more_rounded,
                                  color: textMuted,
                                  size: 22,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 5),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Hint: Select a saved rule to auto-fill',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: textMuted.withValues(alpha: 0.8),
                    ),
                  ),
                ),

                const SizedBox(height: 22),
              ],

              // Rule Name Input
              Text(
                'RULE NAME',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: textMuted,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
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
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameController,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: textMain,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isCollapsed: true,
                          hintText: 'Enter rule moniker...',
                          hintStyle: GoogleFonts.plusJakartaSans(
                            color: textMuted.withValues(alpha: 0.6),
                            fontSize: 14,
                          ),
                        ),
                        onChanged: (_) {
                          if (_selectedTemplateId != null) {
                            setState(() => _selectedTemplateId = null);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(Icons.edit_note_rounded, color: textMuted, size: 20),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // Interception Behavior (BLOCK vs ALLOW)
              Text(
                'INTERCEPTION BEHAVIOR',
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
                  // BLOCK Option Card
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _mode = ScheduleMode.blockDuring;
                          _selectedTemplateId = null;
                        });
                      },
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _mode == ScheduleMode.blockDuring
                              ? (isDark
                                    ? primaryContainerCol.withValues(
                                        alpha: 0.25,
                                      )
                                    : primaryContainerCol.withValues(
                                        alpha: 0.2,
                                      ))
                              : cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _mode == ScheduleMode.blockDuring
                                ? primaryCol
                                : borderCol,
                            width: _mode == ScheduleMode.blockDuring
                                ? 1.8
                                : 1.0,
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: primaryCol.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.do_not_disturb_on_rounded,
                                    color: primaryCol,
                                    size: 18,
                                  ),
                                ),
                                if (_mode == ScheduleMode.blockDuring)
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: primaryCol,
                                    size: 20,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'BLOCK',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: textMain,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Silence alerts',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // ALLOW Option Card
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _mode = ScheduleMode.allowDuring;
                          _selectedTemplateId = null;
                        });
                      },
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _mode == ScheduleMode.allowDuring
                              ? (isDark
                                    ? primaryContainerCol.withValues(
                                        alpha: 0.25,
                                      )
                                    : primaryContainerCol.withValues(
                                        alpha: 0.2,
                                      ))
                              : cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _mode == ScheduleMode.allowDuring
                                ? primaryCol
                                : borderCol,
                            width: _mode == ScheduleMode.allowDuring
                                ? 1.8
                                : 1.0,
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color:
                                        (isDark
                                                ? AppTheme.darkSecondary
                                                : AppTheme.lightSecondary)
                                            .withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.notifications_active_rounded,
                                    color: isDark
                                        ? AppTheme.darkSecondary
                                        : AppTheme.lightSecondary,
                                    size: 18,
                                  ),
                                ),
                                if (_mode == ScheduleMode.allowDuring)
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: primaryCol,
                                    size: 20,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'ALLOW',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: textMain,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Pass through',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              // Priority Urgent Call Exception Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
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
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: secondaryContainerCol,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.emergency_rounded,
                        color: onSecondaryContainerCol,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Urgent Call Escalation',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: textMain,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Allow repeated calls within 3 minutes',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    StitchSwitch(
                      value: _allowUrgent,
                      onChanged: (val) => setState(() => _allowUrgent = val),
                    ),
                  ],
                ),
              ),
            ],
          );

          final timingAndRecurrenceColumn = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Time Window · Daily Schedule
              Text(
                'TIME WINDOW · DAILY SCHEDULE',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: textMuted,
                ),
              ),
              const SizedBox(height: 8),
              // Duration & Overnight Indicators
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: cardBgHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Duration: $spanHours hrs',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: textMuted,
                      ),
                    ),
                  ),
                  if (_isOvernight) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: primaryCol.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bedtime_rounded,
                            size: 12,
                            color: primaryCol,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '+1 DAY OVERNIGHT',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: primaryCol,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  // Starts At Card
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _pickTime(isStart: true),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(14),
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
                            Text(
                              'STARTS AT',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: textMuted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatTimeDisplay(_startHour, _startMinute),
                              style: GoogleFonts.newsreader(
                                fontSize: 28,
                                fontWeight: FontWeight.w600,
                                color: textMain,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Center Arrow Indicator
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: cardBgHighest,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: primaryCol,
                      ),
                    ),
                  ),

                  // Ends At Card
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _pickTime(isStart: false),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(14),
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
                            Text(
                              'ENDS AT',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: textMuted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatTimeDisplay(_endHour, _endMinute),
                              style: GoogleFonts.newsreader(
                                fontSize: 28,
                                fontWeight: FontWeight.w600,
                                color: textMain,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Recurrence Days
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'RECURRENCE DAYS',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: textMuted,
                    ),
                  ),
                  Text(
                    '${_daysOfWeek.length} days / week',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: primaryCol,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Day Presets
              Row(
                children: [
                  _buildPresetButton(
                    label: 'Everyday',
                    isActive: _daysOfWeek.length == 7,
                    onTap: () => _applyDayPreset('everyday'),
                    primaryCol: primaryCol,
                    cardBg: cardBg,
                    borderCol: borderCol,
                    textMain: textMain,
                    textMuted: textMuted,
                  ),
                  const SizedBox(width: 8),
                  _buildPresetButton(
                    label: 'Weekdays',
                    isActive:
                        _daysOfWeek.length == 5 &&
                        _daysOfWeek.contains(1) &&
                        _daysOfWeek.contains(2) &&
                        _daysOfWeek.contains(3) &&
                        _daysOfWeek.contains(4) &&
                        _daysOfWeek.contains(5),
                    onTap: () => _applyDayPreset('weekdays'),
                    primaryCol: primaryCol,
                    cardBg: cardBg,
                    borderCol: borderCol,
                    textMain: textMain,
                    textMuted: textMuted,
                  ),
                  const SizedBox(width: 8),
                  _buildPresetButton(
                    label: 'Weekends',
                    isActive:
                        _daysOfWeek.length == 2 &&
                        _daysOfWeek.contains(6) &&
                        _daysOfWeek.contains(7),
                    onTap: () => _applyDayPreset('weekends'),
                    primaryCol: primaryCol,
                    cardBg: cardBg,
                    borderCol: borderCol,
                    textMain: textMain,
                    textMuted: textMuted,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // 7 Day Toggle Squircle Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildDayButton(
                    1,
                    'M',
                    primaryCol,
                    cardBg,
                    borderCol,
                    textMain,
                    textMuted,
                  ),
                  _buildDayButton(
                    2,
                    'T',
                    primaryCol,
                    cardBg,
                    borderCol,
                    textMain,
                    textMuted,
                  ),
                  _buildDayButton(
                    3,
                    'W',
                    primaryCol,
                    cardBg,
                    borderCol,
                    textMain,
                    textMuted,
                  ),
                  _buildDayButton(
                    4,
                    'T',
                    primaryCol,
                    cardBg,
                    borderCol,
                    textMain,
                    textMuted,
                  ),
                  _buildDayButton(
                    5,
                    'F',
                    primaryCol,
                    cardBg,
                    borderCol,
                    textMain,
                    textMuted,
                  ),
                  _buildDayButton(
                    6,
                    'S',
                    primaryCol,
                    cardBg,
                    borderCol,
                    textMain,
                    textMuted,
                  ),
                  _buildDayButton(
                    7,
                    'S',
                    primaryCol,
                    cardBg,
                    borderCol,
                    textMain,
                    textMuted,
                  ),
                ],
              ),
            ],
          );

          final saveButton = SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _handleSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryCol,
                foregroundColor: isDark
                    ? const Color(0xFF482900)
                    : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      widget.createTemplate
                          ? 'Save Rule'
                          : _isEditingTemplate
                          ? 'Save Changes'
                          : widget.existingRule != null
                          ? 'Update Schedule Rule'
                          : 'Save Schedule Rule',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
            ),
          );

          final Widget saveArea = _isEditingTemplate
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.createTemplate
                          ? 'Saved to your rules, so you can use it again later.'
                          : 'Apps already using this rule keep their current schedule.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: textMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    saveButton,
                  ],
                )
              : saveButton;

          if (isTablet) {
            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: templateAndNameColumn),
                    const SizedBox(width: 24),
                    Expanded(flex: 5, child: timingAndRecurrenceColumn),
                  ],
                ),
                const SizedBox(height: 32),
                saveArea,
                const SizedBox(height: 32),
              ],
            );
          }

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            children: [
              templateAndNameColumn,
              const SizedBox(height: 24),
              timingAndRecurrenceColumn,
              const SizedBox(height: 32),
              saveArea,
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPresetButton({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    required Color primaryCol,
    required Color cardBg,
    required Color borderCol,
    required Color textMain,
    required Color textMuted,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? primaryCol : cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? primaryCol : borderCol),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
            color: isActive
                ? (Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF482900)
                      : Colors.white)
                : textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildDayButton(
    int day,
    String label,
    Color primaryCol,
    Color cardBg,
    Color borderCol,
    Color textMain,
    Color textMuted,
  ) {
    final bool active = _daysOfWeek.contains(day);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => _toggleDay(day),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: active ? primaryCol : cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? primaryCol : borderCol),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: active
                ? (isDark ? const Color(0xFF482900) : Colors.white)
                : textMuted,
          ),
        ),
      ),
    );
  }
}
