/// Page transitions for GoRouter routes.
///
/// - [slideTransition] — pushing a page lifts a sheet of paper onto the desk:
///   the new page rises from a little lower down, a touch smaller, with its
///   shadow still soft, while the page under it recedes and dims. Back is the
///   same move in reverse, faster. iOS keeps its own transition.
/// - [fadeThroughTransition] — tab to tab: one page fades out, the next fades
///   in. Nothing moves, so it is the same with or without motion.
/// - [bottomSheetTransition] — an overlay route that comes up from the bottom
///   edge, like a sheet pulled out from under a stack.
///
/// With "减少动画" on, every one of them is a short fade.
///
/// Usage in a GoRoute:
/// ```dart
/// GoRoute(
///   path: '/notes',
///   pageBuilder: (context, state) =>
///       fadeThroughTransition(const NotesListScreen()),
/// )
/// ```
library;

import 'package:flutter/cupertino.dart' show CupertinoPage;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../platform/platform_utils.dart';
import 'app_animation.dart';
import 'app_binding.dart';
import 'animation_config.dart';

/// A page is pushed onto the one before it. iOS keeps its own transition.
Page<void> slideTransition(Widget child) {
  if (PlatformUtils.isIOS) {
    return CupertinoPage<void>(child: child);
  }
  // Decided when the page is created; a route cannot change its length midway.
  final reduced = ReduceMotionSwitch.active;
  return CustomTransitionPage<void>(
    child: child,
    transitionDuration: reduced ? AppAnimation.fast : AppAnimation.emphasized,
    reverseTransitionDuration:
        reduced ? AppAnimation.fast : AppAnimation.standard,
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        _SheetLiftTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: child,
    ),
  );
}

/// Sibling pages at the same level (bottom-navigation tabs).
Page<void> fadeThroughTransition(Widget child) {
  return CustomTransitionPage<void>(
    child: child,
    transitionDuration: AppAnimation.standard,
    reverseTransitionDuration: AppAnimation.standard,
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        _FadeThroughTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: child,
    ),
  );
}

/// An overlay route that covers the page below it but does not replace it.
Page<void> bottomSheetTransition(Widget child) {
  final reduced = ReduceMotionSwitch.active;
  return CustomTransitionPage<void>(
    barrierDismissible: true,
    barrierColor: Colors.black54,
    opaque: false,
    transitionDuration: reduced ? AppAnimation.fast : AppAnimation.emphasized,
    reverseTransitionDuration:
        reduced ? AppAnimation.fast : AppAnimation.standard,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final motion = context.motion;
      final eased = animation.drive(
        Tween<double>(begin: 0, end: 1).chain(CurveTween(curve: motion.arrive)),
      );
      if (motion.reduceMotion) {
        return FadeTransition(opacity: eased, child: child);
      }
      return SlideTransition(
        position: eased.drive(
          Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero),
        ),
        child: FadeTransition(opacity: eased, child: child),
      );
    },
    child: child,
  );
}

/// A sheet of paper lifted onto the desk.
///
/// The inner layers move with [animation] — this page arriving. The outer
/// ones move with [secondaryAnimation] — another page being lifted onto this
/// one, which recedes and goes quiet underneath.
class _SheetLiftTransition extends StatelessWidget {
  const _SheetLiftTransition({
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  /// How far down the sheet starts.
  static const _rise = 24.0;

  /// How much smaller than the desk it starts.
  static const _shrink = 0.04;

  /// How far the page underneath backs off.
  static const _recede = 0.015;

  /// How much darker the page underneath gets.
  static const _dim = 0.08;

  @override
  Widget build(BuildContext context) {
    final motion = context.motion;
    final arriving = animation.drive(
      Tween<double>(begin: 0, end: 1).chain(CurveTween(curve: motion.arrive)),
    );
    if (motion.reduceMotion) {
      return FadeTransition(opacity: arriving, child: child);
    }

    final covered = secondaryAnimation.drive(
      Tween<double>(begin: 0, end: 1).chain(CurveTween(curve: motion.arrive)),
    );
    return Stack(
      children: [
        Transform.scale(
          scale: 1 - _recede * covered.value,
          alignment: Alignment.topCenter,
          child: FadeTransition(
            opacity: arriving,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.26),
                    blurRadius: 28,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              child: SlideTransition(
                position: arriving.drive(
                  Tween<Offset>(
                    begin: const Offset(0, _rise),
                    end: Offset.zero,
                  ),
                ),
                child: ScaleTransition(
                  scale: arriving.drive(
                    Tween<double>(begin: 1 - _shrink, end: 1),
                  ),
                  alignment: Alignment.topCenter,
                  child: child,
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: FadeTransition(
              opacity: covered.drive(
                Tween<double>(begin: 0, end: _dim),
              ),
              child: const ColoredBox(color: Colors.black),
            ),
          ),
        ),
      ],
    );
  }
}

/// The outgoing page fades out, then the incoming one fades in. They do not
/// overlap, so nothing shimmers.
class _FadeThroughTransition extends StatelessWidget {
  const _FadeThroughTransition({
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final incoming = animation.drive(_incoming);
    final outgoing = secondaryAnimation.drive(_outgoing);

    return FadeTransition(
      opacity: outgoing,
      child: FadeTransition(opacity: incoming, child: child),
    );
  }

  static const _inAt = Interval(0.35, 1, curve: AppAnimation.arrive);
  static const _outBy = Interval(0, 0.45, curve: AppAnimation.depart);

  /// The page arriving: the second part of the beat.
  static final _incoming = _arriving.chain(CurveTween(curve: _inAt));

  /// The page being replaced: fully there until the next one starts, gone by
  /// the time it begins to show.
  static final _outgoing = _leaving.chain(CurveTween(curve: _outBy));

  static final _arriving = Tween<double>(begin: 0, end: 1);
  static final _leaving = Tween<double>(begin: 1, end: 0);
}
