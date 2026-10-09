import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../main.dart';

/// Top App Bar faithfully adhering to Stitch design specifications:
/// - Strictly displays only the Notiflow brand emblem and page title (no back arrow)
/// - Adaptive Light and Dark mode styling:
///   - Dark mode: Obsidian zinc background (#09090B), #27272A border, #FAFAFA high-contrast text
///   - Light mode: Crisp surface background (#F9F9FB), #E2E2E4 border, #1A1C1D high-contrast text
/// - Integrated interactive Theme Switch on the header across every page:
///   - Switch-style layout: Sun icon on left when Light mode is active ([☀️ Sun] Light), Moon icon on right when Dark mode is active (Dark [🌙 Moon])
///   - Responsive emblem icon that dynamically updates between light and dark modes
class StitchHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onProfileTap;
  final List<Widget>? actions;
  final bool showThemeToggle;

  const StitchHeader({
    super.key,
    this.title = 'Notification Handler',
    this.onProfileTap,
    this.actions,
    this.showThemeToggle = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF09090B) : const Color(0xFFF9F9FB);
    final borderCol = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E2E4);
    final textMain = isDark ? const Color(0xFFFAFAFA) : const Color(0xFF1A1C1D);
    final amber = const Color(0xFFF59E0B);

    return Container(
      height: preferredSize.height + MediaQuery.of(context).padding.top,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
        left: 16,
        right: 16,
      ),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.96),
        border: Border(
          bottom: BorderSide(color: borderCol, width: 0.8),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Adaptive Notiflow Emblem matching Stitch design
                Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF18181B) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E2E4),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/icon/app_icon.png',
                      width: 32,
                      height: 32,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: textMain,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: amber,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: amber.withValues(alpha: 0.5),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...?actions,
              if (showThemeToggle) ...[
                if (actions != null && actions!.isNotEmpty) const SizedBox(width: 6),
                const StitchThemeSwitch(),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Interactive Light/Dark mode header toggle faithfully matching Stitch design:
/// - Displays Sun icon on the left of text when Light mode is active ([☀️ Sun] Light)
/// - Displays Moon icon on the right of text when Dark mode is active (Dark [🌙 Moon])
/// - Hides Moon icon in Light mode and hides Sun icon in Dark mode
/// - Active icon highlights in Notiflow signal amber (#F59E0B)
class StitchThemeSwitch extends StatelessWidget {
  const StitchThemeSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, mode, _) {
        final platformBrightness = MediaQuery.maybePlatformBrightnessOf(context) ?? Brightness.light;
        final bool isDark = mode == ThemeMode.dark ||
            (mode == ThemeMode.system && platformBrightness == Brightness.dark);

        final bg = isDark ? const Color(0xFF18181B) : const Color(0xFFF1F1F4);
        final borderCol = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E2E4);
        final textCol = isDark ? const Color(0xFFFAFAFA) : const Color(0xFF1A1C1D);
        final amber = const Color(0xFFF59E0B);

        return GestureDetector(
          onTap: () {
            updateAppThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
          },
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderCol, width: 1.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Sun icon on the left when Light mode is active (hidden in Dark mode)
                if (!isDark) ...[
                  Icon(
                    Icons.wb_sunny_rounded,
                    size: 14,
                    color: amber,
                  ),
                  const SizedBox(width: 5),
                ],
                // Mode text in the middle
                Text(
                  isDark ? 'Dark' : 'Light',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: textCol,
                    letterSpacing: -0.2,
                  ),
                ),
                // Moon icon on the right when Dark mode is active (hidden in Light mode)
                if (isDark) ...[
                  const SizedBox(width: 5),
                  Icon(
                    Icons.nightlight_round,
                    size: 14,
                    color: amber,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
