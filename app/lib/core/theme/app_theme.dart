import 'package:flutter/material.dart';
import 'colors.dart';
import 'typography.dart';

class MiighoTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: MiighoColors.primary,
      scaffoldBackgroundColor: MiighoColors.backgroundLight,
      colorScheme: const ColorScheme.light(
        primary: MiighoColors.primary,
        secondary: MiighoColors.secondary,
        surface: MiighoColors.surfaceLight,
        error: MiighoColors.error,
      ),
      textTheme: MiighoTypography.textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: MiighoColors.primary,
        foregroundColor: MiighoColors.backgroundLight,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: MiighoColors.primary,
          foregroundColor: MiighoColors.backgroundLight,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: MiighoColors.surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: MiighoColors.primary),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: MiighoColors.primary,
      scaffoldBackgroundColor: MiighoColors.backgroundDark,
      colorScheme: const ColorScheme.dark(
        primary: MiighoColors.primaryLight,
        secondary: MiighoColors.secondary,
        surface: MiighoColors.surfaceDark,
        error: MiighoColors.error,
      ),
      textTheme: MiighoTypography.textTheme.apply(
        bodyColor: MiighoColors.textDark,
        displayColor: MiighoColors.textDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: MiighoColors.surfaceDark,
        foregroundColor: MiighoColors.textDark,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: MiighoColors.primaryLight,
          foregroundColor: MiighoColors.backgroundDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: MiighoColors.surfaceDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: MiighoColors.primaryLight),
        ),
      ),
    );
  }
}
