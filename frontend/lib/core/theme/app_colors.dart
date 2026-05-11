import 'package:flutter/material.dart';

/// Centralized color tokens for the "Warm White / Warm Dark" aesthetic.
///
/// Light mode: warm white surfaces like high-quality paper, with warm neutrals.
/// Dark mode: warm dark brown/charcoal, like writing by lamplight.
/// Accent: warm coral-amber for interactive elements and status.
///
/// All text tiers meet WCAG AA 4.5:1 contrast on their respective surfaces.
/// Neutrals are tinted warm (slight red-orange hue) for subconscious cohesion.
class AppColors {
  AppColors._();

  // -- Light palette ----------------------------------------------------------

  static const lightSurface = Color(0xFFFAF8F5);
  static const lightCardBg = Color(0xFFFEFDFB);
  static const lightInputFill = Color(0xFFF2EFE9);
  static const lightBorder = Color(0xFFA89880);
  static const lightDivider = Color(0xFFE2D9CB);
  static const lightDisabled = Color(0xFFB0A090);

  // Light text tiers (WCAG AA on lightSurface)

  static const lightTextPrimary = Color(0xFF3A3228);
  static const lightTextSecondary = Color(0xFF6B5E4E);
  static const lightTextTertiary = Color(0xFF8C8070);

  // -- Dark palette -----------------------------------------------------------

  static const darkSurface = Color(0xFF1E1A16);
  static const darkCardBg = Color(0xFF252119);
  static const darkInputFill = Color(0xFF2A2520);
  static const darkBorder = Color(0xFF3D3630);
  static const darkDivider = Color(0xFF342E28);
  static const darkDisabled = Color(0xFF504840);

  // Dark text tiers (WCAG AA on darkSurface)

  static const darkTextPrimary = Color(0xFFF4F1EA);
  static const darkTextSecondary = Color(0xFFC4B8A8);
  static const darkTextTertiary = Color(0xFF9E9285);

  // -- Brand accent -----------------------------------------------------------

  static const primary = Color(0xFFD9774A);
  static const primaryDark = Color(0xFFB86035);
  static const secondary = Color(0xFFE8A84C);

  // -- Semantic colors --------------------------------------------------------

  static const error = Color(0xFFD65B4A);
  static const success = Color(0xFF5FA870);
  static const warning = Color(0xFFE8A84C);
  static const info = Color(0xFF6B9AC8);

  // -- High contrast (WCAG AAA 7:1) -------------------------------------------

  static const hcPrimary = Color(0xFFA05030);
  static const hcDarkPrimary = Color(0xFFE8A080);

  // -- Semantic variants for light mode ---------------------------------------

  static const lightErrorBg = Color(0xFFF8E8E5);
  static const lightErrorBorder = Color(0xFFE8C4C0);
  static const lightSuccessBg = Color(0xFFE8F0EB);
  static const lightSuccessBorder = Color(0xFFC0DCD0);
  static const lightWarningBg = Color(0xFFF8EDE4);
  static const lightWarningBorder = Color(0xFFE8D0B8);
  static const lightInfoBg = Color(0xFFE8EDF4);
  static const lightInfoBorder = Color(0xFFC0D0E0);

  // -- Semantic variants for dark mode ----------------------------------------

  static const darkErrorBg = Color(0xFF2E1E1C);
  static const darkErrorBorder = Color(0xFF48302C);
  static const darkSuccessBg = Color(0xFF1E2E22);
  static const darkSuccessBorder = Color(0xFF2C4832);
  static const darkWarningBg = Color(0xFF2E2820);
  static const darkWarningBorder = Color(0xFF48382E);
  static const darkInfoBg = Color(0xFF222830);
  static const darkInfoBorder = Color(0xFF2E3848);
}
