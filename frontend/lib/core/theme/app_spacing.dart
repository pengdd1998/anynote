/// Consistent spacing and sizing constants for the warm design system.
///
/// Use these constants instead of hard-coded numeric literals so that paddings,
/// gaps, and component sizes stay uniform across the entire app.
///
/// ```dart
/// Padding(padding: const EdgeInsets.all(AppSpacing.md), child: ...)
/// SizedBox(height: AppSpacing.s12)
/// ```
///
/// The scale follows a 4 px base grid with intermediate steps.
library;

import 'package:flutter/material.dart';

class AppSpacing {
  AppSpacing._();

  // ---------------------------------------------------------------------------
  // Numeric spacing scale (4 px base grid)
  // ---------------------------------------------------------------------------

  static const double s2 = 2;
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s40 = 40;
  static const double s48 = 48;

  // ---------------------------------------------------------------------------
  // Semantic aliases (short names)
  // ---------------------------------------------------------------------------

  static const double xs = s4;
  static const double sm = s8;
  static const double md = s16;
  static const double lg = s24;
  static const double xl = s32;

  // ---------------------------------------------------------------------------
  // Component dimensions
  // ---------------------------------------------------------------------------

  static const double buttonHeight = 48;
  static const double iconCircleSize = 32;

  // ---------------------------------------------------------------------------
  // Content padding presets
  // ---------------------------------------------------------------------------

  static const double screenPadding = 16;
  static const double sectionGap = 24;
  static const double itemGap = 8;

  // ---------------------------------------------------------------------------
  // Touch target
  // ---------------------------------------------------------------------------

  static const double minTouchTarget = 44;

  // ---------------------------------------------------------------------------
  // Convenience EdgeInsets
  // ---------------------------------------------------------------------------

  static const EdgeInsets paddingH16V6 = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 6,
  );

  static const EdgeInsets paddingAll16 = EdgeInsets.all(16);
  static const EdgeInsets paddingH32 = EdgeInsets.symmetric(horizontal: 32);
  static const EdgeInsets paddingH16 = EdgeInsets.symmetric(horizontal: 16);
  static const EdgeInsets paddingH16V12 = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 12,
  );

  /// Standard screen horizontal padding (16px).
  static const EdgeInsets screenH = EdgeInsets.symmetric(horizontal: screenPadding);

  /// Screen with top section gap.
  static const EdgeInsets screenWithGap = EdgeInsets.fromLTRB(
    screenPadding, sectionGap, screenPadding, 0,
  );

  /// Card inner padding.
  static const EdgeInsets cardInner = EdgeInsets.all(16);

  /// List item horizontal padding.
  static const EdgeInsets listItemH = EdgeInsets.symmetric(horizontal: 16);
}
