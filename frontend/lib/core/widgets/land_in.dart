import 'package:flutter/material.dart';

import '../theme/app_animation.dart';
import '../theme/app_binding.dart';

/// Something arriving in its place: it comes in a touch large and high, and
/// lands with one small dip — the way a stamp comes down on paper.
///
/// Plays once, when it is inserted. With "减少动画" on it is simply there.
class LandIn extends StatefulWidget {
  const LandIn({
    super.key,
    required this.child,
    this.fromScale = 1.25,
    this.drop = 3,
  });

  final Widget child;

  /// How much larger than its place it starts.
  final double fromScale;

  /// How much higher than its place it starts, in logical pixels.
  final double drop;

  @override
  State<LandIn> createState() => _LandInState();
}

class _LandInState extends State<LandIn> with SingleTickerProviderStateMixin {
  late final AnimationController _land;
  late final Curve _curve;

  @override
  void initState() {
    super.initState();
    // Read once, here: this plays a single time and does not follow the
    // setting while it plays.
    final duration =
        ReduceMotionSwitch.active ? Duration.zero : AppAnimation.fast;
    _curve = AppAnimation.settleCurve(AppAnimation.fast);
    _land = AnimationController(vsync: this, duration: duration)..forward();
  }

  @override
  void dispose() {
    _land.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _land,
      builder: (context, child) {
        // Past 1 for a moment: the dip.
        final placed = _curve.transform(_land.value);
        final coming = 1 - placed;
        return Transform.translate(
          offset: Offset(0, -widget.drop * coming),
          child: Transform.scale(
            scale: 1 + (widget.fromScale - 1) * coming,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
