import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Animation configuration that respects the user's reduce motion preference.
///
/// When animations are disabled (via system setting or manual override),
/// all animation durations are reduced to near-zero for instant transitions.
/// This helps users with vestibular motion sensitivity or cognitive load.
///
/// Usage:
/// ```dart
/// final config = AnimationConfig.of(context);
/// final duration = config.duration(const Duration(milliseconds: 300));
/// final curve = config.curve(Curves.easeInOut);
/// ```
class AnimationConfig extends InheritedWidget {
  /// Creates an animation configuration for the subtree.
  const AnimationConfig({
    super.key,
    required this.reduceMotion,
    required super.child,
  });

  /// Whether animations should be reduced/skipped.
  ///
  /// When true, durations become Duration.zero and curves are linear.
  final bool reduceMotion;

  /// The current animation config from the closest [AnimationConfig] ancestor.
  ///
  /// Defaults to respecting system settings if no ancestor is found.
  static AnimationConfig of(BuildContext context) {
    final result =
        context.dependOnInheritedWidgetOfExactType<AnimationConfig>();
    return result ??
        AnimationConfig(
          reduceMotion: MediaQuery.disableAnimationsOf(context),
          child: const SizedBox.shrink(),
        );
  }

  @override
  bool updateShouldNotify(AnimationConfig oldWidget) =>
      reduceMotion != oldWidget.reduceMotion;

  /// Returns the effective duration based on [reduceMotion] setting.
  ///
  /// When reduce motion is enabled, returns [Duration.zero] for instant
  /// transitions. Otherwise returns the original [duration].
  Duration duration(Duration duration) {
    if (reduceMotion) {
      return Duration.zero;
    }
    return duration;
  }

  /// Returns an effective curve based on [reduceMotion] setting.
  ///
  /// When reduce motion is enabled, returns [Curves.linear] (no easing).
  /// Otherwise returns the original [curve].
  Curve curve(Curve curve) {
    if (reduceMotion) {
      return Curves.linear;
    }
    return curve;
  }

  /// Lerps a value with respect to the reduce motion setting.
  ///
  /// When reduce motion is enabled, returns the [end] value immediately.
  /// Otherwise performs standard linear interpolation.
  double lerp(double begin, double end, double t) {
    if (reduceMotion) {
      return end;
    }
    return lerpDouble(begin, end, t)!;
  }

  /// Wraps a child with animation-aware behavior.
  ///
  /// When reduce motion is enabled, the child is rendered immediately.
  /// Otherwise, the [builder] is called with the animation value.
  static Widget builder({
    required BuildContext context,
    required Animation<double> animation,
    required Widget Function(BuildContext, double) builder,
  }) {
    final config = of(context);
    if (config.reduceMotion) {
      return builder(context, 1.0);
    }
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => builder(context, animation.value),
    );
  }
}

/// User override for reduce motion (null = follow system, true = always on, false = always off).
final reduceMotionOverrideProvider = StateProvider<bool?>((ref) => null);

/// A widget that injects the current reduce motion setting into the widget tree
/// via [AnimationConfig].
///
/// This allows descendant widgets to query the setting without directly
/// accessing the provider.
class AnimationConfigInjector extends ConsumerWidget {
  final Widget child;

  const AnimationConfigInjector({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userOverride = ref.watch(reduceMotionOverrideProvider);
    final systemDisabled = MediaQuery.disableAnimationsOf(context);
    final effectiveReduceMotion = userOverride ?? systemDisabled;

    return AnimationConfig(
      reduceMotion: effectiveReduceMotion,
      child: child,
    );
  }
}
