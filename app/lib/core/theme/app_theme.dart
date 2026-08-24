import 'package:flutter/material.dart';
import 'colors.dart';
import 'typography.dart';

/// MÏÏghO Design System v2.0 — Thèmes Officiels (Dark & Light)
class MiighoTheme {
  // === DARK THEME (Thème souverain par défaut de MÏÏghO) ===
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: MiighoColors.primary,
      scaffoldBackgroundColor: MiighoColors.canvas,
      canvasColor: MiighoColors.canvas,
      colorScheme: const ColorScheme.dark(
        primary: MiighoColors.primary,
        primaryContainer: MiighoColors.primaryDark,
        secondary: MiighoColors.gold,
        secondaryContainer: MiighoColors.goldAlpha,
        surface: MiighoColors.surface2,
        surfaceContainerHigh: MiighoColors.surface3,
        surfaceContainerHighest: MiighoColors.surfaceElevated,
        error: MiighoColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: MiighoColors.textPrimary,
        onError: Colors.white,
        outline: MiighoColors.borderMedium,
        outlineVariant: MiighoColors.borderSubtle,
      ),
      fontFamily: MiighoTypography.fontFamilyPrimary,
      textTheme: MiighoTypography.darkTextTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: MiighoColors.surface1,
        foregroundColor: MiighoColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: MiighoTypography.fontFamilyPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: MiighoColors.textPrimary,
        ),
        iconTheme: IconThemeData(color: MiighoColors.textPrimary),
      ),
      cardTheme: CardTheme(
        color: MiighoColors.surface2,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: MiighoColors.borderSubtle),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: MiighoColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          textStyle: const TextStyle(
            fontFamily: MiighoTypography.fontFamilyPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: MiighoColors.textPrimary,
          side: const BorderSide(color: MiighoColors.borderMedium),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          textStyle: const TextStyle(
            fontFamily: MiighoTypography.fontFamilyPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: MiighoColors.primaryLight,
          textStyle: const TextStyle(
            fontFamily: MiighoTypography.fontFamilyPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: MiighoColors.surface1,
        hintStyle: const TextStyle(color: MiighoColors.textMuted, fontSize: 14),
        labelStyle: const TextStyle(color: MiighoColors.textSecondary, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: MiighoColors.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: MiighoColors.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: MiighoColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: MiighoColors.error),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: MiighoColors.borderSubtle,
        thickness: 1,
        space: 1,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: MiighoColors.surface1,
        selectedItemColor: MiighoColors.primary,
        unselectedItemColor: MiighoColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: MiighoColors.surfaceElevated,
        contentTextStyle: const TextStyle(color: MiighoColors.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // === LIGHT THEME (Mode Clair complet) ===
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: MiighoColors.primary,
      scaffoldBackgroundColor: MiighoColors.lightCanvas,
      canvasColor: MiighoColors.lightCanvas,
      colorScheme: const ColorScheme.light(
        primary: MiighoColors.primary,
        primaryContainer: MiighoColors.primaryAlpha,
        secondary: MiighoColors.gold,
        secondaryContainer: MiighoColors.goldAlpha,
        surface: MiighoColors.lightSurface1,
        surfaceContainerHigh: MiighoColors.lightSurface2,
        surfaceContainerHighest: MiighoColors.lightSurface3,
        error: MiighoColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: MiighoColors.lightTextPrimary,
        onError: Colors.white,
        outline: MiighoColors.lightBorderMedium,
        outlineVariant: MiighoColors.lightBorderSubtle,
      ),
      fontFamily: MiighoTypography.fontFamilyPrimary,
      textTheme: MiighoTypography.lightTextTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: MiighoColors.lightSurface1,
        foregroundColor: MiighoColors.lightTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: MiighoTypography.fontFamilyPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: MiighoColors.lightTextPrimary,
        ),
        iconTheme: IconThemeData(color: MiighoColors.lightTextPrimary),
      ),
      cardTheme: CardTheme(
        color: MiighoColors.lightSurface1,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: MiighoColors.lightBorderSubtle),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: MiighoColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          textStyle: const TextStyle(
            fontFamily: MiighoTypography.fontFamilyPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: MiighoColors.lightTextPrimary,
          side: const BorderSide(color: MiighoColors.lightBorderMedium),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          textStyle: const TextStyle(
            fontFamily: MiighoTypography.fontFamilyPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: MiighoColors.primary,
          textStyle: const TextStyle(
            fontFamily: MiighoTypography.fontFamilyPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: MiighoColors.lightSurface2,
        hintStyle: const TextStyle(color: MiighoColors.lightTextMuted, fontSize: 14),
        labelStyle: const TextStyle(color: MiighoColors.lightTextSecondary, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: MiighoColors.lightBorderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: MiighoColors.lightBorderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: MiighoColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: MiighoColors.error),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: MiighoColors.lightBorderSubtle,
        thickness: 1,
        space: 1,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: MiighoColors.lightSurface1,
        selectedItemColor: MiighoColors.primary,
        unselectedItemColor: MiighoColors.lightTextMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: MiighoColors.lightSurface1,
        contentTextStyle: const TextStyle(color: MiighoColors.lightTextPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
