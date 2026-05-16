import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Imperial Scroll design system.
///
/// Inspired by ancient warrior armor — parchment background with deep
/// crimson cape accents, antique gold trim, and steel-navy structure.
/// Designed to be unique (not a copy of any reference) yet
/// give a refined, "study scroll" feeling.
class AppTheme {
  AppTheme._();

  // ── Brand palette ──────────────────────────────────────────────────
  /// Warm aged-paper background.
  static const Color parchment = Color(0xFFF4ECDA);

  /// Slightly lighter card surface.
  static const Color surface = Color(0xFFFBF6E9);

  /// Deep crimson — primary action (the cape).
  static const Color crimson = Color(0xFF9B2C2C);

  /// Crimson highlight (lighter shade for hover/pressed).
  static const Color crimsonLight = Color(0xFFB94545);

  /// Antique gold — accents, trim, dividers.
  static const Color gold = Color(0xFFC9A961);

  /// Soft gold for borders.
  static const Color goldSoft = Color(0xFFD9BE7C);

  /// Steel navy — armor; secondary buttons, headings.
  static const Color steel = Color(0xFF1E2A3A);

  /// Lighter steel for icon containers.
  static const Color steelLight = Color(0xFF34465E);

  // ── Semantic colors ────────────────────────────────────────────────
  static const Color ink = Color(0xFF1A1F2E);
  static const Color muted = Color(0xFF6B7280);
  static const Color success = Color(0xFF3F7D3F); // jade
  static const Color error = Color(0xFFB71C1C);
  static const Color white = Color(0xFFFFFFFF);

  // ── Legacy aliases (kept so existing screens compile during migration) ──
  static const Color background = parchment;
  static const Color primaryBlue = crimson; // primary action
  static const Color accentOchre = gold;
  static const Color textDark = ink;
  static const Color textMuted = muted;
  static const Color cardShadowDark = steel;
  static const Color cardShadowLight = surface;

  // ── Shadows: warm, subtle (no claymorphism) ────────────────────────
  static List<BoxShadow> softShadows({double intensity = 1.0}) => [
        BoxShadow(
          color: steel.withValues(alpha: 0.10 * intensity),
          offset: Offset(0, 4 * intensity),
          blurRadius: 12 * intensity,
        ),
      ];

  static List<BoxShadow> liftedShadows({double intensity = 1.0}) => [
        BoxShadow(
          color: steel.withValues(alpha: 0.16 * intensity),
          offset: Offset(0, 6 * intensity),
          blurRadius: 18 * intensity,
        ),
      ];

  static List<BoxShadow> innerSoftShadows() => [
        BoxShadow(
          color: steel.withValues(alpha: 0.06),
          offset: const Offset(0, 2),
          blurRadius: 4,
        ),
      ];

  // ── Radii ──────────────────────────────────────────────────────────
  static BorderRadius cardRadius = BorderRadius.circular(18);
  static BorderRadius buttonRadius = BorderRadius.circular(14);
  static BorderRadius inputRadius = BorderRadius.circular(12);
  static BorderRadius pillRadius = BorderRadius.circular(999);

  // ── Typography helpers ─────────────────────────────────────────────
  /// Display font — serif "manuscript" feel for titles & logo.
  static TextStyle display({
    double size = 32,
    FontWeight weight = FontWeight.w700,
    Color color = ink,
    double letterSpacing = 0.5,
  }) =>
      GoogleFonts.cormorantGaramond(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
      );

  /// Body font — clean modern sans.
  static TextStyle body({
    double size = 15,
    FontWeight weight = FontWeight.w500,
    Color color = ink,
  }) =>
      GoogleFonts.nunito(fontSize: size, fontWeight: weight, color: color);

  // ── Theme data ─────────────────────────────────────────────────────
  static ThemeData get themeData => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: parchment,
        colorScheme: const ColorScheme.light(
          primary: crimson,
          secondary: gold,
          surface: surface,
          onPrimary: white,
          onSecondary: ink,
          onSurface: ink,
          error: error,
        ),
        textTheme: GoogleFonts.nunitoTextTheme().apply(
          bodyColor: ink,
          displayColor: ink,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: parchment,
          surfaceTintColor: parchment,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: GoogleFonts.cormorantGaramond(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: ink,
            letterSpacing: 0.5,
          ),
          iconTheme: const IconThemeData(color: ink),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: buttonRadius),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: inputRadius,
            borderSide: BorderSide(color: goldSoft.withValues(alpha: 0.6)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: inputRadius,
            borderSide: BorderSide(color: goldSoft.withValues(alpha: 0.5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: inputRadius,
            borderSide: const BorderSide(color: crimson, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: inputRadius,
            borderSide: const BorderSide(color: error, width: 1.2),
          ),
          hintStyle: GoogleFonts.nunito(
            color: muted,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
}

