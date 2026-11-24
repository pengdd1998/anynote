/// Press feedback for anything tappable: it gives slightly, like paper under
/// a thumb, and lands when let go.
///
/// With "减少动画" on nothing scales. A press is shown by dimming instead, so
/// the feedback is still there without the movement.
library;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../theme/animation_config.dart';
import '../theme/app_animation.dart';

/// Default press scale factor.
const _kPressScale = 0.97;

/// How much a press dims when motion is reduced.
const _pressedOpacity = 0.72;

class PressableScale extends StatefulWidget {
  /// Callback invoked on tap.
  final VoidCallback? onPressed;

  /// The widget to wrap with press feedback.
  final Widget child;

  /// Optional scale factor override. Defaults to 0.97.
  final double scaleDown;

  /// Border radius for the InkWell splash.
  final BorderRadius borderRadius;

  const PressableScale({
    super.key,
    required this.onPressed,
    required this.child,
    this.scaleDown = _kPressScale,
    this.borderRadius = BorderRadius.zero,
  });

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale>
    with SingleTickerProviderStateMixin {
  /// 1: at rest. [PressableScale.scaleDown]: pressed.
  late final AnimationController _scale;

  /// Whether the thumb is down while motion is reduced.
  bool _dimmed = false;

  @override
  void initState() {
    super.initState();
    _scale = AnimationController(
      vsync: this,
      value: 1.0,
      lowerBound: 0.0,
      upperBound: 1.2,
    );
  }

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  void _to(double target) {
    if (context.motion.reduceMotion) {
      setState(() => _dimmed = target != 1.0);
      return;
    }
    _scale.animateWith(
      SpringSimulation(
        target == widget.scaleDown ? AppAnimation.press : AppAnimation.settle,
        _scale.value,
        target,
        // Carry the motion it already has, so a release mid-press is seamless.
        (target - _scale.value) * 2.0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _to(widget.scaleDown),
      onTapUp: (_) => _to(1.0),
      onTapCancel: () => _to(1.0),
      onTap: widget.onPressed,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) => Opacity(
          opacity: _dimmed ? _pressedOpacity : 1,
          child: Transform.scale(
            scale: _scale.value,
            child: child,
          ),
        ),
        child: widget.child,
      ),
    );
  }
}
