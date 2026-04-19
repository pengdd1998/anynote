/// Consistent spacing and sizing constants for the AnyNote design system.
///
/// Use these constants instead of hard-coded numeric literals so that paddings,
/// gaps, border radii, and component sizes stay uniform across the entire app.
///
/// ```dart
/// Padding(padding: const EdgeInsets.all(AppSpacing.md), child: ...)
/// ```
///
/// See also:
/// - [AppTheme] for color, typography, and component shape tokens.
library;

import 'package:flutter/material.dart';

class AppSpacing {
  AppSpacing._();

  // ---------------------------------------------------------------------------
  // Inline / gap spacing
  // ---------------------------------------------------------------------------
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  // ---------------------------------------------------------------------------
  // Component dimensions
  // ---------------------------------------------------------------------------
  static const double cardRadius = 12;
  static const double buttonHeight = 48;

  // ---------------------------------------------------------------------------
  // Content padding presets
  // ---------------------------------------------------------------------------
  static const double screenPadding = 16;
  static const double sectionGap = 24;
  static const double itemGap = 8;

  // ---------------------------------------------------------------------------
  // Convenience EdgeInsets
  // ---------------------------------------------------------------------------
  static const EdgeInsets paddingH16V6 = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 6,
  );

  static const EdgeInsets paddingAll16 = EdgeInsets.all(16);
  static const EdgeInsets paddingH32 = EdgeInsets.symmetric(horizontal: 32);
}
