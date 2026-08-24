import 'package:flutter/material.dart';

/// MÏÏghO Design System v2.0 — Tokens de Couleurs Officiels
class MiighoColors {
  // === Fondations & Surfaces Minérales (Dark Mode Principal) ===
  static const Color canvas = Color(0xFF080C14);
  static const Color surface1 = Color(0xFF0E1422);
  static const Color surface2 = Color(0xFF141D30);
  static const Color surface3 = Color(0xFF1B263E);
  static const Color surfaceElevated = Color(0xFF22304E);

  // === Mode Clair (Light Mode) ===
  static const Color lightCanvas = Color(0xFFF8FAFC);
  static const Color lightSurface1 = Color(0xFFFFFFFF);
  static const Color lightSurface2 = Color(0xFFF1F5F9);
  static const Color lightSurface3 = Color(0xFFE2E8F0);
  static const Color lightSurfaceElevated = Color(0xFFFFFFFF);

  // === Rétrocompatibilité Thème ===
  static const Color backgroundDark = canvas;
  static const Color backgroundLight = lightCanvas;
  static const Color surfaceDark = surface2;
  static const Color surfaceLight = lightSurface1;

  // === Couleur Signature MÏÏghO (Pourpre Royal Panafricain) ===
  static const Color primary = Color(0xFF7C3AED);
  static const Color primaryLight = Color(0xFF9333EA);
  static const Color primaryDark = Color(0xFF6D28D9);
  static const Color primaryAlpha = Color(0x1F7C3AED); // ~12% opacity
  static const Color primaryGlow = Color(0x597C3AED); // ~35% opacity

  // === Accent Valeur & Finance (Or Sahélien) ===
  static const Color gold = Color(0xFFF59E0B);
  static const Color goldLight = Color(0xFFFBBF24);
  static const Color goldDark = Color(0xFFD97706);
  static const Color goldAlpha = Color(0x1FF59E0B);
  static const Color secondary = gold;

  // === Typographie & Textes (Dark Mode) ===
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textDisabled = Color(0xFF475569);

  // === Typographie & Textes (Light Mode) ===
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextMuted = Color(0xFF64748B);
  static const Color lightTextDisabled = Color(0xFF94A3B8);

  // Rétrocompatibilité text
  static const Color textLight = lightTextPrimary;
  static const Color textDark = textPrimary;

  // === Bordures & Séparateurs (Dark) ===
  static const Color borderSubtle = Color(0x0FFFFFFF); // 6% white
  static const Color borderMedium = Color(0x1FFFFFFF); // 12% white
  static const Color borderStrong = Color(0x33FFFFFF); // 20% white
  static const Color borderFocus = primary;

  // === Bordures & Séparateurs (Light) ===
  static const Color lightBorderSubtle = Color(0xFFE2E8F0);
  static const Color lightBorderMedium = Color(0xFFCBD5E1);
  static const Color lightBorderStrong = Color(0xFF94A3B8);

  // === Sémantique & Statuts Système ===
  static const Color success = Color(0xFF10B981);
  static const Color successAlpha = Color(0x1F10B981);
  static const Color warning = Color(0xFFF97316);
  static const Color warningAlpha = Color(0x1FF97316);
  static const Color error = Color(0xFFEF4444);
  static const Color errorAlpha = Color(0x1FEF4444);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoAlpha = Color(0x1F3B82F6);

  // === Statuts Écosystème MÏÏghO ===
  static const Color statusActive = Color(0xFF10B981); // Vert
  static const Color statusBeta = Color(0xFF3B82F6); // Bleu
  static const Color statusPrototype = Color(0xFFF59E0B); // Ambre / Or
  static const Color statusDevelopment = Color(0xFF8B5CF6); // Violet
  static const Color statusComingSoon = Color(0xFF64748B); // Gris ardoise
}
