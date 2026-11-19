import 'dart:ui' show ImageFilter;

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
  final bool showEmblem;

  const StitchHeader({
    super.key,
    this.title = 'Notiflow',
    this.onProfileTap,
    this.actions,
    this.showThemeToggle = true,
    this.showEmblem = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkBackground : AppTheme.lightBackground;
    final textMain = isDark ? AppTheme.darkOnSurface : AppTheme.lightOnSurface;

    return Container(
      height: preferredSize.height + MediaQuery.of(context).padding.top,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
        left: 20,
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
                if (showEmblem) ...[
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
                        isDark ? 'assets/icon/app_icon.png' : 'assets/icon/app_icon_light.png',
                        width: 32,
                        height: 32,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ],
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.headerTitleStyle(context, textMain),
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

/// Softens content at the top of its scroll viewport without blurring the header.
class HeaderScrollTransition extends StatefulWidget {
  const HeaderScrollTransition({
    super.key,
    required this.child,
    this.backgroundColor,
  });

  final Widget child;
  final Color? backgroundColor;

  @override
  State<HeaderScrollTransition> createState() => _HeaderScrollTransitionState();
}

class _HeaderScrollTransitionState extends State<HeaderScrollTransition> {
  bool _scrolled = false;

  void _updateScroll(ScrollMetrics metrics, int depth) {
    if (depth != 0 || metrics.axis != Axis.vertical) return;
    final scrolled = metrics.extentBefore > 0;
    if (_scrolled != scrolled) setState(() => _scrolled = scrolled);
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.backgroundColor ??
        (Theme.of(context).brightness == Brightness.dark
            ? AppTheme.darkBackground
            : AppTheme.lightBackground);

    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (notification) {
        _updateScroll(notification.metrics, notification.depth);
        return false;
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          _updateScroll(notification.metrics, notification.depth);
          return false;
        },
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            widget.child,
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 24,
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: AnimatedOpacity(
                    key: const ValueKey('header-scroll-fade'),
                    opacity: _scrolled ? 1 : 0,
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 150),
                    child: ClipRect(
                      child: ShaderMask(
                        blendMode: BlendMode.dstIn,
                        shaderCallback: (bounds) => const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white,
                            Colors.white,
                            Colors.transparent,
                          ],
                          stops: [0, 0.2, 1],
                        ).createShader(bounds),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  bg,
                                  bg.withValues(alpha: 0.65),
                                  bg.withValues(alpha: 0),
                                ],
                                stops: const [0, 0.35, 1],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Header Light/Dark toggle matching docs/design-reference:
/// - Phone light: "[sun] Light" pill on surface-container
/// - Phone dark: "Dark [moon]" pill with border and amber moon
/// - Tablet light: "[sun] Light" pill on secondary-fixed
/// - Tablet dark: "[moon] Dark" pill on surface-container-high in primary
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
        final bool isTablet = MediaQuery.sizeOf(context).width >= 600;

        final Widget pill = isTablet
            ? _buildTabletPill(isDark)
            : _buildPhonePill(isDark);

        return Semantics(
          button: true,
          label: 'Toggle theme',
          child: GestureDetector(
            onTap: () {
              updateAppThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
            },
            behavior: HitTestBehavior.opaque,
            child: pill,
          ),
        );
      },
    );
  }

  Widget _buildPhonePill(bool isDark) {
    final label = Text(
      isDark ? 'Dark' : 'Light',
      style: GoogleFonts.plusJakartaSans(
        fontSize: 11,
        height: 16 / 11,
        fontWeight: FontWeight.w600,
        color: isDark ? const Color(0xFFF3F4F1) : AppTheme.lightOnSurfaceVariant,
      ),
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2621) : AppTheme.lightSurfaceContainer,
        borderRadius: BorderRadius.circular(999),
        border: isDark ? Border.all(color: const Color(0xFF2A362F)) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: isDark
            ? [
                label,
                const SizedBox(width: 6),
                const Icon(Icons.dark_mode, size: 16, color: Color(0xFFF59E0B)),
              ]
            : [
                const Icon(Icons.light_mode_outlined, size: 16, color: AppTheme.lightPrimary),
                const SizedBox(width: 6),
                label,
              ],
      ),
    );
  }

  Widget _buildTabletPill(bool isDark) {
    final fg = isDark ? AppTheme.darkPrimary : const Color(0xFF171E06);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF272B29) : const Color(0xFFDEE7BF),
        borderRadius: BorderRadius.circular(999),
        border: isDark
            ? Border.all(color: const Color(0xFF514539).withOpacity(0.4))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
            size: 18,
            color: fg,
          ),
          const SizedBox(width: 8),
          Text(
            isDark ? 'Dark' : 'Light',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              height: 18 / 13,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
