import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_animation.dart';
import 'app_binding.dart';

/// Whether motion is reduced here, and the tokens to use.
///
/// Reached as `context.motion`. With "减少动画" on, every duration is zero
/// and every curve is linear, so what is left is a change of state and not a
/// movement.
///
/// ```dart
/// AnimatedOpacity(
///   duration: context.motion.standard,
///   curve: context.motion.arrive,
/// );
/// ```
class AnimationConfig extends InheritedWidget {
  const AnimationConfig({
    super.key,
    required this.reduceMotion,
    required super.child,
  });

  /// The user asked for fewer animations (in the app, or in the system
  /// settings).
  final bool reduceMotion;

  /// The configuration for [context]; the platform's setting when no
  /// [AnimationConfigInjector] is above it.
  static AnimationConfig of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AnimationConfig>() ??
        AnimationConfig(
          reduceMotion: ReduceMotionSwitch.active,
          child: const SizedBox.shrink(),
        );
  }

  @override
  bool updateShouldNotify(AnimationConfig oldWidget) =>
      reduceMotion != oldWidget.reduceMotion;

  /// [AppAnimation.fast] here.
  Duration get fast => _duration(AppAnimation.fast);

  /// [AppAnimation.standard] here.
  Duration get standard => _duration(AppAnimation.standard);

  /// [AppAnimation.emphasized] here.
  Duration get emphasized => _duration(AppAnimation.emphasized);

  /// [AppAnimation.expressive] here.
  Duration get expressive => _duration(AppAnimation.expressive);

  /// [AppAnimation.arrive] here.
  Curve get arrive => _curve(AppAnimation.arrive);

  /// [AppAnimation.depart] here.
  Curve get depart => _curve(AppAnimation.depart);

  Duration _duration(Duration duration) =>
      reduceMotion ? Duration.zero : duration;

  Curve _curve(Curve curve) => reduceMotion ? Curves.linear : curve;
}

/// `context.motion`: the motion tokens as they apply at [BuildContext].
extension MotionContext on BuildContext {
  AnimationConfig get motion => AnimationConfig.of(this);
}

const _kReduceMotionKey = 'reduce_motion';

/// The user's answer to "减少动画": `null` follows the system setting.
///
/// It is kept on disk, so the answer survives a restart.
final reduceMotionOverrideProvider =
    StateNotifierProvider<ReduceMotionNotifier, bool?>(
  (ref) => ReduceMotionNotifier(),
);

class ReduceMotionNotifier extends StateNotifier<bool?> {
  ReduceMotionNotifier() : super(null) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _set(
        switch (prefs.getString(_kReduceMotionKey)) {
          'on' => true,
          'off' => false,
          _ => null,
        },
      );
    } catch (_) {
      // Nothing saved, or no storage yet: keep following the system.
    }
  }

  /// Remembers [value] and writes it to disk.
  Future<void> set(bool? value) async {
    _set(value);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kReduceMotionKey,
        switch (value) {
          true => 'on',
          false => 'off',
          null => 'system',
        },
      );
    } catch (_) {
      // The answer is in memory for this session either way.
    }
  }

  void _set(bool? value) {
    state = value;
    ReduceMotionSwitch.override = value;
  }
}

/// Puts the reduce-motion setting where widgets can read it.
class AnimationConfigInjector extends ConsumerWidget {
  const AnimationConfigInjector({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userOverride = ref.watch(reduceMotionOverrideProvider);
    final systemDisabled = MediaQuery.disableAnimationsOf(context);

    return AnimationConfig(
      reduceMotion: userOverride ?? systemDisabled,
      child: child,
    );
  }
}
