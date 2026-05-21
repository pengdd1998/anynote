import 'package:flutter/material.dart';

/// Border-radius tokens for the warm design system.
///
/// Generous, rounded corners are a core element of the design language.
/// All components use radii from this scale.
///
/// ```dart
/// Container(
///   decoration: BoxDecoration(
///     borderRadius: AppRadius.mdBorder,
///   ),
/// )
/// ```
class AppRadius {
  AppRadius._();

  /// 12 — chips, badges, small elements
  static const double xs = 12;

  /// 16 — inputs, buttons
  static const double sm = 16;

  /// 20 — cards
  static const double md = 20;

  /// 24 — dialogs, feature cards
  static const double lg = 24;

  /// 28 — bottom sheets, modals
  static const double xl = 28;

  /// Fully rounded (pill/capsule)
  static const double pill = 9999;

  // -- Convenience BorderRadius instances --

  static BorderRadius get xsBorder => BorderRadius.circular(xs);
  static BorderRadius get smBorder => BorderRadius.circular(sm);
  static BorderRadius get mdBorder => BorderRadius.circular(md);
  static BorderRadius get lgBorder => BorderRadius.circular(lg);
  static BorderRadius get xlBorder => BorderRadius.circular(xl);
  static BorderRadius get pillBorder => BorderRadius.circular(pill);

  /// Top-only rounded corners for bottom sheets.
  static BorderRadius get topXl =>
      const BorderRadius.vertical(top: Radius.circular(xl));

  /// Top-only rounded corners at lg size.
  static BorderRadius get topLg =>
      const BorderRadius.vertical(top: Radius.circular(lg));
}
