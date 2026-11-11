import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../main.dart';
import '../theme/app_theme.dart';

/// Top App Bar faithfully adhering to Botanical design specifications:
/// - Strictly displays the Notiflow brand emblem and page title
/// - Seamless canvas flow: ZERO bottom border or divider line to give a single unified page effect
/// - Adaptive Light (Botanical Sanctuary) and Dark (Botanical Nocturne) mode styling:
///   - Dark mode: Deep forest canvas (#101412), #E0E3E0 high-contrast text, #FCBC76 accent
///   - Light mode: Warm sanctuary canvas (#FEF8F6), #1D1B1A high-contrast text, #7D562D accent
/// - Integrated interactive Theme Switch on the header across every page
class StitchHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onProfileTap;
  final List<Widget>? actions;
  final bool showThemeToggle;

  const StitchHeader({
    super.key,
    this.title = 'Notiflow',
    this.onProfileTap,
    this.actions,
    this.showThemeToggle = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkBackground : AppTheme.lightBackground;
    final textMain = isDark ? AppTheme.darkOnSurface : AppTheme.lightOnSurface;
    final accent = isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary;

    return Container(
      height: preferredSize.height + MediaQuery.of(context).padding.top,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
        left: 16,
        right: 16,
      ),
      decoration: BoxDecoration(
        color: bg,
        // Seamless design: NO bottom border and NO divider line
        border: null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Notiflow Emblem matching Botanical design
                Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurfaceContainer : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? AppTheme.darkOutlineVariant : AppTheme.lightOutlineVariant,
                      width: 1.0,
                    ),
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
                    style: GoogleFonts.newsreader(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
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
                    color: accent,
                    shape: BoxShape.circle,
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

/// Interactive Light/Dark mode header toggle faithfully matching Botanical design:
/// - Displays Sun icon on the left of text when Light mode is active ([☀️ Sun] Light)
/// - Displays Moon icon on the right of text when Dark mode is active (Dark [🌙 Moon])
/// - Seamless Botanical container styling
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

        final bg = isDark ? AppTheme.darkSurfaceContainer : AppTheme.lightSurfaceContainer;
        final borderCol = isDark ? AppTheme.darkOutlineVariant : AppTheme.lightOutlineVariant;
        final textCol = isDark ? AppTheme.darkOnSurface : AppTheme.lightOnSurface;
        final accent = isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary;

        return GestureDetector(
          onTap: () {
            updateAppThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
          },
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderCol, width: 1.0),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Sun icon on the left when Light mode is active (hidden in Dark mode)
                if (!isDark) ...[
                  Icon(
                    Icons.wb_sunny_rounded,
                    size: 14,
                    color: accent,
                  ),
                  const SizedBox(width: 5),
                ],
                // Mode text in the middle
                Text(
                  isDark ? 'Dark' : 'Light',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
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
                    color: accent,
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
