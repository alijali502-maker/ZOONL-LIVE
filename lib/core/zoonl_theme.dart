import 'package:flutter/material.dart';

/// Shared visual system for every authenticated and unauthenticated screen.
class ZoonlTheme {
  ZoonlTheme._();

  static const Color background = Color(0xFF070B17);
  static const Color backgroundRaised = Color(0xFF0D1426);
  static const Color surface = Color(0xFF141E35);
  static const Color surfaceRaised = Color(0xFF1B2844);
  static const Color border = Color(0xFF2C3B59);
  static const Color champagne = Color(0xFF9B8CFF);
  static const Color champagneLight = Color(0xFFD2CEFF);
  static const Color teal = Color(0xFF58D6CE);
  static const Color textPrimary = Color(0xFFF4F6FF);
  static const Color textSecondary = Color(0xFFA9B4CA);
  static const Color danger = Color(0xFFFF788E);

  static ThemeData get dark {
    final ColorScheme scheme = const ColorScheme.dark(
      primary: champagne,
      onPrimary: Color(0xFF17130A),
      secondary: teal,
      onSecondary: Color(0xFF071713),
      surface: surface,
      onSurface: textPrimary,
      error: danger,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      dividerColor: border,
      primaryColor: champagne,
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: .2,
        ),
        iconTheme: IconThemeData(color: champagne),
      ),
      textTheme: ThemeData.dark().textTheme.apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ).copyWith(
        titleLarge: const TextStyle(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: const TextStyle(
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: const TextStyle(
          color: textSecondary,
          height: 1.45,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: backgroundRaised,
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: textSecondary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: champagne, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: champagne,
          foregroundColor: const Color(0xFF17130A),
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: .25,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: champagneLight,
          minimumSize: const Size(48, 48),
          side: const BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: surfaceRaised,
        contentTextStyle: TextStyle(color: textPrimary),
        behavior: SnackBarBehavior.floating,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: backgroundRaised,
        selectedItemColor: champagne,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
