import 'package:flutter/material.dart';

import '../../../../core/constants/app_durations.dart';

/// Staggered entrance animation for note cards.
///
/// Each card fades in and slides up slightly with a delay proportional to its
/// [index], creating a cascading reveal effect when the list first loads.
class StaggeredCardEntrance extends StatefulWidget {
  final int index;
  final int staggerDelay;
  final Widget child;

  const StaggeredCardEntrance({
    super.key,
    required this.index,
    required this.staggerDelay,
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
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // Stagger delay based on index.
    final delay = Duration(milliseconds: widget.staggerDelay * widget.index);
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
        child: widget.child,
      ),
    );
  }
}
