/// A wrapper widget that applies a subtle scale-down animation on press.
///
/// Scales the child to 0.95 on press and springs back to 1.0 on release,
/// giving tactile feedback for buttons and cards. Uses [AnimatedScale] with
/// a short 100ms duration and [Curves.easeOutCubic] for a natural feel.
///
/// ```dart
/// PressableScale(
///   onPressed: () => doSomething(),
///   child: FilledButton(child: Text('Action')),
/// )
/// ```
library;

import 'package:flutter/material.dart';

import '../constants/app_durations.dart';

/// Default press scale factor.
const _kPressScale = 0.95;

/// Default animation duration for press feedback.
const _kPressDuration = AppDurations.veryShortAnimation;

class PressableScale extends StatefulWidget {
  /// Callback invoked on tap.
  final VoidCallback? onPressed;

  /// The widget to wrap with press-scale feedback.
  final Widget child;

  /// Optional scale factor override. Defaults to 0.95.
  final double scaleDown;

  /// Optional duration override. Defaults to 100ms.
  final Duration duration;

  /// Border radius for the InkWell splash.
  final BorderRadius borderRadius;

  const PressableScale({
    super.key,
    required this.onPressed,
    required this.child,
    this.scaleDown = _kPressScale,
    this.duration = _kPressDuration,
    this.borderRadius = BorderRadius.zero,
  });

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _isPressed = false;

  void _setPressed(bool pressed) {
    if (_isPressed == pressed) return;
    setState(() => _isPressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _isPressed ? widget.scaleDown : 1.0,
        duration: widget.duration,
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
