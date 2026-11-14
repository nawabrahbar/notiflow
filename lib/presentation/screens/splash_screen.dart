import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/repositories/schedule_repository.dart';
import '../../platform/platform_factory.dart';
import '../theme/app_theme.dart';
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
  late final AnimationController _pulseController;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _startStartupFlow();
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startStartupFlow() async {
    final initFuture = widget.repository.initialize();
    final prefsFuture = SharedPreferences.getInstance();

    await Future.wait([initFuture, prefsFuture]);

    if (!mounted) return;

    _navigationTimer = Timer(const Duration(milliseconds: 2000), () async {
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
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkBackground : AppTheme.lightBackground;
    final textMain = isDark ? AppTheme.darkOnSurface : AppTheme.lightOnSurface;
    final textMuted = isDark ? AppTheme.darkOnSurfaceVariant : AppTheme.lightOnSurfaceVariant;
    final containerLow = isDark ? AppTheme.darkSurfaceContainerLow : AppTheme.lightSurfaceContainerLow;
    final borderCol = isDark ? AppTheme.darkOutlineVariant : AppTheme.lightOutlineVariant;
    final primary = isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary;
    final secondary = isDark ? AppTheme.darkSecondary : AppTheme.lightSecondary;
    final tertiary = isDark ? AppTheme.darkTertiary : AppTheme.lightTertiary;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isTablet = constraints.maxWidth >= 600;

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isTablet ? 640 : 420,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(height: 12),

                      // Central Medallion Core
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Tactile Medallion with Ambient Pulse Rings
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              final pulse = _pulseController.value;
                              return Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Outer atmospheric glow
                                  Container(
                                    width: (isTablet ? 180 : 150) + (pulse * 20),
                                    height: (isTablet ? 180 : 150) + (pulse * 20),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: primary.withOpacity(0.06 + (0.05 * (1 - pulse))),
                                    ),
                                  ),
                                  // Mid secondary pulse ring
                                  Container(
                                    width: (isTablet ? 160 : 135) + (pulse * 10),
                                    height: (isTablet ? 160 : 135) + (pulse * 10),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: secondary.withOpacity(0.10 + (0.05 * pulse)),
                                    ),
                                  ),
                                  // Tactile cardstock medallion
                                  Container(
                                    width: isTablet ? 130 : 110,
                                    height: isTablet ? 130 : 110,
                                    decoration: BoxDecoration(
                                      color: containerLow,
                                      borderRadius: BorderRadius.circular(isTablet ? 36 : 30),
                                      border: Border.all(
                                        color: borderCol.withOpacity(0.5),
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(isDark ? 0.35 : 0.08),
                                          blurRadius: 24,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    padding: const EdgeInsets.all(12),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(isTablet ? 26 : 22),
                                      child: Image.asset(
                                        'assets/icon/app_icon.png',
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 28),

                          // Editorial Serif Brand Headline
                          Text(
                            'Notiflow',
                            style: GoogleFonts.newsreader(
                              fontSize: isTablet ? 46 : 38,
                              fontWeight: FontWeight.w600,
                              color: textMain,
                              letterSpacing: -0.6,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Brand Positioning Subtitle
                          Text(
                            'Quiet the noise. Schedule your peace.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: isTablet ? 16 : 14.5,
                              fontWeight: FontWeight.w400,
                              color: textMuted,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Subdued Cadence Indicator (3 bouncing dots)
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, _) {
                              final p = _pulseController.value;
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _CadenceDot(color: primary, offset: (p * 5)),
                                  const SizedBox(width: 8),
                                  _CadenceDot(color: secondary, offset: ((1 - p) * 5)),
                                  const SizedBox(width: 8),
                                  _CadenceDot(color: tertiary, offset: (p * 4)),
                                ],
                              );
                            },
                          ),
                        ],
                      ),

                      // Bottom Security & Integrity Watermark (Zero borders)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: containerLow,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: borderCol.withOpacity(0.35),
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.lock_outline_rounded,
                                size: 15,
                                color: tertiary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '100% On-Device · Zero Telemetry',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: textMain,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CadenceDot extends StatelessWidget {
  final Color color;
  final double offset;

  const _CadenceDot({required this.color, required this.offset});

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(0, -offset),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
