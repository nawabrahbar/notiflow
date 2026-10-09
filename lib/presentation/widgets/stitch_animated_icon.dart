import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Animated Brand Icon faithful to Stitch's animated emblem.
/// Obsidian Signal theme with warm amber glow, revolving orbit arc,
/// floating focus shield, and silenced chime.
class StitchAnimatedIcon extends StatefulWidget {
  final double size;
  final bool animate;
  final Color? accentColor;

  const StitchAnimatedIcon({
    super.key,
    this.size = 180,
    this.animate = true,
    this.accentColor,
  });

  @override
  State<StitchAnimatedIcon> createState() => _StitchAnimatedIconState();
}

class _StitchAnimatedIconState extends State<StitchAnimatedIcon>
    with TickerProviderStateMixin {
  late final AnimationController _orbitController;
  late final AnimationController _pulseController;
  late final AnimationController _bounceController;

  @override
  void initState() {
    super.initState();
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    if (widget.animate) {
      _orbitController.repeat();
      _pulseController.repeat(reverse: true);
      _bounceController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _orbitController.dispose();
    _pulseController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = widget.accentColor ?? const Color(0xFFF59E0B);

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _orbitController,
          _pulseController,
          _bounceController,
        ]),
        builder: (context, _) {
          return CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _StitchIconPainter(
              orbitAngle: _orbitController.value * 2 * math.pi,
              pulseValue: _pulseController.value,
              bounceOffset: math.sin(_bounceController.value * math.pi) * 3.5,
              accentColor: accent,
              isDark: isDark,
            ),
          );
        },
      ),
    );
  }
}

class _StitchIconPainter extends CustomPainter {
  final double orbitAngle;
  final double pulseValue;
  final double bounceOffset;
  final Color accentColor;
  final bool isDark;

  _StitchIconPainter({
    required this.orbitAngle,
    required this.pulseValue,
    required this.bounceOffset,
    required this.accentColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final scale = size.width / 200.0;

    // 1. Ambient Radial Amber Glow behind icon
    final glowRadius = (75.0 + 8.0 * pulseValue) * scale;
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          accentColor.withValues(alpha: isDark ? (0.25 + 0.10 * pulseValue) : (0.15 + 0.08 * pulseValue)),
          accentColor.withValues(alpha: isDark ? 0.06 : 0.03),
          Colors.transparent,
        ],
        stops: const [0.0, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: glowRadius));
    canvas.drawCircle(center, glowRadius, glowPaint);

    // 2. Base Squircle Tile
    final tileWidth = 140.0 * scale;
    final tileRadius = Radius.circular(34.0 * scale);
    final tileRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: tileWidth, height: tileWidth),
      tileRadius,
    );

    final tilePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? const [Color(0xFF18181B), Color(0xFF09090B)]
            : const [Color(0xFFFFFFFF), Color(0xFFEEEEF0)],
      ).createShader(tileRect.outerRect);
    canvas.drawRRect(tileRect, tilePaint);

    // Squircle Border
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 * scale
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [const Color(0xFFF59E0B), const Color(0xFF78350F)]
            : [const Color(0xFFF59E0B), const Color(0xFFE2E2E4)],
      ).createShader(tileRect.outerRect);
    canvas.drawRRect(tileRect, borderPaint);

    // 3. Subtle Dial Ticks (Circle)
    final orbitRadius = 50.0 * scale;
    final dialPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 * scale
      ..color = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E2E4);
    canvas.drawCircle(center, orbitRadius, dialPaint);

    // 4. Precision Revolving Schedule Arc
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(orbitAngle);

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.8 * scale
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          accentColor.withValues(alpha: 0.8),
          const Color(0xFFFDE68A),
        ],
        stops: const [0.0, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: orbitRadius));

    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: orbitRadius),
      -math.pi / 2,
      math.pi * 0.9,
      false,
      arcPaint,
    );

    // Revolving beacon satellite dot
    final beaconPaint = Paint()
      ..color = const Color(0xFFFDE68A)
      ..maskFilter = MaskFilter.blur(BlurStyle.solid, 2.0 * scale);
    final beaconOffset = Offset(
      orbitRadius * math.cos(math.pi * 0.4),
      orbitRadius * math.sin(math.pi * 0.4),
    );
    canvas.drawCircle(beaconOffset, 3.2 * scale, beaconPaint);
    canvas.restore();

    // 5. Central Shield & Silenced Bell (with vertical bounce)
    final shieldCenter = Offset(center.dx, center.dy - bounceOffset * scale);

    // Shield Path
    final shieldPath = Path();
    final sw = 35.0 * scale;
    final sh = 42.0 * scale;
    shieldPath.moveTo(shieldCenter.dx, shieldCenter.dy - sh / 2);
    shieldPath.cubicTo(
      shieldCenter.dx + sw / 2,
      shieldCenter.dy - sh / 2,
      shieldCenter.dx + sw / 2,
      shieldCenter.dy,
      shieldCenter.dx,
      shieldCenter.dy + sh / 2,
    );
    shieldPath.cubicTo(
      shieldCenter.dx - sw / 2,
      shieldCenter.dy,
      shieldCenter.dx - sw / 2,
      shieldCenter.dy - sh / 2,
      shieldCenter.dx,
      shieldCenter.dy - sh / 2,
    );
    shieldPath.close();

    final shieldPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? const [Color(0xFF23252A), Color(0xFF141518)]
            : const [Color(0xFFE4E4E7), Color(0xFFF4F4F5)],
      ).createShader(shieldPath.getBounds());
    canvas.drawPath(shieldPath, shieldPaint);

    final shieldBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 * scale
      ..color = isDark ? const Color(0xFF383A42) : const Color(0xFFCBD5E1);
    canvas.drawPath(shieldPath, shieldBorder);

    // Silenced Bell inside Shield - Clean White bell as in official logo
    final bellPaint = Paint()
      ..color = isDark ? Colors.white : const Color(0xFF18181B);

    // Bell Top Loop
    final bellTopPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 * scale
      ..strokeCap = StrokeCap.round
      ..color = isDark ? Colors.white : const Color(0xFF18181B);
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(shieldCenter.dx, shieldCenter.dy - 10 * scale),
        width: 6 * scale,
        height: 6 * scale,
      ),
      math.pi,
      math.pi,
      false,
      bellTopPaint,
    );

    // Bell Dome
    final bellPath = Path();
    bellPath.moveTo(shieldCenter.dx - 8 * scale, shieldCenter.dy + 4 * scale);
    bellPath.quadraticBezierTo(
      shieldCenter.dx - 7 * scale,
      shieldCenter.dy - 6 * scale,
      shieldCenter.dx,
      shieldCenter.dy - 8 * scale,
    );
    bellPath.quadraticBezierTo(
      shieldCenter.dx + 7 * scale,
      shieldCenter.dy - 6 * scale,
      shieldCenter.dx + 8 * scale,
      shieldCenter.dy + 4 * scale,
    );
    bellPath.lineTo(shieldCenter.dx + 10 * scale, shieldCenter.dy + 7 * scale);
    bellPath.lineTo(shieldCenter.dx - 10 * scale, shieldCenter.dy + 7 * scale);
    bellPath.close();
    canvas.drawPath(bellPath, bellPaint);

    // Amber Bell Clapper as in official logo
    final clapperPaint = Paint()..color = const Color(0xFFF59E0B);
    canvas.drawCircle(
      Offset(shieldCenter.dx, shieldCenter.dy + 8.5 * scale),
      2.5 * scale,
      clapperPaint,
    );

    // 6. Diagonal Amber Silence Slash with dark outline backing
    final slashBackPaint = Paint()
      ..color = isDark ? const Color(0xFF09090B) : Colors.white
      ..strokeWidth = 3.2 * scale
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(shieldCenter.dx - 12 * scale, shieldCenter.dy - 11 * scale),
      Offset(shieldCenter.dx + 12 * scale, shieldCenter.dy + 12 * scale),
      slashBackPaint,
    );

    final slashForePaint = Paint()
      ..color = const Color(0xFFF59E0B)
      ..strokeWidth = 1.8 * scale
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(shieldCenter.dx - 11 * scale, shieldCenter.dy - 10 * scale),
      Offset(shieldCenter.dx + 11 * scale, shieldCenter.dy + 11 * scale),
      slashForePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _StitchIconPainter oldDelegate) {
    return oldDelegate.orbitAngle != orbitAngle ||
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.bounceOffset != bounceOffset ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.isDark != isDark;
  }
}
