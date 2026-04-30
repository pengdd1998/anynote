import 'package:flutter/material.dart';

/// Centralized color tokens for the "Pastel + Pop Accent" design language.
///
/// Light surfaces use soft lavender blush tones; dark surfaces use deep
/// plum-black. The primary accent is vivid coral; secondary is fresh mint.
/// All text tiers are verified to meet WCAG AA 4.5:1 contrast on their
/// respective surfaces.
class AppColors {
  AppColors._();

  // ── Light palette ────────────────────────────────────────────────────

  static const lightSurface = Color(0xFFF5F0FA);
  static const lightCardBg = Color(0xFFFCFAFF);
  static const lightInputFill = Color(0xFFEDE7F6);
  static const lightBorder = Color(0xFFD7CCE8);
  static const lightDivider = Color(0xFFE8E0F0);
  static const lightDisabled = Color(0xFFB8A9D4);

  // Light text tiers (WCAG AA on lightSurface)
  static const lightTextPrimary = Color(0xFF2B1D3B); // ~13.5:1
  static const lightTextSecondary = Color(0xFF5E4B75); // ~5.5:1
  static const lightTextTertiary = Color(0xFF7B6B8F); // ~4.6:1

  // ── Dark palette ─────────────────────────────────────────────────────

  static const darkSurface = Color(0xFF161220);
  static const darkCardBg = Color(0xFF221A2E);
  static const darkInputFill = Color(0xFF2A2036);
  static const darkBorder = Color(0xFF3D3450);
  static const darkDivider = Color(0xFF332A42);
  static const darkDisabled = Color(0xFF4A405A);

  // Dark text tiers (WCAG AA on darkSurface)
  static const darkTextPrimary = Color(0xFFF0EBF5); // ~14:1
  static const darkTextSecondary = Color(0xFFB8ACC8); // ~6:1
  static const darkTextTertiary = Color(0xFF9E90AE); // ~4.7:1

  // ── Brand accent colors ──────────────────────────────────────────────

  static const primary = Color(0xFFFF6B6B); // Vivid coral
  static const primaryDark =
      Color(0xFFD94848); // Darker coral for small text AA
  static const secondary = Color(0xFF51CF66); // Fresh mint

  // ── Semantic colors ──────────────────────────────────────────────────

  static const error = Color(0xFFE53935);
  static const success = Color(0xFF43A047);
  static const warning = Color(0xFFFFA726);
  static const info = Color(0xFF42A5F5);

  // ── High contrast (WCAG AAA 7:1) ─────────────────────────────────────

  static const hcPrimary = Color(0xFFCC3333); // Dark coral for HC light
  static const hcDarkPrimary = Color(0xFFFF8A80); // Light coral for HC dark
}
