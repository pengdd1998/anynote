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
  static List<BoxShadow> get sm => [
        BoxShadow(
          color: AppColors.shadowLight,
          offset: const Offset(0, 1),
          blurRadius: 3,
        ),
      ];

  /// Standard elevation — prominent cards, list headers.
  static List<BoxShadow> get md => [
        BoxShadow(
          color: AppColors.shadowLight,
          offset: const Offset(0, 2),
          blurRadius: 8,
        ),
      ];

  /// High elevation — dialogs, floating panels.
  static List<BoxShadow> get lg => [
        BoxShadow(
          color: AppColors.shadowMedium,
          offset: const Offset(0, 4),
          blurRadius: 16,
        ),
      ];

  /// Maximum elevation — overlays, popovers.
  static List<BoxShadow> get xl => [
        BoxShadow(
          color: AppColors.shadowMedium,
          offset: const Offset(0, 8),
          blurRadius: 24,
        ),
      ];

  // ---------------------------------------------------------------------------
  // Dark mode
  // ---------------------------------------------------------------------------

  static List<BoxShadow> get smDark => [
        BoxShadow(
          color: AppColors.shadowDark,
          offset: const Offset(0, 1),
          blurRadius: 4,
        ),
      ];

  static List<BoxShadow> get mdDark => [
        BoxShadow(
          color: AppColors.shadowDark,
          offset: const Offset(0, 2),
          blurRadius: 8,
        ),
      ];

  static List<BoxShadow> get lgDark => [
        BoxShadow(
          color: AppColors.shadowDark,
          offset: const Offset(0, 4),
          blurRadius: 16,
        ),
      ];

  static List<BoxShadow> get xlDark => [
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
}
