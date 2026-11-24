import 'package:flutter/animation.dart';
import 'package:flutter/physics.dart';

/// Motion tokens: four durations, two curves, two springs.
///
/// The only place an animation gets its time or its easing.
///
/// ```dart
/// // A widget that animates by duration takes the token as it is.
/// AnimatedOpacity(duration: AppAnimation.standard, curve: AppAnimation.arrive);
///
/// // Authored motion — a stagger, a loop, a spring, a page transition —
/// // asks the context instead: shortening a duration would leave the wait
/// // and the overshoot in place.
/// AnimatedOpacity(duration: context.motion.standard, curve: context.motion.arrive);
/// ```
class AppAnimation {
  AppAnimation._();

  /// Immediate feedback: a press, a toggle, an arrow turning, text swapping.
  static const fast = Duration(milliseconds: 120);

  /// A routine state change: a sheet, a card settling, a tab switch, a fade.
  static const standard = Duration(milliseconds: 220);

  /// A page change.
  static const emphasized = Duration(milliseconds: 320);

  /// The one authored move a screen is allowed: a note settling into place.
  static const expressive = Duration(milliseconds: 480);

  /// Coming into place: Material's emphasized decelerate. Quick to start,
  /// then a long glide to rest — the way a hand puts something down.
  static const arrive = Cubic(0.05, 0.7, 0.1, 1);

  /// Leaving: Material's emphasized accelerate. It hangs, then goes.
  static const depart = Cubic(0.3, 0, 0.8, 0.15);

  /// Pressing down. Over-damped, so nothing wobbles under a thumb.
  static const press = SpringDescription(mass: 1, stiffness: 1400, damping: 90);

  /// Letting go. Just short of critical damping, so a thing lands with one
  /// small dip past its place and stops: paper, not rubber.
  static const settle = SpringDescription(mass: 1, stiffness: 500, damping: 31);

  /// How long [settle] takes to come to rest.
  static const _settleSeconds = 0.45;

  static final Map<int, Curve> _settleCurves = {};

  /// [settle] as a curve, for widgets that animate by duration: the same
  /// landing, fitted into [duration].
  static Curve settleCurve(Duration duration) {
    return _settleCurves.putIfAbsent(
      duration.inMilliseconds,
      () => _SpringCurve(SpringSimulation(settle, 0, 1, 0)),
    );
  }
}

/// Plays a [SpringSimulation] over the unit interval.
class _SpringCurve extends Curve {
  const _SpringCurve(this.simulation);

  final SpringSimulation simulation;

  @override
  double transformInternal(double t) =>
      simulation.x(t * AppAnimation._settleSeconds);
}
