import 'package:flutter/material.dart';
import 'colors.dart';
import 'typography.dart';

/// MÏÏghO Design System v1.0 — Thèmes Officiels
class MiighoTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: MiighoColors.primary,
      scaffoldBackgroundColor: MiighoColors.canvas,
      colorScheme: const ColorScheme.dark(
        primary: MiighoColors.primary,
        secondary: MiighoColors.gold,
        surface: MiighoColors.surface2,
        error: MiighoColors.error,
        onPrimary: Colors.white,
        onSurface: MiighoColors.textPrimary,
      ),
      fontFamily: MiighoTypography.fontFamilyPrimary,
      textTheme: MiighoTypography.darkTextTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: MiighoColors.surface1,
        foregroundColor: MiighoColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: MiighoTypography.fontFamilyPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: MiighoColors.textPrimary,
        ),
      ),
      cardTheme: CardTheme(
        color: MiighoColors.surface2,
        elevation: 0,
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
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: MiighoColors.surface1,
        hintStyle: const TextStyle(color: MiighoColors.textMuted, fontSize: 14),
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
    );
  }

  static ThemeData get lightTheme {
    return darkTheme; // MÏÏghO adopte le Dark Mode Panafricain souverain par défaut
  }
}
