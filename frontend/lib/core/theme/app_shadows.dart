import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Shadow tokens for the warm design system.
///
/// Soft, diffused shadows that create depth without harshness.
/// Light-mode shadows are nearly invisible; dark-mode shadows use
/// slightly higher contrast to remain perceptible on dark surfaces.
///
/// ```dart
/// Container(
///   decoration: BoxDecoration(
///     boxShadow: AppShadows.md,
///     borderRadius: AppRadius.mdBorder,
///     color: AppColors.lightCardBg,
///   ),
/// )
/// ```
class AppShadows {
  AppShadows._();

  // ---------------------------------------------------------------------------
  // Light mode
  // ---------------------------------------------------------------------------

  /// Subtle lift — list cards, compact tiles.
  static final List<BoxShadow> sm = [
    BoxShadow(
      color: AppColors.shadowLight,
      offset: const Offset(0, 1),
      blurRadius: 4,
    ),
  ];

  /// Standard elevation — prominent cards, list headers.
  static final List<BoxShadow> md = [
    BoxShadow(
      color: AppColors.shadowLight,
      offset: const Offset(0, 2),
      blurRadius: 12,
    ),
  ];

  /// High elevation — dialogs, floating panels.
  static final List<BoxShadow> lg = [
    BoxShadow(
      color: AppColors.shadowMedium,
      offset: const Offset(0, 4),
      blurRadius: 20,
    ),
  ];

  /// Maximum elevation — overlays, popovers.
  static final List<BoxShadow> xl = [
    BoxShadow(
      color: AppColors.shadowMedium,
      offset: const Offset(0, 8),
      blurRadius: 24,
    ),
  ];

  /// Skeuomorphic paper lift — sticky-note cards. Two layers: a tight contact
  /// shadow plus a warm diffuse one, so the paper looks placed on a desk.
  static final List<BoxShadow> paper = [
    BoxShadow(
      color: AppColors.paperShadow,
      offset: const Offset(3, 6),
      blurRadius: 16,
    ),
    BoxShadow(
      color: AppColors.paperShadowNear,
      offset: const Offset(1, 2),
      blurRadius: 4,
    ),
  ];

  /// Paper lift in dark mode — soft black, no warm tint needed on navy.
  static final List<BoxShadow> paperDark = [
    BoxShadow(
      color: AppColors.shadowDark,
      offset: const Offset(3, 6),
      blurRadius: 16,
    ),
    BoxShadow(
      color: AppColors.shadowDark,
      offset: const Offset(1, 2),
      blurRadius: 4,
    ),
  ];

  // ---------------------------------------------------------------------------
  // Dark mode
  // ---------------------------------------------------------------------------

  static final List<BoxShadow> smDark = [
    BoxShadow(
      color: AppColors.shadowDark,
      offset: const Offset(0, 1),
      blurRadius: 4,
    ),
  ];

  static final List<BoxShadow> mdDark = [
    BoxShadow(
      color: AppColors.shadowDark,
      offset: const Offset(0, 2),
      blurRadius: 8,
    ),
  ];

  static final List<BoxShadow> lgDark = [
    BoxShadow(
      color: AppColors.shadowDark,
      offset: const Offset(0, 4),
      blurRadius: 16,
    ),
  ];

  static final List<BoxShadow> xlDark = [
    BoxShadow(
      color: AppColors.shadowDark,
      offset: const Offset(0, 8),
      blurRadius: 24,
    ),
  ];

  // ---------------------------------------------------------------------------
  // Resolve by brightness
  // ---------------------------------------------------------------------------

  static List<BoxShadow> smOf(Brightness brightness) =>
      brightness == Brightness.dark ? smDark : sm;

  static List<BoxShadow> mdOf(Brightness brightness) =>
      brightness == Brightness.dark ? mdDark : md;

  static List<BoxShadow> lgOf(Brightness brightness) =>
      brightness == Brightness.dark ? lgDark : lg;

  static List<BoxShadow> xlOf(Brightness brightness) =>
      brightness == Brightness.dark ? xlDark : xl;

  static List<BoxShadow> paperOf(Brightness brightness) =>
      brightness == Brightness.dark ? paperDark : paper;
}
