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

  /// 8 — tag badges, small rounded elements
  static const double xxs = 8;

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

  static const BorderRadius xxsBorder =
      BorderRadius.all(Radius.circular(xxs));
  static const BorderRadius xsBorder =
      BorderRadius.all(Radius.circular(xs));
  static const BorderRadius smBorder =
      BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdBorder =
      BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgBorder =
      BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlBorder =
      BorderRadius.all(Radius.circular(xl));
  static const BorderRadius pillBorder =
      BorderRadius.all(Radius.circular(pill));

  /// Top-only rounded corners for bottom sheets.
  static const BorderRadius topXl =
      BorderRadius.vertical(top: Radius.circular(xl));

  /// Top-only rounded corners at lg size.
  static const BorderRadius topLg =
      BorderRadius.vertical(top: Radius.circular(lg));
}
