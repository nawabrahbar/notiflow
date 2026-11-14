import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App-wide theme configuration for Notiflow.
/// Implements the Botanical Sanctuary (Light) and Botanical Nocturne (Dark) design systems:
/// - Light Mode: Warm Canvas (#FEF8F6), Earthy Terracotta (#7D562D), Sage Green (#5A6242)
/// - Dark Mode: Deep Forest (#101412), Golden Ochre/Terracotta (#FCBC76), Sage (#BECCA3)
/// - Typography: Google Fonts Newsreader for display/headlines, Plus Jakarta Sans for body/labels
/// - Seamless Navigation: Zero header bottom border and zero shadow elevation across all surfaces
class AppTheme {
  // Status & Signal Indicators
  static const Color signalSuccess = Color(0xFF22C55E);
  static const Color signalError = Color(0xFFEF4444);
  static const Color signalWarning = Color(0xFFF59E0B);
  static const Color signalHeld = Color(0xFFF87171);
  static const Color toastSuccess = signalSuccess;
  static const Color toastWarning = signalWarning;
  static const Color toastError = signalError;

  // Botanical Sanctuary (Light Mode) Tokens
  static const Color lightBackground = Color(0xFFFEF8F6);
  static const Color lightSurface = Color(0xFFFEF8F6);
  static const Color lightSurfaceDim = Color(0xFFDED9D7);
  static const Color lightSurfaceBright = Color(0xFFFEF8F6);
  static const Color lightSurfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color lightSurfaceContainerLow = Color(0xFFF8F2F0);
  static const Color lightSurfaceContainer = Color(0xFFF2EDEB);
  static const Color lightSurfaceContainerHigh = Color(0xFFEDE7E5);
  static const Color lightSurfaceContainerHighest = Color(0xFFE7E1DF);
  static const Color lightOnSurface = Color(0xFF1D1B1A);
  static const Color lightOnSurfaceVariant = Color(0xFF50453B);
  static const Color lightOutline = Color(0xFF82756A);
  static const Color lightOutlineVariant = Color(0xFFD4C4B7);
  static const Color lightPrimary = Color(0xFF7D562D);
  static const Color lightOnPrimary = Color(0xFFFFFFFF);
  static const Color lightPrimaryContainer = Color(0xFFD4A373);
  static const Color lightOnPrimaryContainer = Color(0xFF5B3912);
  static const Color lightSecondary = Color(0xFF5A6242);
  static const Color lightOnSecondary = Color(0xFFFFFFFF);
  static const Color lightSecondaryContainer = Color(0xFFDEE7BF);
  static const Color lightOnSecondaryContainer = Color(0xFF606848);
  static const Color lightTertiary = Color(0xFF5C6145);
  static const Color lightTertiaryContainer = Color(0xFFABAF8E);
  static const Color lightError = Color(0xFFBA1A1A);

  // Botanical Nocturne (Dark Mode) Tokens
  static const Color darkBackground = Color(0xFF101412);
  static const Color darkSurface = Color(0xFF101412);
  static const Color darkSurfaceDim = Color(0xFF101412);
  static const Color darkSurfaceBright = Color(0xFF363A38);
  static const Color darkSurfaceContainerLowest = Color(0xFF0B0F0D);
  static const Color darkSurfaceContainerLow = Color(0xFF181C1A);
  static const Color darkSurfaceContainer = Color(0xFF1C201E);
  static const Color darkSurfaceContainerHigh = Color(0xFF272B29);
  static const Color darkSurfaceContainerHighest = Color(0xFF323633);
  static const Color darkOnSurface = Color(0xFFE0E3E0);
  static const Color darkOnSurfaceVariant = Color(0xFFD5C3B4);
  static const Color darkOutline = Color(0xFF9E8E80);
  static const Color darkOutlineVariant = Color(0xFF514539);
  static const Color darkPrimary = Color(0xFFFCBC76);
  static const Color darkOnPrimary = Color(0xFF482900);
  static const Color darkPrimaryContainer = Color(0xFFDDA15E);
  static const Color darkOnPrimaryContainer = Color(0xFF5F3800);
  static const Color darkSecondary = Color(0xFFBECCA3);
  static const Color darkOnSecondary = Color(0xFF293417);
  static const Color darkSecondaryContainer = Color(0xFF414D2E);
  static const Color darkOnSecondaryContainer = Color(0xFFB0BE96);
  static const Color darkTertiary = Color(0xFFA7D4A3);
  static const Color darkTertiaryContainer = Color(0xFF8CB889);
  static const Color darkError = Color(0xFFFFB4AB);

  // Backward-compatible design token aliases (defaults to Dark/Botanical tokens)
  static const Color amberPrimary = darkPrimary;
  static const Color amberLight = darkPrimary;
  static const Color amberDim = darkPrimaryContainer;
  static const Color amberDark = darkOnPrimaryContainer;
  static const Color amberContainerDark = darkSecondaryContainer;

  static const Color primaryTeal = darkPrimary;
  static const Color primaryDarkTeal = darkPrimary;
  static const Color primaryLightTeal = darkPrimary;
  static const Color tertiaryAmber = darkPrimary;
  static const Color tertiaryContainer = darkSecondaryContainer;
  static const Color secondaryContainer = darkSecondaryContainer;

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
  static const Color primaryContainer = darkPrimaryContainer;

  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.plusJakartaSansTextTheme().apply(
      bodyColor: lightOnSurface,
      displayColor: lightOnSurface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: lightPrimary,
        onPrimary: lightOnPrimary,
        primaryContainer: lightPrimaryContainer,
        onPrimaryContainer: lightOnPrimaryContainer,
        secondary: lightSecondary,
        onSecondary: lightOnSecondary,
        secondaryContainer: lightSecondaryContainer,
        onSecondaryContainer: lightOnSecondaryContainer,
        surface: lightSurface,
        onSurface: lightOnSurface,
        onSurfaceVariant: lightOnSurfaceVariant,
        outline: lightOutline,
        outlineVariant: lightOutlineVariant,
        error: lightError,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: lightBackground,
      textTheme: baseTextTheme.copyWith(
        displayLarge: GoogleFonts.newsreader(
          fontSize: 48,
          fontWeight: FontWeight.w400,
          color: lightOnSurface,
          height: 1.16,
        ),
        displayMedium: GoogleFonts.newsreader(
          fontSize: 36,
          fontWeight: FontWeight.w500,
          color: lightOnSurface,
          height: 1.22,
        ),
        displaySmall: GoogleFonts.newsreader(
          fontSize: 28,
          fontWeight: FontWeight.w500,
          color: lightOnSurface,
          height: 1.28,
        ),
        headlineLarge: GoogleFonts.newsreader(
          fontSize: 32,
          fontWeight: FontWeight.w400,
          color: lightOnSurface,
          height: 1.25,
        ),
        headlineMedium: GoogleFonts.newsreader(
          fontSize: 26,
          fontWeight: FontWeight.w500,
          color: lightOnSurface,
          height: 1.3,
        ),
        headlineSmall: GoogleFonts.newsreader(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: lightOnSurface,
          height: 1.36,
        ),
        titleLarge: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: lightOnSurface,
          letterSpacing: -0.2,
        ),
        titleMedium: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: lightOnSurface,
          letterSpacing: -0.2,
        ),
        titleSmall: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: lightOnSurface,
        ),
        bodyLarge: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w400,
          color: lightOnSurface,
          height: 1.55,
        ),
        bodyMedium: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: lightOnSurface,
          height: 1.6,
        ),
        bodySmall: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: lightOnSurfaceVariant,
          height: 1.5,
        ),
        labelLarge: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: lightOnSurface,
        ),
        labelMedium: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: lightOnSurfaceVariant,
        ),
        labelSmall: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: lightOnSurfaceVariant,
        ),
      ),
      cardTheme: CardThemeData(
        color: lightSurfaceContainerLow,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: lightOutlineVariant, width: 1),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: lightBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.newsreader(
          color: lightOnSurface,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: lightOnSurface),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lightPrimary,
          foregroundColor: lightOnPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
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
          textStyle: GoogleFonts.plusJakartaSans(
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
            return lightPrimary;
          }
          return lightOutlineVariant;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.transparent;
          }
          return lightOutline;
        }),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: lightSurface,
        selectedItemColor: lightPrimary,
        unselectedItemColor: lightOnSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: signalSuccess,
        contentTextStyle: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.fixed,
      ),
    );
  }

  static ThemeData get darkTheme {
    final baseTextTheme = GoogleFonts.plusJakartaSansTextTheme().apply(
      bodyColor: darkOnSurface,
      displayColor: darkOnSurface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: darkPrimary,
        onPrimary: darkOnPrimary,
        primaryContainer: darkPrimaryContainer,
        onPrimaryContainer: darkOnPrimaryContainer,
        secondary: darkSecondary,
        onSecondary: darkOnSecondary,
        secondaryContainer: darkSecondaryContainer,
        onSecondaryContainer: darkOnSecondaryContainer,
        surface: darkSurface,
        onSurface: darkOnSurface,
        onSurfaceVariant: darkOnSurfaceVariant,
        outline: darkOutline,
        outlineVariant: darkOutlineVariant,
        error: darkError,
        onError: const Color(0xFF690005),
      ),
      scaffoldBackgroundColor: darkBackground,
      textTheme: baseTextTheme.copyWith(
        displayLarge: GoogleFonts.newsreader(
          fontSize: 48,
          fontWeight: FontWeight.w400,
          color: darkOnSurface,
          height: 1.16,
        ),
        displayMedium: GoogleFonts.newsreader(
          fontSize: 36,
          fontWeight: FontWeight.w500,
          color: darkOnSurface,
          height: 1.22,
        ),
        displaySmall: GoogleFonts.newsreader(
          fontSize: 28,
          fontWeight: FontWeight.w500,
          color: darkOnSurface,
          height: 1.28,
        ),
        headlineLarge: GoogleFonts.newsreader(
          fontSize: 32,
          fontWeight: FontWeight.w400,
          color: darkOnSurface,
          height: 1.25,
        ),
        headlineMedium: GoogleFonts.newsreader(
          fontSize: 26,
          fontWeight: FontWeight.w500,
          color: darkOnSurface,
          height: 1.3,
        ),
        headlineSmall: GoogleFonts.newsreader(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: darkOnSurface,
          height: 1.36,
        ),
        titleLarge: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: darkOnSurface,
          letterSpacing: -0.2,
        ),
        titleMedium: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: darkOnSurface,
          letterSpacing: -0.2,
        ),
        titleSmall: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: darkOnSurface,
        ),
        bodyLarge: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w400,
          color: darkOnSurface,
          height: 1.55,
        ),
        bodyMedium: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: darkOnSurface,
          height: 1.6,
        ),
        bodySmall: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: darkOnSurfaceVariant,
          height: 1.5,
        ),
        labelLarge: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: darkOnSurface,
        ),
        labelMedium: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: darkOnSurfaceVariant,
        ),
        labelSmall: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: darkOnSurfaceVariant,
        ),
      ),
      cardTheme: CardThemeData(
        color: darkSurfaceContainerLow,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: darkOutlineVariant, width: 1),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: darkBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.newsreader(
          color: darkOnSurface,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: darkOnSurface),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkPrimary,
          foregroundColor: darkOnPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
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
          textStyle: GoogleFonts.plusJakartaSans(
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
            return darkPrimary;
          }
          return darkSurfaceContainerHighest;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.transparent;
          }
          return darkOutline;
        }),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkSurface,
        selectedItemColor: darkPrimary,
        unselectedItemColor: darkOnSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: signalSuccess,
        contentTextStyle: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.fixed,
      ),
    );
  }
}
