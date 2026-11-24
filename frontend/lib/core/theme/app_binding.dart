import 'package:flutter/rendering.dart' show SemanticsBinding;
import 'package:flutter/widgets.dart';

/// The in-app answer to "减少动画", for code that runs outside a build.
///
/// `null` follows the platform. `ReduceMotionNotifier` (animation_config.dart)
/// keeps it in step with the setting. It is a plain static rather than a
/// provider because the binding sits below the widget tree and outlives every
/// container in it.
abstract final class ReduceMotionSwitch {
  /// `true`: fewer animations. `false`: all of them. `null`: the platform
  /// decides.
  static bool? override;

  /// Whether motion is reduced right now: the in-app answer, else the
  /// platform's.
  static bool get active =>
      override ??
      WidgetsBinding
          .instance.platformDispatcher.accessibilityFeatures.disableAnimations;
}

/// Tells Flutter about the in-app "减少动画" switch.
///
/// Before an animation runs by duration, `AnimationController` asks the
/// binding whether animations are off, and if so runs it in a single frame.
/// The platform's own setting is what normally answers. Reporting the in-app
/// switch here is what lets "减少动画" reach everything Flutter times itself —
/// sheets, menus, switches, ink, every `Animated*` widget — without each of
/// them having to ask. What a duration cannot express (a stagger's wait, a
/// loop, a spring) is handled by `context.motion` where it is authored.
///
/// Indicators whose animation *is* the message (a progress ring) are exempt
/// by Flutter's own rule and keep turning.
mixin ReduceMotionBinding on SemanticsBinding {
  @override
  bool get disableAnimations =>
      ReduceMotionSwitch.override ?? super.disableAnimations;
}

/// The app's binding.
///
/// [initialize] stands in for `WidgetsFlutterBinding.ensureInitialized()` and
/// has to run first in `main()`: the first binding created is the one the
/// whole app gets.
class AppBinding extends WidgetsFlutterBinding with ReduceMotionBinding {
  static WidgetsBinding initialize() => AppBinding();
}
