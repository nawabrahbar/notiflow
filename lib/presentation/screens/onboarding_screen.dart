import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/repositories/schedule_repository.dart';
import '../../platform/notification_platform_interface.dart';
import '../../platform/platform_factory.dart';
import '../theme/app_theme.dart';
import 'import_rules_screen.dart';

/// 3-Step Onboarding Journey faithfully adhering to Botanical Nocturne & Sanctuary UX:
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
    final bg = isDark ? AppTheme.darkBackground : AppTheme.lightBackground;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: switch (_currentStep) {
            1 => _buildStepOne(isDark),
            2 => _buildStepTwo(isDark),
            _ => ImportRulesScreen(repository: widget.repository),
          },
        ),
      ),
    );
  }

  Widget _buildTopMetaBar(String stepLabel, bool isDark) {
    final textMain = isDark ? AppTheme.darkOnSurface : AppTheme.lightOnSurface;
    final primary = isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary;
    final primaryContainer = isDark ? AppTheme.darkPrimaryContainer : AppTheme.lightPrimaryContainer;
    final cardBg = isDark ? AppTheme.darkSurfaceContainerLow : AppTheme.lightSurfaceContainerLow;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Notiflow',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: textMain,
            letterSpacing: -0.3,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: primaryContainer.withValues(alpha: 0.4)),
          ),
          child: Text(
            stepLabel,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: primary,
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // STEP 1: Cognitive Peace of Mind & Value Pillars
  // ===========================================================================
  Widget _buildStepOne(bool isDark) {
    final textMain = isDark ? AppTheme.darkOnSurface : AppTheme.lightOnSurface;
    final textMuted = isDark ? AppTheme.darkOnSurfaceVariant : AppTheme.lightOnSurfaceVariant;
    final primaryContainer = isDark ? AppTheme.darkPrimaryContainer : AppTheme.lightPrimaryContainer;
    final onPrimary = isDark ? AppTheme.darkOnPrimary : AppTheme.lightOnSurface;

    return ListView(
      key: const ValueKey('onboarding_step_1'),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      children: [
        _buildTopMetaBar('STEP 1 OF 3', isDark),
        const SizedBox(height: 28),

        Text(
          'Take back control of your attention',
          style: GoogleFonts.newsreader(
            fontSize: 32,
            fontWeight: FontWeight.w500,
            color: textMain,
            letterSpacing: -0.5,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Silence distracting notifications on your schedule while letting critical alerts reach you.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14.5,
            color: textMuted,
            height: 1.5,
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
          isGreenTag: false,
        ),
        const SizedBox(height: 12),
        _buildPillarCard(
          icon: Icons.shield_outlined,
          tag: 'OFFLINE',
          title: '100% On-Device Privacy',
          description: 'Zero cloud servers, zero analytics. Notiflow operates without an internet permission manifest, keeping all data on your phone.',
          isDark: isDark,
          isGreenTag: true,
        ),
        const SizedBox(height: 12),
        _buildPillarCard(
          icon: Icons.bolt_rounded,
          tag: 'BYPASS',
          title: 'Unmanaged Apps Untouched',
          description: 'Non-configured apps bypass the gate instantly without interference, delay, or battery drain.',
          isDark: isDark,
          isGreenTag: false,
        ),
        const SizedBox(height: 32),

        // Bottom CTA Button
        ElevatedButton(
          onPressed: () => setState(() => _currentStep = 2),
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryContainer,
            foregroundColor: onPrimary,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            elevation: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Get Started',
                style: GoogleFonts.plusJakartaSans(fontSize: 15.5, fontWeight: FontWeight.w700),
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

  Widget _buildPillarCard({
    required IconData icon,
    required String tag,
    required String title,
    required String description,
    required bool isDark,
    required bool isGreenTag,
  }) {
    final cardBg = isDark ? AppTheme.darkSurfaceContainerLow : AppTheme.lightSurfaceContainerLow;
    final borderCol = isDark ? AppTheme.darkOutlineVariant : AppTheme.lightOutlineVariant;
    final textMain = isDark ? AppTheme.darkOnSurface : AppTheme.lightOnSurface;
    final textMuted = isDark ? AppTheme.darkOnSurfaceVariant : AppTheme.lightOnSurfaceVariant;
    final primary = isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary;
    final secondary = isDark ? AppTheme.darkSecondary : AppTheme.lightSecondary;
    final secContainer = isDark ? AppTheme.darkSecondaryContainer : AppTheme.lightSecondaryContainer;
    final iconColor = isGreenTag ? secondary : primary;
    final iconBg = isGreenTag
        ? secContainer.withValues(alpha: 0.6)
        : primary.withValues(alpha: 0.14);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol.withValues(alpha: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: iconColor.withValues(alpha: 0.25)),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: textMain,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: iconColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        tag,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: iconColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: textMuted,
                    height: 1.45,
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
    final cardBg = isDark ? AppTheme.darkSurfaceContainerLow : AppTheme.lightSurfaceContainerLow;
    final borderCol = isDark ? AppTheme.darkOutlineVariant : AppTheme.lightOutlineVariant;
    final textMain = isDark ? AppTheme.darkOnSurface : AppTheme.lightOnSurface;
    final textMuted = isDark ? AppTheme.darkOnSurfaceVariant : AppTheme.lightOnSurfaceVariant;
    final primaryContainer = isDark ? AppTheme.darkPrimaryContainer : AppTheme.lightPrimaryContainer;
    final onPrimary = isDark ? AppTheme.darkOnPrimary : AppTheme.lightOnSurface;

    return ListView(
      key: const ValueKey('onboarding_step_2'),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      children: [
        _buildTopMetaBar('STEP 2 OF 3', isDark),
        const SizedBox(height: 28),

        Text(
          'Notification Access is required',
          style: GoogleFonts.newsreader(
            fontSize: 30,
            fontWeight: FontWeight.w500,
            color: textMain,
            letterSpacing: -0.5,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'To silently filter notifications outside your chosen schedules, Android requires Notification Access permission for Notiflow.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: textMuted,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),

        // Diagnostic Steps Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderCol.withValues(alpha: 0.6)),
          ),
          child: Column(
            children: [
              _buildStepItem(
                '1',
                'Open Android Settings',
                'Directs to phone\'s Device & app notifications',
                isDark,
              ),
              Divider(color: borderCol.withValues(alpha: 0.4), height: 24),
              _buildStepItem(
                '2',
                'Find “Notiflow”',
                'Locate Notiflow in the listener list',
                isDark,
              ),
              Divider(color: borderCol.withValues(alpha: 0.4), height: 24),
              _buildStepItem(
                '3',
                'Switch Toggle to ON',
                'Accept the Android system dialog',
                isDark,
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // Primary Action
        ElevatedButton(
          onPressed: _isCheckingPermission
              ? null
              : () async {
                  await _platform.openNotificationAccessSettings();
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryContainer,
            foregroundColor: onPrimary,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            elevation: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Open Android Settings',
                style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700),
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
              style: GoogleFonts.plusJakartaSans(
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
    final primary = isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary;
    final textMain = isDark ? AppTheme.darkOnSurface : AppTheme.lightOnSurface;
    final textMuted = isDark ? AppTheme.darkOnSurfaceVariant : AppTheme.lightOnSurfaceVariant;

    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.14),
            shape: BoxShape.circle,
            border: Border.all(color: primary.withValues(alpha: 0.4)),
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: primary,
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
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: textMain,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
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
