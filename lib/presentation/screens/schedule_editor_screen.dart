import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/repositories/schedule_repository.dart';
import '../../domain/models/managed_app.dart';
import '../../domain/models/schedule_rule.dart';
import '../widgets/stitch_header.dart';
import '../widgets/stitch_switch.dart';

/// Schedule Rule Editor matching Stitch Obsidian Signal redesign.
/// Features Rule configuration header, BLOCK vs ALLOW mode selector,
/// Start / End time pickers with overnight math, 7-day recurrence selector,
/// and urgent call escalation toggle.
class ScheduleEditorScreen extends StatefulWidget {
  final ScheduleRepository repository;
  final ManagedApp? app;
  final ManagedApp? targetApp;
  final ScheduleRule? existingRule;

  const ScheduleEditorScreen({
    super.key,
    required this.repository,
    this.app,
    this.targetApp,
    this.existingRule,
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
  bool _isSaving = false;

  ManagedApp get _effectiveApp =>
      widget.app ?? widget.targetApp ?? widget.repository.managedApps.first;

  @override
  void initState() {
    super.initState();
    final rule = widget.existingRule;
    if (rule != null) {
      _nameController = TextEditingController(text: 'Focus Schedule');
      _mode = rule.mode;
      _startHour = rule.startTime.hour;
      _startMinute = rule.startTime.minute;
      _endHour = rule.endTime.hour;
      _endMinute = rule.endTime.minute;
      _daysOfWeek = Set<int>.from(rule.daysOfWeek);
      _allowUrgent = rule.allowVipContacts;
    } else {
      _nameController = TextEditingController(text: 'Work Focus Hours');
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
      if (preset == 'everyday') {
        _daysOfWeek = {1, 2, 3, 4, 5, 6, 7};
      } else if (preset == 'weekdays') {
        _daysOfWeek = {1, 2, 3, 4, 5};
      } else if (preset == 'weekends') {
        _daysOfWeek = {6, 7};
      }
    });
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    final now = DateTime.now();

    final rule = ScheduleRule(
      id: widget.existingRule?.id ?? 'rule_${now.millisecondsSinceEpoch}',
      appId: _effectiveApp.id,
      enabled: widget.existingRule?.enabled ?? true,
      mode: _mode,
      startTime: TimeOfDayValue(hour: _startHour, minute: _startMinute),
      endTime: TimeOfDayValue(hour: _endHour, minute: _endMinute),
      daysOfWeek: _daysOfWeek,
      allowVipContacts: _allowUrgent,
      createdAt: widget.existingRule?.createdAt ?? now,
      updatedAt: now,
    );

    await widget.repository.saveRule(rule);
    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Schedule rule saved successfully!'),
          backgroundColor: Color(0xFFF59E0B),
        ),
      );
      Navigator.pop(context);
    }
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

    final spanHours = _calculateSpanHours();

    return Scaffold(
      backgroundColor: bg,
      appBar: const StitchHeader(title: 'Schedule Rule Editor'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Meta Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFEEEEF0),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: borderCol),
                ),
                child: Text(
                  'RULE CONFIGURATION · AUTOMATION #04',
                  style: GoogleFonts.jetBrainsMono(
                    color: amber,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              Text(
                'Custom Cadence',
                style: GoogleFonts.inter(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: textMain,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Define automated focus shields & notification intervals. High-efficiency triage active.',
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  color: textMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              // Rule Name Input
              Text(
                'RULE NAME',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: textMuted,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderCol),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _nameController,
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: textMain),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'e.g. Work Focus Hours, Sleep Shield',
                    hintStyle: GoogleFonts.inter(color: textMuted),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Interception Behavior (BLOCK vs ALLOW)
              Text(
                'INTERCEPTION BEHAVIOR',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: textMuted,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _mode = ScheduleMode.blockDuring),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _mode == ScheduleMode.blockDuring
                              ? (isDark ? const Color(0xFF272014) : const Color(0xFFFEF3C7))
                              : cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _mode == ScheduleMode.blockDuring ? amber : borderCol,
                            width: _mode == ScheduleMode.blockDuring ? 1.8 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Icon(Icons.remove_circle_outline_rounded,
                                    color: _mode == ScheduleMode.blockDuring ? amber : textMuted, size: 20),
                                if (_mode == ScheduleMode.blockDuring)
                                  Icon(Icons.check_circle_rounded, color: amber, size: 18),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'BLOCK',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: _mode == ScheduleMode.blockDuring ? amber : textMain,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Silence alerts',
                              style: GoogleFonts.inter(
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
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _mode = ScheduleMode.allowDuring),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _mode == ScheduleMode.allowDuring
                              ? (isDark ? const Color(0xFF052E16) : const Color(0xFFDCFCE7))
                              : cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _mode == ScheduleMode.allowDuring ? const Color(0xFF22C55E) : borderCol,
                            width: _mode == ScheduleMode.allowDuring ? 1.8 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Icon(Icons.notifications_active_outlined,
                                    color: _mode == ScheduleMode.allowDuring ? const Color(0xFF22C55E) : textMuted, size: 20),
                                if (_mode == ScheduleMode.allowDuring)
                                  const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 18),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'ALLOW',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: _mode == ScheduleMode.allowDuring ? const Color(0xFF16A34A) : textMain,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Pass through',
                              style: GoogleFonts.inter(
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

              const SizedBox(height: 24),

              // Time Window Selectors
              Text(
                'TIME WINDOW · DAILY SCHEDULE',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: textMuted,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _pickTime(isStart: true),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderCol),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'STARTS AT',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: textMuted,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${_startHour.toString().padLeft(2, '0')}:${_startMinute.toString().padLeft(2, '0')}',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: textMain,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(Icons.arrow_forward_rounded, color: Color(0xFFF59E0B), size: 20),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _pickTime(isStart: false),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderCol),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ENDS AT',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: textMuted,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${_endHour.toString().padLeft(2, '0')}:${_endMinute.toString().padLeft(2, '0')}',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: textMain,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Span duration indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF121214) : const Color(0xFFF3F3F5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderCol),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline_rounded, size: 16, color: amber),
                    const SizedBox(width: 8),
                    Text(
                      _isOvernight
                          ? 'Overnight interval ($spanHours hrs total across midnight)'
                          : 'Same day interval ($spanHours hrs total)',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: textMuted,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Recurrence Days
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'RECURRENCE DAYS',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: textMuted,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Text(
                    '${_daysOfWeek.length} days / week',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: amber,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Day presets
              Row(
                children: [
                  _buildDayPresetChip('Everyday', 'everyday', isDark),
                  const SizedBox(width: 8),
                  _buildDayPresetChip('Weekdays', 'weekdays', isDark),
                  const SizedBox(width: 8),
                  _buildDayPresetChip('Weekends', 'weekends', isDark),
                ],
              ),
              const SizedBox(height: 12),

              // 7 Day Toggle Pills
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildDayPill('M', 1, isDark),
                  _buildDayPill('T', 2, isDark),
                  _buildDayPill('W', 3, isDark),
                  _buildDayPill('T', 4, isDark),
                  _buildDayPill('F', 5, isDark),
                  _buildDayPill('S', 6, isDark),
                  _buildDayPill('S', 7, isDark),
                ],
              ),

              const SizedBox(height: 24),

              // Exceptions & Escalation
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderCol),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF272014) : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.emergency_rounded, color: amber, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Allow urgent repeated calls',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: textMain,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Passes priority pings through if received twice within 3 minutes.',
                            style: GoogleFonts.inter(fontSize: 12, color: textMuted, height: 1.3),
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

              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: amber,
                    foregroundColor: const Color(0xFF09090B),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Save Schedule Rule',
                        style: GoogleFonts.inter(fontSize: 15.5, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.check_rounded, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDayPresetChip(String label, String id, bool isDark) {
    final cardBg = isDark ? const Color(0xFF18181B) : Colors.white;
    final borderCol = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E2E4);
    final textMain = isDark ? const Color(0xFFFAFAFA) : const Color(0xFF1A1C1D);

    return GestureDetector(
      onTap: () => _applyDayPreset(id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderCol),
        ),
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: textMain,
          ),
        ),
      ),
    );
  }

  Widget _buildDayPill(String label, int dayIndex, bool isDark) {
    final isSelected = _daysOfWeek.contains(dayIndex);
    final amber = const Color(0xFFF59E0B);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            if (_daysOfWeek.length > 1) _daysOfWeek.remove(dayIndex);
          } else {
            _daysOfWeek.add(dayIndex);
          }
        });
      },
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isSelected
              ? amber
              : (isDark ? const Color(0xFF18181B) : const Color(0xFFEEEEF0)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? amber : (isDark ? const Color(0xFF27272A) : const Color(0xFFE2E2E4)),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: isSelected ? const Color(0xFF09090B) : (isDark ? const Color(0xFFA1A1AA) : const Color(0xFF77767B)),
          ),
        ),
      ),
    );
  }
}
