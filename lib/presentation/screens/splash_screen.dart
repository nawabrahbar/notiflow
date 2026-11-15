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
    final borderCol = isDark ? AppTheme.darkOutlineVariant : AppTheme.lightOutlineVariant;
    final primary = isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary;
    final iconAsset = isDark ? 'assets/icon/app_icon.png' : 'assets/icon/app_icon_light.png';

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isTablet = constraints.maxWidth >= 600;
            final iconSize = isTablet ? 124.0 : 104.0;
            final ringSize = isTablet ? 168.0 : 144.0;

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isTablet ? 520 : 360,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // App Icon inside concentric dashed ring
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          final pulse = _pulseController.value;
                          return SizedBox(
                            width: ringSize,
                            height: ringSize,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CustomPaint(
                                  size: Size(ringSize, ringSize),
                                  painter: _DashedCirclePainter(
                                    color: borderCol.withValues(alpha: 0.55 + (0.25 * pulse)),
                                    strokeWidth: 1.2,
                                  ),
                                ),
                                Container(
                                  width: iconSize,
                                  height: iconSize,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(isTablet ? 30 : 26),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                                        blurRadius: 24,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(isTablet ? 30 : 26),
                                    child: Image.asset(
                                      iconAsset,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),

                      // Editorial Serif Brand Headline
                      Text(
                        'Notiflow',
                        style: GoogleFonts.newsreader(
                          fontSize: isTablet ? 44 : 36,
                          fontWeight: FontWeight.w600,
                          color: textMain,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Brand Positioning Tagline (regular + italic)
                      Text(
                        'Silence the noise.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: isTablet ? 16 : 14.5,
                          fontWeight: FontWeight.w400,
                          color: textMuted,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Protect what matters.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.newsreader(
                          fontSize: isTablet ? 17 : 15.5,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w400,
                          color: textMain.withValues(alpha: 0.9),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Thin horizontal progress bar
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, _) {
                          final progress = 0.35 + (0.55 * _pulseController.value);
                          return Container(
                            width: isTablet ? 220 : 185,
                            height: 3,
                            decoration: BoxDecoration(
                              color: borderCol.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: progress,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: primary,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 14),

                      Text(
                        'Waking on-device shield...',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: textMuted.withValues(alpha: 0.8),
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

class _DashedCirclePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const _DashedCirclePainter({
    required this.color,
    this.strokeWidth = 1.2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final radius = (size.shortestSide / 2) - strokeWidth;
    final center = Offset(size.width / 2, size.height / 2);
    const dashCount = 48;
    const sweepPerDash = (2 * 3.141592653589793) / dashCount;

    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * sweepPerDash;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepPerDash * 0.52,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}
