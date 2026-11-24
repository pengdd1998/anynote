import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../../../core/theme/animation_config.dart';
import '../../../../core/theme/app_animation.dart';

/// A note landing in the list.
///
/// The first screenful settles into place, each a moment after the one
/// before, like sheets laid down by hand. Every card is there and readable
/// from the first frame — slightly large and low — and comes to rest with
/// one small dip; none waits invisible for its turn.
///
/// Only the first [maxStagger] cards do this, and only while motion is on.
class StaggeredCardEntrance extends StatelessWidget {
  const StaggeredCardEntrance({
    super.key,
    required this.index,
    required this.child,
    this.maxStagger = 8,
  });

  /// The card's place in the list.
  final int index;

  final Widget child;

  /// How many cards, counted from the first, land one after another. The
  /// whole list is never more than a screen's worth behind.
  final int maxStagger;

  /// The pause between one card and the next.
  static const stagger = Duration(milliseconds: 24);

  @override
  Widget build(BuildContext context) {
    if (index >= maxStagger || context.motion.reduceMotion) {
      return child;
    }
    return _LandingNote(delay: stagger * index, child: child);
  }
}

class _LandingNote extends StatefulWidget {
  const _LandingNote({required this.delay, required this.child});

  final Duration delay;
  final Widget child;

  @override
  State<_LandingNote> createState() => _LandingNoteState();
}

class _LandingNoteState extends State<_LandingNote>
    with SingleTickerProviderStateMixin {
  /// 0: still held above its place. 1: at rest. Past 1 for a moment: the dip.
  late final AnimationController _rest;
  Timer? _timer;

  /// How high the card starts, in logical pixels.
  static const _lift = 10.0;

  /// How much larger than its place it starts.
  static const _grow = 0.035;

  @override
  void initState() {
    super.initState();
    _rest = AnimationController(vsync: this, value: 0);
    _timer = Timer(widget.delay, () {
      if (mounted) {
        _rest.animateWith(SpringSimulation(AppAnimation.settle, 0, 1, 0));
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _rest.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _rest,
      builder: (context, child) {
        final held = 1 - _rest.value;
        return Transform.translate(
          offset: Offset(0, _lift * held),
          child: Transform.scale(
            scale: 1 + _grow * held,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
