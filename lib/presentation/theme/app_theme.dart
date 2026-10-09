import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App-wide theme configuration for Notiflow.
/// Implements the Obsidian Signal design system from Stitch:
/// - Dark Mode: Deep Zinc/Obsidian (#09090B), Card (#18181B), Amber Signal Accent (#F59E0B)
/// - Light Mode: Clean Soft Surface (#F9F9FB), White Card (#FFFFFF), Amber/Deep Contrast (#F59E0B)
/// - Typography: Google Fonts Inter for text & JetBrains Mono for numerical counters/chips
class AppTheme {
  // Brand Signal Colors
  static const Color amberPrimary = Color(0xFFF59E0B);
  static const Color amberLight = Color(0xFFFBBF24);
  static const Color amberDim = Color(0xFFFEF3C7);
  static const Color amberDark = Color(0xFFD97706);
  static const Color amberContainerDark = Color(0xFF272014);

  // Status & Signal Indicators
  static const Color signalSuccess = Color(0xFF22C55E);
  static const Color signalError = Color(0xFFEF4444);
  static const Color signalWarning = Color(0xFFF59E0B);
  static const Color signalHeld = Color(0xFFF87171);

  // Dark Theme Tokens (Obsidian Signal)
  static const Color darkBackground = Color(0xFF09090B);
  static const Color darkSurface = Color(0xFF09090B);
  static const Color darkSurfaceContainerLowest = Color(0xFF0C0C0E);
  static const Color darkSurfaceContainerLow = Color(0xFF121214);
  static const Color darkSurfaceContainer = Color(0xFF18181B);
  static const Color darkSurfaceContainerHigh = Color(0xFF222226);
  static const Color darkSurfaceContainerHighest = Color(0xFF27272A);
  static const Color darkOnSurface = Color(0xFFFAFAFA);
  static const Color darkOnSurfaceVariant = Color(0xFFA1A1AA);
  static const Color darkOutline = Color(0xFF3F3F46);
  static const Color darkOutlineVariant = Color(0xFF27272A);

  // Light Theme Tokens
  static const Color lightBackground = Color(0xFFF9F9FB);
  static const Color lightSurface = Color(0xFFF9F9FB);
  static const Color lightSurfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color lightSurfaceContainerLow = Color(0xFFF3F3F5);
  static const Color lightSurfaceContainer = Color(0xFFEEEEF0);
  static const Color lightSurfaceContainerHigh = Color(0xFFE8E8EA);
  static const Color lightSurfaceContainerHighest = Color(0xFFE2E2E4);
  static const Color lightOnSurface = Color(0xFF1A1C1D);
  static const Color lightOnSurfaceVariant = Color(0xFF47464B);
  static const Color lightOutline = Color(0xFF77767B);
  static const Color lightOutlineVariant = Color(0xFFE2E2E4);

  // Backward-compatible design token aliases (defaults to Dark/Signal tokens)
  static const Color primaryTeal = amberPrimary;
  static const Color primaryDarkTeal = amberDark;
  static const Color primaryLightTeal = amberLight;
  static const Color tertiaryAmber = amberPrimary;
  static const Color tertiaryContainer = amberContainerDark;
  static const Color secondaryContainer = amberContainerDark;

  static const Color surface = darkSurface;
  static const Color surfaceContainerLowest = darkSurfaceContainerLowest;
  static const Color surfaceContainerLow = darkSurfaceContainerLow;
  static const Color surfaceContainer = darkSurfaceContainer;
  static const Color surfaceContainerHigh = darkSurfaceContainerHigh;
  static const Color surfaceContainerHighest = darkSurfaceContainerHighest;
  static const Color onSurface = darkOnSurface;
  static const Color onSurfaceVariant = darkOnSurfaceVariant;
  static const Color outline = darkOutline;
  static const Color outlineVariant = darkOutlineVariant;
  static const Color primaryContainer = amberContainerDark;

  static ThemeData get lightTheme {
    final textTheme = GoogleFonts.interTextTheme().apply(
      bodyColor: lightOnSurface,
      displayColor: lightOnSurface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: amberPrimary,
        onPrimary: Color(0xFF09090B),
        primaryContainer: amberDim,
        onPrimaryContainer: Color(0xFF78350F),
        secondary: amberDark,
        secondaryContainer: Color(0xFFFFDCC3),
        onSecondaryContainer: Color(0xFF663500),
        surface: lightSurface,
        onSurface: lightOnSurface,
        onSurfaceVariant: lightOnSurfaceVariant,
        outline: lightOutline,
        outlineVariant: lightOutlineVariant,
        error: Color(0xFFBA1A1A),
        onError: Colors.white,
        errorContainer: Color(0xFFFFDAD6),
      ),
      scaffoldBackgroundColor: lightBackground,
      textTheme: textTheme,
      cardTheme: CardThemeData(
        color: lightSurfaceContainerLowest,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: lightOutlineVariant, width: 1),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: lightBackground.withValues(alpha: 0.95),
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          color: lightOnSurface,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: lightOnSurface),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: amberPrimary,
          foregroundColor: const Color(0xFF09090B),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: lightOnSurface,
          side: const BorderSide(color: lightOutlineVariant),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return amberPrimary;
          }
          return const Color(0xFFCBD5E1);
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.transparent;
          }
          return const Color(0xFF94A3B8);
        }),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: amberDark,
        unselectedItemColor: lightOnSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }

  static ThemeData get darkTheme {
    final textTheme = GoogleFonts.interTextTheme().apply(
      bodyColor: darkOnSurface,
      displayColor: darkOnSurface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: amberPrimary,
        onPrimary: Color(0xFF09090B),
        primaryContainer: amberContainerDark,
        onPrimaryContainer: amberPrimary,
        secondary: amberPrimary,
        secondaryContainer: amberContainerDark,
        onSecondaryContainer: amberPrimary,
        surface: darkSurface,
        onSurface: darkOnSurface,
        onSurfaceVariant: darkOnSurfaceVariant,
        outline: darkOutline,
        outlineVariant: darkOutlineVariant,
        error: signalError,
        onError: Colors.white,
        errorContainer: Color(0xFF450A0A),
      ),
      scaffoldBackgroundColor: darkBackground,
      textTheme: textTheme,
      cardTheme: CardThemeData(
        color: darkSurfaceContainer,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: darkOutlineVariant, width: 1),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: darkBackground.withValues(alpha: 0.95),
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          color: darkOnSurface,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: darkOnSurface),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: amberPrimary,
          foregroundColor: const Color(0xFF09090B),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkOnSurface,
          side: const BorderSide(color: darkOutlineVariant),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return amberPrimary;
          }
          return const Color(0xFF27272A);
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.transparent;
          }
          return const Color(0xFF3F3F46);
        }),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkSurface,
        selectedItemColor: amberPrimary,
        unselectedItemColor: darkOnSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }
}
