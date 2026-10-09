import 'package:flutter/material.dart';

/// Custom toggle switch matching the Stitch Obsidian Signal specifications:
/// - Smooth animated sliding thumb
/// - 48px width x 28px height
/// - Dark mode: Signal Amber (#F59E0B) track with Obsidian (#09090B) thumb when active;
///   Zinc (#27272A) track with Slate (#71717A) thumb when inactive.
/// - Light mode: Amber (#904D00 / #F59E0B) track with crisp White (#FFFFFF) thumb when active;
///   Surface (#E2E2E4) track with White (#FFFFFF) thumb when inactive.
class StitchSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? activeTrackColor;
  final Color? inactiveTrackColor;

  const StitchSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeTrackColor,
    this.inactiveTrackColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final activeTrack = activeTrackColor ??
        (isDark ? const Color(0xFFF59E0B) : const Color(0xFF904D00));
    final inactiveTrack = inactiveTrackColor ??
        (isDark ? const Color(0xFF27272A) : const Color(0xFFE2E2E4));

    final activeThumb = isDark ? const Color(0xFF09090B) : const Color(0xFFFFFFFF);
    final inactiveThumb = isDark ? const Color(0xFF71717A) : const Color(0xFFFFFFFF);

    return Semantics(
      toggled: value,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          width: 48,
          height: 28,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: value ? activeTrack : inactiveTrack,
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: value ? activeThumb : inactiveThumb,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.12),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
