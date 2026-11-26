import 'package:flutter/material.dart';

/// Centralized color tokens for the warm design system.
///
/// Light mode uses warm cream surfaces with soft periwinkle-purple accents
/// and a warm accent palette (lavender, yellow, mint, peach).
/// Dark mode uses deep navy with muted highlights.
/// All neutrals are warm-tinted.
///
/// Every text tier meets WCAG AA (4.5:1) on the surfaces of its theme, and
/// so does the accent wherever it carries text — asserted, not promised, by
/// `test/core/theme/contrast_test.dart`. The status colours are the one
/// exception: [success], [warning] and [error] are fills, and anything that
/// has to be read takes the `status…Ink` pair instead (see below).
class AppColors {
  AppColors._();

  // -- Light palette (warm cream) ---------------------------------------------

  static const lightSurface = Color(0xFFFAF8F5); // warm cream
  static const lightCardBg = Color(0xFFFFFDF9); // faint warm tint
  static const lightInputFill = Color(0xFFF5F2EE); // warm input fill
  static const lightBorder = Color(0xFFE8E4DF); // warm border
  static const lightDivider = Color(0xFFEBE8E3);
  static const lightDisabled = Color(0xFFD5D0C8);

  // Light text tiers (WCAG AA on lightSurface) — warm slate
  static const lightTextPrimary = Color(0xFF0F172A); // slate-900
  static const lightTextSecondary = Color(0xFF5C534A); // warm brown-gray
  static const lightTextTertiary =
      Color(0xFF7B6A59); // warm muted, AA on input fills too

  // -- Dark palette -----------------------------------------------------------

  static const darkSurface = Color(0xFF1A1E2E);
  static const darkCardBg = Color(0xFF1E2235);
  static const darkInputFill = Color(0xFF252A3E);
  static const darkBorder = Color(0xFF353B52);
  static const darkDivider = Color(0xFF2D3348);
  static const darkDisabled = Color(0xFF4B5268);

  // Dark text tiers (WCAG AA on darkSurface)
  static const darkTextPrimary = Color(0xFFF4F2FF);
  static const darkTextSecondary =
      Color(0xFFCAC5DA); // AA on the dark note washes too
  static const darkTextTertiary = Color(0xFF9E9AB8);

  // -- Brand accent (periwinkle purple — matching design mockup) -------------

  /// Deep enough to carry white (5.3:1) and to be read as text on every light
  /// surface, the desk behind the notes included (4.66:1 and up). The
  /// mockup's softer periwinkle (#8B7CE8) did neither, and one step bluer
  /// (#6B5CD0) met the desk by five ten-thousandths and no more.
  static const primary = Color(0xFF6C5BC4);
  static const primaryDark = Color(0xFF5B4AC0); // pressed / deeper purple
  static const secondary = Color(0xFFB7ADF5); // light periwinkle

  /// Soft lavender tint used for selected chips, subtle fills, highlights.
  static const primarySoft = Color(0xFFEFECFE);
  static const primarySoftBorder = Color(0xFFDCD5FA);

  /// Disabled-state accent (light washed purple, e.g. inactive CTA buttons).
  static const primaryDisabled = Color(0xFFCFC8F7);

  /// The accent as text — link text, body accents. The same value as
  /// [primary] on purpose: there is one purple. `contrast_test.dart` holds
  /// the two together.
  static const primaryText = Color(0xFF6C5BC4);

  // -- Warm accent palette ----------------------------------------------------

  static const accentLavender = Color(0xFFC4B5FD);
  static const accentYellow = Color(0xFFFDE68A);
  static const accentMint = Color(0xFFA7F3D0);
  static const accentPeach = Color(0xFFFDBA74);
  static const accentCoral = Color(0xFFF4A28C);

  // -- Warm accent backgrounds (for cards, chips, sections) -------------------

  static const accentLavenderBg = Color(0xFFF3F0FF);
  static const accentYellowBg = Color(0xFFFEF9E7);
  static const accentMintBg = Color(0xFFECFDF5);
  static const accentPeachBg = Color(0xFFFFF7ED);
  static const accentCoralBg = Color(0xFFFFF0EB);

  // -- Slate palette (Tailwind) -----------------------------------------------

  static const slate50 = Color(0xFFF8FAFC);
  static const slate100 = Color(0xFFF1F5F9);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate300 = Color(0xFFCBD5E1);
  static const slate400 = Color(0xFF94A3B8);
  static const slate500 = Color(0xFF64748B);
  static const slate600 = Color(0xFF475569);
  static const slate700 = Color(0xFF334155);
  static const slate900 = Color(0xFF0F172A);

  // -- Indigo accent tones (Tailwind) -----------------------------------------

  static const indigo50 = Color(0xFFEEF2FF);
  static const indigo100 = Color(0xFFE0E7FF);

  // -- Warm accent text (for text on light surfaces) --------------------------

  static const accentLavenderText = Color(0xFF7C6AC4);
  static const accentYellowText = Color(0xFF92690A);
  static const accentMintText = Color(0xFF0E7A52);
  static const accentPeachText = Color(0xFFB45815);
  static const accentCoralText = Color(0xFFB85A3A);

  // Ordered accent backgrounds for auto-cycling (cards, tags).
  // Warm-first: peach, yellow, coral, mint.
  static const accentBackgrounds = <Color>[
    accentPeachBg,
    accentYellowBg,
    accentCoralBg,
    accentMintBg,
  ];

  // -- Shadow colors (warm-tinted) -------------------------------------------

  static const shadowLight = Color(0x1A1008); // warm ~10%
  static const shadowMedium = Color(0x2A2018); // warm ~16%
  static const shadowDark = Color(0x20000000); // ~12% black (dark mode)

  // -- Semantic colors --------------------------------------------------------

  static const error = Color(0xFFEF4444);
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const info = Color(0xFF3B82F6);

  // -- Status ink -------------------------------------------------------------

  /// Ink for status *text and icons* — saved, not synced, a conflict — which
  /// has to be read: at least 4.6:1 on every surface of its theme.
  ///
  /// [success], [warning] and [error] are one value for both themes and cannot
  /// meet that: no colour is 4.5:1 against cream paper and against deep navy
  /// at once. They stay as fills; anything meant to be read takes these.
  static const statusSuccessInk = Color(0xFF2D7860);
  static const statusWarningInk = Color(0xFF896529);
  static const statusErrorInk = Color(0xFFC23838);
  static const statusSuccessInkDark = Color(0xFF3EA482);
  static const statusWarningInkDark = Color(0xFFBC8B37);
  static const statusErrorInkDark = Color(0xFFDD7575);

  static Color statusSuccessOf(Brightness brightness) =>
      brightness == Brightness.dark ? statusSuccessInkDark : statusSuccessInk;
  static Color statusWarningOf(Brightness brightness) =>
      brightness == Brightness.dark ? statusWarningInkDark : statusWarningInk;
  static Color statusErrorOf(Brightness brightness) =>
      brightness == Brightness.dark ? statusErrorInkDark : statusErrorInk;

  // -- High contrast (WCAG AAA 7:1) -------------------------------------------

  static const hcPrimary = Color(0xFF4F3DB8); // deep violet
  static const hcDarkPrimary = Color(0xFFC9C0FF); // pale periwinkle

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

  static const noteYellow = Color(0xFFFFFBEB); // warm cream
  static const notePeach = Color(0xFFFFF5F0); // warm peach
  static const noteGreen = Color(0xFFF0FDF4); // subtle mint
  static const notePink = Color(0xFFFFF1F2); // subtle rose
  static const noteBlue = Color(0xFFF0F7FF); // subtle sky
  static const noteOrange = Color(0xFFFFF7ED); // subtle peach

  /// Ordered palette for auto-cycling card colors. Warm-first.
  static const notePastels = <Color>[
    noteYellow,
    noteOrange,
    notePink,
    noteGreen,
    noteBlue,
    notePeach,
  ];

  // -- Sticky-note PAPER palette (skeuomorphic mockup style) -------------------
  // Saturated candy pastels sampled from the 2026-05 mockup: grid cards read
  // as real paper sticky notes (color block + soft shadow, no border).

  static const paperYellow = Color(0xFFFBE48E); // Morning thoughts yellow
  static const paperWhite = Color(0xFFF9F4EA); // plain paper (Book recs)
  static const paperPink = Color(0xFFFDD0CB); // salmon pink (That's a wrap)
  static const paperLavender = Color(0xFFE4D3F6); // Quote to remember
  static const paperCream = Color(0xFFFCF7EA); // Tiny ideas cream
  static const paperGreen = Color(0xFFE2EFD0); // Plant care mint

  /// Ordered paper cycle for auto-cycling card colors. Mirrors the mockup's
  /// rhythm: strong yellow, plain paper, pink, lavender, cream, green.
  static const notePapers = <Color>[
    paperYellow,
    paperWhite,
    paperPink,
    paperLavender,
    paperCream,
    paperGreen,
  ];

  /// Muted ink for each of the [notePapers], in the same order — in the light
  /// theme: the sheet's own hue, darkened until a timestamp reads on it (5:1
  /// and up). One warm grey for all six was 2.2–2.9:1. A dark-theme sheet is
  /// a wash and takes [darkTextSecondary], whichever paper it was made from.
  static const paperInks = <Color>[
    Color(0xFF665F47), // on Morning thoughts yellow
    Color(0xFF736750), // on plain paper
    Color(0xFF70514E), // on salmon pink
    Color(0xFF625175), // on Lavender note
    Color(0xFF746A51), // on Tiny ideas cream
    Color(0xFF5A6748), // on Plant care mint
  ];

  /// Warm shadow ink for paper cards (light mode): soft brown-gray, like a
  /// note resting slightly above the desk.
  static const paperShadow = Color(0x26786442); // ~15% warm brown
  static const paperShadowNear = Color(0x1F786442); // ~12% tighter layer

  /// Slightly deeper page background so paper cards pop (notes home screen).
  static const lightDeskBg = Color(0xFFF2EFE9);

  // -- Note card border colors (soft, warm-tinted) ---------------------------

  static const noteBorderYellow = Color(0xFFFEECC0);
  static const noteBorderPink = Color(0xFFFECDD3);
  static const noteBorderGreen = Color(0xFFBBF7D0);
  static const noteBorderPeach = Color(0xFFFED7AA);
  static const noteBorderBlue = Color(0xFFBFDBFE);
  static const noteBorderOrange = Color(0xFFFED7AA);

  static const noteBorderColors = <Color>[
    noteBorderYellow,
    noteBorderOrange,
    noteBorderPink,
    noteBorderGreen,
    noteBorderBlue,
    noteBorderPeach,
  ];
}
