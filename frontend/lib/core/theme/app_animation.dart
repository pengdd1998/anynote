import 'package:flutter/animation.dart';

/// Animation and motion tokens for the warm design system.
///
/// Gentle, warm transitions that feel organic — never mechanical.
/// Use these consistently so the app feels alive and cohesive.
///
/// ```dart
/// AnimatedOpacity(
///   duration: AppAnimation.medium,
///   curve: AppAnimation.easeOut,
///   ...
/// )
/// ```
class AppAnimation {
  AppAnimation._();

  // ---------------------------------------------------------------------------
  // Durations
  // ---------------------------------------------------------------------------

  static const Duration instant = Duration(milliseconds: 100);
  static const Duration short = Duration(milliseconds: 200);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration long = Duration(milliseconds: 450);
  static const Duration extraLong = Duration(milliseconds: 600);

  // ---------------------------------------------------------------------------
  // Curves
  // ---------------------------------------------------------------------------

  /// Default curve — deceleration for entrances and state changes.
  static const Curve easeOut = Curves.easeOut;

  /// Entrance curve with slight overshoot — playful but not bouncy.
  static const Curve easeOutBack = Curves.easeOutBack;

  /// Exit curve — gentle acceleration.
  static const Curve easeIn = Curves.easeIn;

  /// Standard Material ease-in-out for symmetrical animations.
  static const Curve easeInOut = Curves.easeInOut;

  /// Emphasized decelerate (Material 3 motion).
  static const Curve emphasized = Curves.easeOutCubic;

  /// Snappy spring-like curve for micro-interactions.
  static const Curve springy = Curves.elasticOut;
}
