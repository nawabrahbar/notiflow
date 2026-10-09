import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/repositories/schedule_repository.dart';
import '../../domain/models/rule_preset.dart';
import '../widgets/stitch_header.dart';
import 'main_navigation_shell.dart';

/// Screen 4 / Step 3: Import Rules Screen.
/// Matches Stitch redesign: obsidian signal theme with amber accents,
/// curated preset selection, and custom .notiflow JSON file import.
class ImportRulesScreen extends StatefulWidget {
  final ScheduleRepository repository;
  final bool isFromOnboarding;

  const ImportRulesScreen({
    super.key,
    required this.repository,
    this.isFromOnboarding = false,
  });

  @override
  State<ImportRulesScreen> createState() => _ImportRulesScreenState();
}

class _ImportRulesScreenState extends State<ImportRulesScreen> {
  String _selectedPresetId = 'deep_work';
  bool _isProcessing = false;
  String? _statusMessage;
  bool _isSuccessMessage = true;

  final List<RulePreset> _presets = RulePreset.curatedPresets;

  Future<void> _handleChooseFile() async {
    // Show modal allowing user to either paste JSON or select file
    final TextEditingController jsonController = TextEditingController();

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final sheetBg = isDark ? const Color(0xFF18181B) : Colors.white;
        final textColor = isDark ? const Color(0xFFFAFAFA) : const Color(0xFF1A1C1D);
        final subTextColor = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF47464B);
        final borderCol = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E2E4);

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: sheetBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: borderCol),
            ),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Import .notiflow Backup',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Paste your .notiflow JSON content below to restore all schedules and managed app rules.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: subTextColor,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: jsonController,
                  maxLines: 6,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    color: textColor,
                  ),
                  decoration: InputDecoration(
                    hintText: '{\n  "app": "Notiflow",\n  "schedules": [...]\n}',
                    hintStyle: GoogleFonts.jetBrainsMono(
                      color: isDark ? const Color(0xFF52525B) : const Color(0xFF94A3B8),
                      fontSize: 12,
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF09090B) : const Color(0xFFF9F9FB),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderCol),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textColor,
                          side: BorderSide(color: borderCol),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          final text = jsonController.text.trim();
                          if (text.isNotEmpty) {
                            Navigator.pop(context, text);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF59E0B),
                          foregroundColor: const Color(0xFF09090B),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          'Restore JSON',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        _isProcessing = true;
        _statusMessage = null;
      });

      final success = await widget.repository.importRulesJson(result);
      setState(() {
        _isProcessing = false;
        if (success) {
          _statusMessage = 'Rules successfully restored from .notiflow backup!';
          _isSuccessMessage = true;
        } else {
          _statusMessage = 'Invalid .notiflow backup format. Please verify JSON schema.';
          _isSuccessMessage = false;
        }
      });

      if (success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup restored successfully!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
        _finishFlow();
      }
    }
  }

  Future<void> _handleApplyPreset() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = null;
    });

    final preset = _presets.firstWhere(
      (p) => p.id == _selectedPresetId,
      orElse: () => _presets.first,
    );

    await widget.repository.applyPreset(preset, replaceAll: false);

    setState(() {
      _isProcessing = false;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Applied "${preset.title}" rules!'),
        backgroundColor: const Color(0xFFF59E0B),
      ),
    );
    _finishFlow();
  }

  void _finishFlow() {
    if (widget.isFromOnboarding) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => MainNavigationShell(repository: widget.repository),
        ),
        (route) => false,
      );
    } else {
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

    return Scaffold(
      backgroundColor: bg,
      appBar: StitchHeader(
        title: widget.isFromOnboarding ? 'Setup Rules' : 'Import Rules',
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Step Pill
              if (widget.isFromOnboarding)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF27272A) : const Color(0xFFEEEEF0),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: borderCol),
                  ),
                  child: Text(
                    'STEP 3 OF 3 · RULES IMPORT',
                    style: GoogleFonts.jetBrainsMono(
                      color: amber,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              const SizedBox(height: 12),

              // Title & Subtitle
              Text(
                'Import Rules',
                style: GoogleFonts.inter(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: textMain,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Restore rules from an exported backup or start fresh with defaults.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: textMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              // Status message banner if any
              if (_statusMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isSuccessMessage
                        ? (isDark ? const Color(0xFF052E16) : const Color(0xFFDCFCE7))
                        : (isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isSuccessMessage
                          ? const Color(0xFF22C55E)
                          : const Color(0xFFEF4444),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isSuccessMessage ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                        color: _isSuccessMessage
                            ? const Color(0xFF22C55E)
                            : const Color(0xFFEF4444),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _statusMessage!,
                          style: GoogleFonts.inter(
                            color: _isSuccessMessage
                                ? (isDark ? const Color(0xFF86EFAC) : const Color(0xFF166534))
                                : (isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B)),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Card: Upload .notiflow JSON
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderCol),
                ),
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF272014) : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.file_upload_outlined, color: amber, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Upload .notiflow JSON',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: textMain,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Select an encrypted rule export from device storage or your local archive.',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: textMuted,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isProcessing ? null : _handleChooseFile,
                        icon: const Icon(Icons.attach_file_rounded, size: 18),
                        label: Text(
                          'Choose File / Paste JSON',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? const Color(0xFFFAFAFA) : const Color(0xFF1A1C1D),
                          side: BorderSide(color: borderCol),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Divider with Presets Label
              Row(
                children: [
                  Expanded(child: Divider(color: borderCol)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'OR START WITH CURATED PRESETS',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: textMuted,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: borderCol)),
                ],
              ),

              const SizedBox(height: 18),

              // Curated Presets Cards
              ..._presets.map((preset) {
                final isSelected = _selectedPresetId == preset.id;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedPresetId = preset.id;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? amber : borderCol,
                        width: isSelected ? 1.8 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: amber.withValues(alpha: 0.12),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ]
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? (isDark ? const Color(0xFF272014) : const Color(0xFFFEF3C7))
                                    : (isDark ? const Color(0xFF27272A) : const Color(0xFFEEEEF0)),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                preset.icon,
                                color: isSelected ? amber : textMuted,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                preset.title,
                                style: GoogleFonts.inter(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700,
                                  color: textMain,
                                ),
                              ),
                            ),
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected ? amber : Colors.transparent,
                                border: Border.all(
                                  color: isSelected ? amber : textMuted,
                                  width: 2,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check,
                                      size: 14,
                                      color: Color(0xFF09090B),
                                    )
                                  : null,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          preset.description,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: textMuted,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: preset.badges.map((b) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF27272A) : const Color(0xFFEEEEF0),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                b,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? amber : textMuted,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                );
              }),

              const SizedBox(height: 24),

              // Bottom Actions
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _handleApplyPreset,
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
                        'Apply Preset & Finish',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _finishFlow,
                  child: Text(
                    widget.isFromOnboarding ? 'Set Up Rules Later' : 'Cancel',
                    style: GoogleFonts.inter(
                      color: textMuted,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Bottom trust indicator
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_outlined, size: 13, color: textMuted),
                    const SizedBox(width: 6),
                    Text(
                      '100% ON-DEVICE · ZERO TELEMETRY',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: textMuted,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
