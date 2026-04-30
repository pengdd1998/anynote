/// A wrapper widget that applies a spring-based scale animation on press.
///
/// Scales the child down on press using a critically-damped spring, then
/// springs back to 1.0 on release with a subtle bounce for tactile feedback.
/// Respects the reduce-motion accessibility setting when available.
library;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../theme/animation_config.dart';

/// Default press scale factor.
const _kPressScale = 0.95;

/// Critically-damped spring for press-down (fast, no overshoot).
const _pressSpring = SpringDescription(
  mass: 1.0,
  stiffness: 1000.0,
  damping: 40.0,
);

/// Slightly underdamped spring for release (subtle bounce).
const _releaseSpring = SpringDescription(
  mass: 1.0,
  stiffness: 400.0,
  damping: 18.0,
);

class PressableScale extends StatefulWidget {
  /// Callback invoked on tap.
  final VoidCallback? onPressed;

  /// The widget to wrap with press-scale feedback.
  final Widget child;

  /// Optional scale factor override. Defaults to 0.95.
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
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      value: 1.0,
      lowerBound: 0.0,
      upperBound: 1.2,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _animateTo(double target) {
    final simulation = SpringSimulation(
      target == widget.scaleDown ? _pressSpring : _releaseSpring,
      _controller.value,
      target,
      // Compute velocity towards the target for continuity.
      (target - _controller.value) * 2.0,
    );
    _controller.animateWith(simulation);
  }

  bool get _reduceMotion {
    try {
      return AnimationConfig.of(context).reduceMotion;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        if (_reduceMotion) {
          _controller.value = widget.scaleDown;
        } else {
          _animateTo(widget.scaleDown);
        }
      },
      onTapUp: (_) {
        if (_reduceMotion) {
          _controller.value = 1.0;
        } else {
          _animateTo(1.0);
        }
      },
      onTapCancel: () {
        if (_reduceMotion) {
          _controller.value = 1.0;
        } else {
          _animateTo(1.0);
        }
      },
      onTap: widget.onPressed,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _controller.value,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}
