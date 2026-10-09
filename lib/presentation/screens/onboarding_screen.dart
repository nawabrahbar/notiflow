import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/repositories/schedule_repository.dart';
import '../../platform/notification_platform_interface.dart';
import '../../platform/platform_factory.dart';
import 'import_rules_screen.dart';
import '../widgets/restricted_settings_sheet.dart';

/// 3-Step Onboarding Journey faithfully implemented from Stitch UX.
/// Step 1: System Setup & Attention Ownership
/// Step 2: Permission Health & Notification Access
/// Step 3: Rules Import (Curated Presets / .notiflow Backup)
class OnboardingScreen extends StatefulWidget {
  final ScheduleRepository repository;

  const OnboardingScreen({super.key, required this.repository});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with WidgetsBindingObserver {
  final NotificationPlatformInterface _platform = PlatformFactory.createPlatformService();
  int _currentStep = 1; // 1, 2, or 3
  bool _isCheckingPermission = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _currentStep == 2) {
      _checkPermissionAndAdvance();
    }
  }

  Future<void> _checkPermissionAndAdvance() async {
    setState(() => _isCheckingPermission = true);
    try {
      final isGranted = await _platform.isNotificationAccessGranted();
      if (isGranted && mounted) {
        setState(() => _currentStep = 3);
      }
    } finally {
      if (mounted) setState(() => _isCheckingPermission = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF09090B) : const Color(0xFFF9F9FB);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: switch (_currentStep) {
            1 => _buildStepOne(isDark),
            2 => _buildStepTwo(isDark),
            _ => ImportRulesScreen(
                repository: widget.repository,
                isFromOnboarding: true,
              ),
          },
        ),
      ),
    );
  }

  // ===========================================================================
  // STEP 1: Cognitive Peace of Mind & Value Pillars
  // ===========================================================================
  Widget _buildStepOne(bool isDark) {
    final borderCol = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E2E4);
    final textMain = isDark ? const Color(0xFFFAFAFA) : const Color(0xFF1A1C1D);
    final textMuted = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF47464B);
    final amber = const Color(0xFFF59E0B);

    return ListView(
      key: const ValueKey('onboarding_step_1'),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      children: [
        // Top Meta Bar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF272014) : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: amber.withValues(alpha: 0.3)),
                  ),
                  child: Icon(Icons.shield_rounded, color: amber, size: 20),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notiflow',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: textMain,
                      ),
                    ),
                    Text(
                      'SOVEREIGN PROTOCOL',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: amber,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF27272A) : const Color(0xFFEEEEF0),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'STEP 1 OF 3',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: amber,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Hero Tag & Headline
        Text(
          'Take back control of your attention',
          style: GoogleFonts.inter(
            fontSize: 27,
            fontWeight: FontWeight.w800,
            color: textMain,
            letterSpacing: -0.7,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Silence distracting notifications on your schedule while letting critical alerts reach you.',
          style: GoogleFonts.inter(
            fontSize: 14.5,
            color: textMuted,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 20),

        // Metrics Banner (Obsidian Protocol)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF121214) : const Color(0xFFF3F3F5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderCol),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetricItem('LATENCY', '0.08ms', isDark),
              Container(width: 1, height: 26, color: borderCol),
              _buildMetricItem('NETWORK', '0 kb/s', isDark),
              Container(width: 1, height: 26, color: borderCol),
              _buildMetricItem('ISOLATION', '100%', isDark),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 3 Pillars
        _buildPillarCard(
          icon: Icons.tune_rounded,
          tag: 'RULES',
          title: 'Precision Scheduling',
          description: 'Set custom silent windows for specific distracting apps. Overnights, weekdays, or weekend shifts handled automatically.',
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _buildPillarCard(
          icon: Icons.shield_outlined,
          tag: 'OFFLINE',
          title: '100% On-Device Privacy',
          description: 'Zero cloud servers, zero analytics. Notiflow operates without an internet permission manifest, keeping all data on your phone.',
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _buildPillarCard(
          icon: Icons.bolt_rounded,
          tag: 'BYPASS',
          title: 'Unmanaged Apps Untouched',
          description: 'Non-configured apps bypass the gate instantly without interference, delay, or battery drain.',
          isDark: isDark,
        ),
        const SizedBox(height: 32),

        // Bottom CTA Button
        ElevatedButton(
          onPressed: () => setState(() => _currentStep = 2),
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
                'Get Started',
                style: GoogleFonts.inter(fontSize: 15.5, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded, size: 18),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildMetricItem(String label, String value, bool isDark) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF77767B),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: const Color(0xFFF59E0B),
          ),
        ),
      ],
    );
  }

  Widget _buildPillarCard({
    required IconData icon,
    required String tag,
    required String title,
    required String description,
    required bool isDark,
  }) {
    final cardBg = isDark ? const Color(0xFF18181B) : Colors.white;
    final borderCol = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E2E4);
    final textMain = isDark ? const Color(0xFFFAFAFA) : const Color(0xFF1A1C1D);
    final textMuted = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF47464B);
    final amber = const Color(0xFFF59E0B);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF272014) : const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: amber, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: textMain,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF27272A) : const Color(0xFFEEEEF0),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        tag,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: amber,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: textMuted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // STEP 2: Permission Health & Notification Access
  // ===========================================================================
  Widget _buildStepTwo(bool isDark) {
    final cardBg = isDark ? const Color(0xFF18181B) : Colors.white;
    final borderCol = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E2E4);
    final textMain = isDark ? const Color(0xFFFAFAFA) : const Color(0xFF1A1C1D);
    final textMuted = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF47464B);
    final amber = const Color(0xFFF59E0B);

    return ListView(
      key: const ValueKey('onboarding_step_2'),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      children: [
        // Top Meta Bar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF272014) : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: amber.withValues(alpha: 0.3)),
                  ),
                  child: Icon(Icons.shield_rounded, color: amber, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  'Notiflow',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: textMain,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF27272A) : const Color(0xFFEEEEF0),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'STEP 2 OF 3 · PERMISSION HEALTH',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: amber,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        Text(
          'Notification Access is required',
          style: GoogleFonts.inter(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: textMain,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'To silently filter notifications outside your chosen schedules, Android requires Notification Access permission for Notiflow.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: textMuted,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 24),

        // Diagnostic Steps Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderCol),
          ),
          child: Column(
            children: [
              _buildStepItem('1', 'Open Android Settings', 'Directs to phone\'s Device & app notifications', isDark),
              const SizedBox(height: 16),
              _buildStepItem('2', 'Find "Notiflow"', 'Locate Notiflow in the listener list', isDark),
              const SizedBox(height: 16),
              _buildStepItem('3', 'Switch Toggle to ON', 'Accept the Android system dialog', isDark),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Sideloaded APK Helper
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF272014) : const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: amber.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: amber, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Sideloaded APK blocked on Android 13+?',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: textMain,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'If Android grays out the toggle as a "Restricted Setting", unlock it in 2 taps via App Info.',
                style: GoogleFonts.inter(fontSize: 12.5, color: textMuted, height: 1.35),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => RestrictedSettingsSheet(),
                  );
                },
                child: Row(
                  children: [
                    Text(
                      'View 2-step unlock guide',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: amber,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, size: 14, color: amber),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // Primary Action
        ElevatedButton(
          onPressed: _isCheckingPermission
              ? null
              : () async {
                  await _platform.openNotificationAccessSettings();
                },
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
                'Open Android Settings',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.north_east_rounded, size: 18),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: () => setState(() => _currentStep = 3),
            child: Text(
              'Continue to Rule Setup',
              style: GoogleFonts.inter(
                fontSize: 13.5,
                color: textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepItem(String number, String title, String subtitle, bool isDark) {
    final amber = const Color(0xFFF59E0B);
    final textMain = isDark ? const Color(0xFFFAFAFA) : const Color(0xFF1A1C1D);
    final textMuted = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF47464B);

    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF272014) : const Color(0xFFFEF3C7),
            shape: BoxShape.circle,
            border: Border.all(color: amber.withValues(alpha: 0.5)),
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: amber,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: textMain,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
