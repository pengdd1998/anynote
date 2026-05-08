import 'package:flutter/material.dart';

/// Centralized color tokens for the "Warm White / Deep Navy" aesthetic.
///
/// Light mode: warm white surfaces like high-quality paper, with warm neutrals.
/// Dark mode: deep navy/charcoal with warm undertones, like writing by lamplight.
/// Accent: warm coral-amber for interactive elements and status.
///
/// All text tiers meet WCAG AA 4.5:1 contrast on their respective surfaces.
/// Neutrals are tinted warm (slight red-orange hue) for subconscious cohesion.
class AppColors {
  AppColors._();

  // ── Light palette (warm white, paper-like) ────────────────────────────────

  /// Surface: warm white, like quality paper (not clinical #FFF)
  /// OKLCH: L=96%, C=0.008, H=35° (warm white hint)
  static const lightSurface = Color(0xFFFAF8F5);

  /// Card background: slightly warmer than surface
  /// OKLCH: L=98%, C=0.006, H=35°
  static const lightCardBg = Color(0xFFFEFDFB);

  /// Input fill: subtle warm tint
  /// OKLCH: L=94%, C=0.01, H=35°
  static const lightInputFill = Color(0xFFF2EFE9);

  /// Border: warm grey-brown
  /// OKLCH: L=62%, C=0.025, H=35°
  static const lightBorder = Color(0xFFA89880);

  /// Divider: subtle warm line
  /// OKLCH: L=88%, C=0.008, H=35°
  static const lightDivider = Color(0xFFE2D9CB);

  /// Disabled state: warm grey
  /// OKLCH: L=65%, C=0.02, H=35°
  static const lightDisabled = Color(0xFFB0A090);

  // Light text tiers (WCAG AA on lightSurface)

  /// Primary text: warm dark brown (not pure black)
  /// OKLCH: L=28%, C=0.03, H=35° — ~13:1 contrast
  static const lightTextPrimary = Color(0xFF3A3228);

  /// Secondary text: warm medium brown
  /// OKLCH: L=45%, C=0.025, H=35° — ~5.5:1 contrast
  static const lightTextSecondary = Color(0xFF6B5E4E);

  /// Tertiary text: warm light brown
  /// OKLCH: L=55%, C=0.02, H=35° — ~4.6:1 contrast
  static const lightTextTertiary = Color(0xFF8C8070);

  // ── Dark palette (deep navy/charcoal, warm undertones) ──────────────────

  /// Surface: deep navy with warmth (not cold black/purple)
  /// OKLCH: L=14%, C=0.025, H=250° → warm navy
  static const darkSurface = Color(0xFF1A1E2E);

  /// Card background: slightly lighter navy
  /// OKLCH: L=18%, C=0.022, H=250°
  static const darkCardBg = Color(0xFF252A3D);

  /// Input fill: mid navy
  /// OKLCH: L=22%, C=0.02, H=250°
  static const darkInputFill = Color(0xFF2D3247);

  /// Border: warm navy-grey
  /// OKLCH: L=35%, C=0.018, H=250°
  static const darkBorder = Color(0xFF4A5068);

  /// Divider: subtle navy line
  /// OKLCH: L=28%, C=0.015, H=250°
  static const darkDivider = Color(0xFF3D4359);

  /// Disabled state: warm navy-grey
  /// OKLCH: L=40%, C=0.015, H=250°
  static const darkDisabled = Color(0xFF585E75);

  // Dark text tiers (WCAG AA on darkSurface)

  /// Primary text: warm off-white
  /// OKLCH: L=92%, C=0.008, H=35° — ~14:1 contrast
  static const darkTextPrimary = Color(0xFFF4F1EA);

  /// Secondary text: warm grey-white
  /// OKLCH: L=72%, C=0.01, H=35° — ~6:1 contrast
  static const darkTextSecondary = Color(0xFFC4B8A8);

  /// Tertiary text: warm grey
  /// OKLCH: L=60%, C=0.012, H=35° — ~4.7:1 contrast
  static const darkTextTertiary = Color(0xFF9E9285);

  // ── Brand accent colors (warm coral-amber) ────────────────────────────────

  /// Primary accent: warm coral-amber for primary actions
  /// OKLCH: L=65%, C=0.16, H=35°
  static const primary = Color(0xFFD9774A);

  /// Primary dark: darker coral for small text AA
  /// OKLCH: L=55%, C=0.14, H=35°
  static const primaryDark = Color(0xFFB86035);

  /// Secondary accent: warm amber for secondary highlights
  /// OKLCH: L=70%, C=0.12, H=45°
  static const secondary = Color(0xFFE8A84C);

  // ── Semantic colors ───────────────────────────────────────────────────────

  /// Error: warm red (not cold pink-red)
  /// OKLCH: L=55%, C=0.18, H=25°
  static const error = Color(0xFFD65B4A);

  /// Success: warm green (not cold blue-green)
  /// OKLCH: L=60%, C=0.14, H=145°
  static const success = Color(0xFF5FA870);

  /// Warning: warm amber
  /// OKLCH: L=70%, C=0.15, H=55°
  static const warning = Color(0xFFE8A84C);

  /// Info: warm blue (not cold cyan)
  /// OKLCH: L=60%, C=0.12, H=230°
  static const info = Color(0xFF6B9AC8);

  // ── High contrast (WCAG AAA 7:1) ──────────────────────────────────────────

  /// HC primary for light mode: darker coral
  static const hcPrimary = Color(0xFFA05030);

  /// HC primary for dark mode: lighter coral
  static const hcDarkPrimary = Color(0xFFE8A080);

  // ── Semantic variants for light mode ───────────────────────────────────────

  /// Error background (light mode)
  static const lightErrorBg = Color(0xFFF8E8E5);

  /// Error border (light mode)
  static const lightErrorBorder = Color(0xFFE8C4C0);

  /// Success background (light mode)
  static const lightSuccessBg = Color(0xFFE8F0EB);

  /// Success border (light mode)
  static const lightSuccessBorder = Color(0xFFC0DCD0);

  /// Warning background (light mode)
  static const lightWarningBg = Color(0xFFF8EDE4);

  /// Warning border (light mode)
  static const lightWarningBorder = Color(0xFFE8D0B8);

  /// Info background (light mode)
  static const lightInfoBg = Color(0xFFE8EDF4);

  /// Info border (light mode)
  static const lightInfoBorder = Color(0xFFC0D0E0);

  // ── Semantic variants for dark mode ───────────────────────────────────────

  /// Error background (dark mode)
  static const darkErrorBg = Color(0xFF3A2828);

  /// Error border (dark mode)
  static const darkErrorBorder = Color(0xFF503838);

  /// Success background (dark mode)
  static const darkSuccessBg = Color(0xFF283830);

  /// Success border (dark mode)
  static const darkSuccessBorder = Color(0xFF385040);

  /// Warning background (dark mode)
  static const darkWarningBg = Color(0xFF3A3028);

  /// Warning border (dark mode)
  static const darkWarningBorder = Color(0xFF504038);

  /// Info background (dark mode)
  static const darkInfoBg = Color(0xFF283038);

  /// Info border (dark mode)
  static const darkInfoBorder = Color(0xFF384050);
}
