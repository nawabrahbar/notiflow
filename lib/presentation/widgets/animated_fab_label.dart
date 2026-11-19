import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';

class AnimatedFabLabel extends StatelessWidget {
  const AnimatedFabLabel({
    super.key,
    required this.extended,
    required this.label,
  });

  final bool extended;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: extended ? 1 : 0),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 250),
      curve: Curves.easeInOutCubic,
      builder: (context, value, child) => ClipRect(
        child: Align(
          alignment: Alignment.centerLeft,
          widthFactor: value,
          child: Opacity(opacity: value, child: child),
        ),
      ),
      child: ExcludeSemantics(
        excluding: !extended,
        child: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
