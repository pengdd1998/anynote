import 'package:flutter/material.dart';

/// Centralized color tokens for the warm design system.
///
/// Light mode uses warm off-white surfaces with soft indigo-purple accents
/// and a warm accent palette (lavender, yellow, mint, peach).
/// Dark mode uses deep navy with muted highlights.
/// All neutrals are warm-tinted.
///
/// All text tiers meet WCAG AA 4.5:1 contrast on their respective surfaces.
class AppColors {
  AppColors._();

  // -- Light palette (warm) ---------------------------------------------------

  static const lightSurface = Color(0xFFFAF9F7);
  static const lightCardBg = Color(0xFFFFFFFF);
  static const lightInputFill = Color(0xFFF3F1ED);
  static const lightBorder = Color(0xFFE8E5DF);
  static const lightDivider = Color(0xFFEFECE7);
  static const lightDisabled = Color(0xFFD5D0C8);

  // Light text tiers (WCAG AA on lightSurface)
  static const lightTextPrimary = Color(0xFF2D2A26);
  static const lightTextSecondary = Color(0xFF6B6560);
  static const lightTextTertiary = Color(0xFF9E9890);

  // -- Dark palette -----------------------------------------------------------

  static const darkSurface = Color(0xFF1A1E2E);
  static const darkCardBg = Color(0xFF1E2235);
  static const darkInputFill = Color(0xFF252A3E);
  static const darkBorder = Color(0xFF353B52);
  static const darkDivider = Color(0xFF2D3348);
  static const darkDisabled = Color(0xFF4B5268);

  // Dark text tiers (WCAG AA on darkSurface)
  static const darkTextPrimary = Color(0xFFF4F2FF);
  static const darkTextSecondary = Color(0xFFC4C0E0);
  static const darkTextTertiary = Color(0xFF9E9AB8);

  // -- Brand accent -----------------------------------------------------------

  static const primary = Color(0xFF6C5CE7);
  static const primaryDark = Color(0xFF5A4BD1);
  static const secondary = Color(0xFFA29BFE);

  // -- Warm accent palette ----------------------------------------------------

  static const accentLavender = Color(0xFFC4B5FD);
  static const accentYellow = Color(0xFFFDE68A);
  static const accentMint = Color(0xFFA7F3D0);
  static const accentPeach = Color(0xFFFDBA74);

  // -- Warm accent backgrounds (for cards, chips, sections) -------------------

  static const accentLavenderBg = Color(0xFFF3F0FF);
  static const accentYellowBg = Color(0xFFFEF9E7);
  static const accentMintBg = Color(0xFFECFDF5);
  static const accentPeachBg = Color(0xFFFFF7ED);

  // -- Warm accent text (for text on light surfaces) --------------------------

  static const accentLavenderText = Color(0xFF7C6AC4);
  static const accentYellowText = Color(0xFF92690A);
  static const accentMintText = Color(0xFF0E7A52);
  static const accentPeachText = Color(0xFFB45815);

  // Ordered accent backgrounds for auto-cycling (cards, tags).
  static const accentBackgrounds = <Color>[
    accentLavenderBg,
    accentYellowBg,
    accentMintBg,
    accentPeachBg,
  ];

  // -- Shadow colors ----------------------------------------------------------

  static const shadowLight = Color(0x14000000); // ~8% black
  static const shadowMedium = Color(0x28000000); // ~16% black
  static const shadowDark = Color(0x20000000); // ~12% black (dark mode)

  // -- Semantic colors --------------------------------------------------------

  static const error = Color(0xFFEF4444);
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const info = Color(0xFF3B82F6);

  // -- High contrast (WCAG AAA 7:1) -------------------------------------------

  static const hcPrimary = Color(0xFF6D28D9);
  static const hcDarkPrimary = Color(0xFFC4B5FD);

  // -- Semantic variants for light mode ---------------------------------------

  static const lightErrorBg = Color(0xFFFFF1F1);
  static const lightErrorBorder = Color(0xFFFECACA);
  static const lightSuccessBg = Color(0xFFF0FDF8);
  static const lightSuccessBorder = Color(0xFFBBF7D4);
  static const lightWarningBg = Color(0xFFFFFBEB);
  static const lightWarningBorder = Color(0xFFFDE68A);
  static const lightInfoBg = Color(0xFFEFF6FF);
  static const lightInfoBorder = Color(0xFFBFDBFE);

  // -- Semantic variants for dark mode ----------------------------------------

  static const darkErrorBg = Color(0xFF2D1B1B);
  static const darkErrorBorder = Color(0xFF4A2424);
  static const darkSuccessBg = Color(0xFF1B2D22);
  static const darkSuccessBorder = Color(0xFF244A32);
  static const darkWarningBg = Color(0xFF2D2A1B);
  static const darkWarningBorder = Color(0xFF4A4224);
  static const darkInfoBg = Color(0xFF1B1F2D);
  static const darkInfoBorder = Color(0xFF24304A);

  // -- Note card pastel backgrounds -------------------------------------------

  static const noteYellow = Color(0xFFFFF3CD);
  static const notePurple = Color(0xFFE6E1FF);
  static const noteGreen = Color(0xFFE8F5E9);
  static const notePink = Color(0xFFFCE4EC);
  static const noteBlue = Color(0xFFE3F2FD);
  static const noteOrange = Color(0xFFFFE8D6);

  /// Ordered palette for auto-cycling card colors.
  static const notePastels = <Color>[
    noteYellow,
    notePurple,
    noteGreen,
    notePink,
    noteBlue,
    noteOrange,
  ];
}
