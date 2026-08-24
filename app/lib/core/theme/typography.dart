import 'package:flutter/material.dart';
import 'colors.dart';

/// MÏÏghO Design System v2.0 — Typographie Officielle
class MiighoTypography {
  static const String fontFamilyPrimary = 'Plus Jakarta Sans';
  static const String fontFamilyDisplay = 'Outfit';
  static const String fontFamilyNumeric = 'Space Grotesk';

  // === Dark Text Theme ===
  static const TextTheme darkTextTheme = TextTheme(
    displayLarge: TextStyle(
      fontFamily: fontFamilyDisplay,
      fontSize: 36,
      fontWeight: FontWeight.w800,
      color: MiighoColors.textPrimary,
      letterSpacing: -0.5,
    ),
    displayMedium: TextStyle(
      fontFamily: fontFamilyDisplay,
      fontSize: 28,
      fontWeight: FontWeight.w700,
      color: MiighoColors.textPrimary,
      letterSpacing: -0.3,
    ),
    displaySmall: TextStyle(
      fontFamily: fontFamilyDisplay,
      fontSize: 24,
      fontWeight: FontWeight.w700,
      color: MiighoColors.textPrimary,
    ),
    headlineLarge: TextStyle(
      fontFamily: fontFamilyPrimary,
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: MiighoColors.textPrimary,
    ),
    headlineMedium: TextStyle(
      fontFamily: fontFamilyPrimary,
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: MiighoColors.textPrimary,
    ),
    headlineSmall: TextStyle(
      fontFamily: fontFamilyPrimary,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: MiighoColors.textPrimary,
    ),
    titleLarge: TextStyle(
      fontFamily: fontFamilyPrimary,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: MiighoColors.textPrimary,
    ),
    titleMedium: TextStyle(
      fontFamily: fontFamilyPrimary,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: MiighoColors.textPrimary,
    ),
    titleSmall: TextStyle(
      fontFamily: fontFamilyPrimary,
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: MiighoColors.textSecondary,
    ),
    bodyLarge: TextStyle(
      fontFamily: fontFamilyPrimary,
      fontSize: 15,
      fontWeight: FontWeight.w400,
      color: MiighoColors.textPrimary,
      height: 1.5,
    ),
    bodyMedium: TextStyle(
      fontFamily: fontFamilyPrimary,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: MiighoColors.textPrimary,
      height: 1.45,
    ),
    bodySmall: TextStyle(
      fontFamily: fontFamilyPrimary,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: MiighoColors.textSecondary,
    ),
    labelLarge: TextStyle(
      fontFamily: fontFamilyPrimary,
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: MiighoColors.textPrimary,
    ),
    labelMedium: TextStyle(
      fontFamily: fontFamilyPrimary,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: MiighoColors.textSecondary,
    ),
    labelSmall: TextStyle(
      fontFamily: fontFamilyPrimary,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: MiighoColors.textMuted,
      letterSpacing: 0.6,
    ),
  );

  // === Light Text Theme ===
  static const TextTheme lightTextTheme = TextTheme(
    displayLarge: TextStyle(
      fontFamily: fontFamilyDisplay,
      fontSize: 36,
      fontWeight: FontWeight.w800,
      color: MiighoColors.lightTextPrimary,
      letterSpacing: -0.5,
    ),
    displayMedium: TextStyle(
      fontFamily: fontFamilyDisplay,
      fontSize: 28,
      fontWeight: FontWeight.w700,
      color: MiighoColors.lightTextPrimary,
      letterSpacing: -0.3,
    ),
    displaySmall: TextStyle(
      fontFamily: fontFamilyDisplay,
      fontSize: 24,
      fontWeight: FontWeight.w700,
      color: MiighoColors.lightTextPrimary,
    ),
    headlineLarge: TextStyle(
      fontFamily: fontFamilyPrimary,
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: MiighoColors.lightTextPrimary,
    ),
    headlineMedium: TextStyle(
      fontFamily: fontFamilyPrimary,
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: MiighoColors.lightTextPrimary,
    ),
    headlineSmall: TextStyle(
      fontFamily: fontFamilyPrimary,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: MiighoColors.lightTextPrimary,
    ),
    titleLarge: TextStyle(
      fontFamily: fontFamilyPrimary,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: MiighoColors.lightTextPrimary,
    ),
    titleMedium: TextStyle(
      fontFamily: fontFamilyPrimary,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: MiighoColors.lightTextPrimary,
    ),
    titleSmall: TextStyle(
      fontFamily: fontFamilyPrimary,
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: MiighoColors.lightTextSecondary,
    ),
    bodyLarge: TextStyle(
      fontFamily: fontFamilyPrimary,
      fontSize: 15,
      fontWeight: FontWeight.w400,
      color: MiighoColors.lightTextPrimary,
      height: 1.5,
    ),
    bodyMedium: TextStyle(
      fontFamily: fontFamilyPrimary,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: MiighoColors.lightTextPrimary,
      height: 1.45,
    ),
    bodySmall: TextStyle(
      fontFamily: fontFamilyPrimary,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: MiighoColors.lightTextSecondary,
    ),
    labelLarge: TextStyle(
      fontFamily: fontFamilyPrimary,
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: MiighoColors.lightTextPrimary,
    ),
    labelMedium: TextStyle(
      fontFamily: fontFamilyPrimary,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: MiighoColors.lightTextSecondary,
    ),
    labelSmall: TextStyle(
      fontFamily: fontFamilyPrimary,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: MiighoColors.lightTextMuted,
      letterSpacing: 0.6,
    ),
  );

  static const TextStyle financialAmount = TextStyle(
    fontFamily: fontFamilyNumeric,
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: MiighoColors.gold,
    letterSpacing: -0.5,
  );
}
