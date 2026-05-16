import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const Color background = Color(0xFFF3F1EC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceWarm = Color(0xFFFBFAF7);
  static const Color primary = Color(0xFF0E5E55);
  static const Color primaryDark = Color(0xFF143B37);
  static const Color accent = Color(0xFFC87E4F);
  static const Color danger = Color(0xFFB42318);
  static const Color ink = Color(0xFF18211F);
  static const Color muted = Color(0xFF68716E);
  static const Color line = Color(0xFFE4DED5);

  static ThemeData get themeData {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      surface: surface,
      error: danger,
    );

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      colorScheme: colorScheme,
      fontFamily: 'Avenir Next',
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          fontSize: 40,
          height: 1.02,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
          color: ink,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          height: 1.12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
          color: ink,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          height: 1.2,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          color: ink,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          height: 1.25,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          color: ink,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          height: 1.45,
          fontWeight: FontWeight.w500,
          letterSpacing: 0,
          color: ink,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          height: 1.45,
          fontWeight: FontWeight.w500,
          letterSpacing: 0,
          color: muted,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          height: 1.2,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: surfaceWarm,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceWarm,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        prefixIconColor: muted,
        labelStyle: const TextStyle(color: muted, fontWeight: FontWeight.w600),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          backgroundColor: primaryDark,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          side: const WidgetStatePropertyAll(BorderSide(color: line)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
