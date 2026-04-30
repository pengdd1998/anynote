import 'package:flutter/material.dart';

import '../../../../core/constants/app_durations.dart';

/// Staggered entrance animation for note cards.
///
/// Each card fades in, slides up, and scales up with a delay proportional to
/// its [index], creating a cascading reveal effect when the list first loads.
/// Caps the stagger at [maxStagger] items to avoid long waits on large lists.
class StaggeredCardEntrance extends StatefulWidget {
  final int index;
  final int staggerDelay;
  final int maxStagger;
  final Widget child;

  const StaggeredCardEntrance({
    super.key,
    required this.index,
    required this.staggerDelay,
    this.maxStagger = 10,
    required this.child,
  });

  @override
  State<StaggeredCardEntrance> createState() => _StaggeredCardEntranceState();
}

class _StaggeredCardEntranceState extends State<StaggeredCardEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDurations.mediumAnimation,
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _scale = Tween<double>(
      begin: 0.97,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    // Stagger delay capped at maxStagger items.
    final cappedIndex = widget.index.clamp(0, widget.maxStagger);
    final delay = Duration(milliseconds: widget.staggerDelay * cappedIndex);
    Future.delayed(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: ScaleTransition(
          scale: _scale,
          child: widget.child,
        ),
      ),
    );
  }
}
