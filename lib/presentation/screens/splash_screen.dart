import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/repositories/schedule_repository.dart';
import '../../platform/platform_factory.dart';
import '../widgets/stitch_animated_icon.dart';
import 'main_navigation_shell.dart';
import 'onboarding_screen.dart';
import 'permission_screen.dart';

class SplashScreen extends StatefulWidget {
  final ScheduleRepository repository;

  const SplashScreen({super.key, required this.repository});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progressController;
  late final Animation<double> _progressAnimation;
  String _statusText = 'Synchronizing local schedules...';

  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _progressAnimation = CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOutCubic,
    )..addListener(() {
        final val = _progressAnimation.value;
        String nextStatus;
        if (val < 0.45) {
          nextStatus = 'Synchronizing local schedules...';
        } else if (val < 0.82) {
          nextStatus = 'Calibrating silent triggers...';
        } else {
          nextStatus = 'Quiet engine active';
        }

        if (nextStatus != _statusText && mounted) {
          setState(() {
            _statusText = nextStatus;
          });
        }
      });

    _progressController.forward();
    _startStartupFlow();
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _startStartupFlow() async {
    final initFuture = widget.repository.initialize();
    final prefsFuture = SharedPreferences.getInstance();

    await Future.wait([initFuture, prefsFuture]);

    if (!mounted) return;

    _navigationTimer = Timer(const Duration(milliseconds: 1850), () async {
      if (!mounted) return;

      final prefs = await prefsFuture;
      final onboardingDone = prefs.getBool('pref_onboarding_completed') ?? false;

      if (!mounted) return;

      if (!onboardingDone) {
        _navigate(OnboardingScreen(repository: widget.repository));
        return;
      }

      final platform = PlatformFactory.createPlatformService();
      final isGranted = await platform.isNotificationAccessGranted();

      if (!mounted) return;

      if (!isGranted) {
        _navigate(
          PermissionScreen(
            repository: widget.repository,
            isInitialSetup: false,
          ),
        );
      } else {
        _navigate(MainNavigationShell(repository: widget.repository));
      }
    });
  }

  void _navigate(Widget screen) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF09090B) : const Color(0xFFF9F9FB);
    final cardBg = isDark ? const Color(0xFF18181B) : Colors.white;
    final borderCol = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E2E4);
    final textMain = isDark ? const Color(0xFFFAFAFA) : const Color(0xFF1A1C1D);
    final textMuted = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF47464B);
    final textFoot = isDark ? const Color(0xFF71717A) : const Color(0xFF71717A);
    final amber = const Color(0xFFF59E0B);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              // Top Brand Meta Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: borderCol),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: amber,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'DAEMON READY',
                          style: GoogleFonts.jetBrainsMono(
                            color: textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'v1.4.0',
                    style: GoogleFonts.jetBrainsMono(
                      color: textFoot,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              // Center Animated Emblem & Hero Typography
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const StitchAnimatedIcon(size: 190),
                    const SizedBox(height: 28),
                    Text(
                      'Notiflow',
                      style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: textMain,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Quiet focus, on your schedule',
                      style: GoogleFonts.inter(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                        color: textMuted,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Progress Track & Animated Fill
                    SizedBox(
                      width: 190,
                      child: Column(
                        children: [
                          Container(
                            height: 4,
                            width: 190,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF18181B)
                                  : const Color(0xFFEEEEF0),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: borderCol, width: 0.5),
                            ),
                            child: AnimatedBuilder(
                              animation: _progressAnimation,
                              builder: (context, _) {
                                return FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor:
                                      _progressAnimation.value.clamp(0.05, 1.0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFD97706),
                                          Color(0xFFF59E0B),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                      boxShadow: [
                                        BoxShadow(
                                          color: amber.withValues(alpha: 0.5),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Text(
                              _statusText,
                              key: ValueKey<String>(_statusText),
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: textMuted,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom Zero-Telemetry Security Pill
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: borderCol),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 14,
                      color: textFoot,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '100% ON-DEVICE · ZERO TELEMETRY',
                      style: GoogleFonts.jetBrainsMono(
                        color: textFoot,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
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
