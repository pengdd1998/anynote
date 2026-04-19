/// Custom page transitions for GoRouter routes.
///
/// Two transition styles are provided:
/// - [fadeThroughTransition] -- cross-fade used for tab-to-tab navigation.
///   Follows the Material 3 FadeThrough pattern from the motion spec.
/// - [slideTransition] -- warm slide+fade used for push routes (note detail,
///   editor, settings sub-pages). Uses CupertinoPageRoute on iOS for native feel.
///
/// Usage in a GoRoute:
/// ```dart
/// GoRoute(
///   path: '/notes',
///   pageBuilder: fadeThroughTransition(const NotesListScreen()),
/// )
/// ```
library;

import 'dart:io';

import 'package:flutter/cupertino.dart' show CupertinoPage;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Duration for forward page transitions.
const _kForwardDuration = Duration(milliseconds: 300);

/// Duration for reverse (back) page transitions.
const _kReverseDuration = Duration(milliseconds: 250);

/// Slide offset for warm transitions (30px worth in logical units).
const _kSlideOffset = 30.0;

/// Creates a [CustomTransitionPage] with a FadeThrough (cross-fade) animation.
///
/// The outgoing page fades out while the incoming page fades in, with a brief
/// overlap. This is the recommended transition for sibling pages within the
/// same navigation level (e.g. bottom-nav tab switches).
CustomTransitionPage<void> fadeThroughTransition(Widget child) {
  return CustomTransitionPage(
    transitionDuration: _kForwardDuration,
    reverseTransitionDuration: _kForwardDuration,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return _FadeThroughTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        child: child,
      );
    },
  );
}

/// Creates a page with a warm slide+fade transition for push navigation.
///
/// On iOS, uses [CupertinoPage] for native-feeling transitions.
/// On all other platforms, uses a custom [CustomTransitionPage] with:
/// - Forward: slide from right 30px + fade in (300ms, easeOutCubic)
/// - Back: slide to right 30px + fade out (250ms, easeInCubic)
Page<void> slideTransition(Widget child) {
  // Use CupertinoPageRoute on iOS for native platform feel.
  if (Platform.isIOS) {
    return CupertinoPage(child: child);
  }

  return CustomTransitionPage(
    transitionDuration: _kForwardDuration,
    reverseTransitionDuration: _kReverseDuration,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // Convert 30px logical offset to a fraction of screen width.
      final screenWidth = MediaQuery.sizeOf(context).width;
      final offsetFraction = (_kSlideOffset / screenWidth).clamp(0.0, 1.0);

      // Incoming page: slide from right + fade in.
      final slideIn = Tween<Offset>(
        begin: Offset(offsetFraction, 0),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOutCubic));

      final fadeIn = Tween<double>(begin: 0.0, end: 1.0).chain(
        CurveTween(curve: Curves.easeOutCubic),
      );

      // Outgoing page: slide slightly left.
      final slideOut = Tween<Offset>(
        begin: Offset.zero,
        end: Offset(-offsetFraction * 0.5, 0),
      ).chain(CurveTween(curve: Curves.easeOutCubic));

      return SlideTransition(
        position: secondaryAnimation.drive(slideOut),
        child: SlideTransition(
          position: animation.drive(slideIn),
          child: FadeTransition(
            opacity: animation.drive(fadeIn),
            child: child,
          ),
        ),
      );
    },
  );
}

/// Custom fade-through transition that cross-fades two pages.
///
/// During the first half of the animation the outgoing page fades out.
/// During the second half the incoming page fades in. This avoids visual
/// overlap artifacts and matches the Material 3 motion specification.
class _FadeThroughTransition extends StatelessWidget {
  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  const _FadeThroughTransition({
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // Incoming page fades in over the second half.
    final incomingOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: animation,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );

    // Outgoing page fades out over the first half.
    final outgoingOpacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: secondaryAnimation,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    // Slight scale-down on outgoing page for depth.
    final outgoingScale = Tween<double>(begin: 1, end: 0.95).animate(
      CurvedAnimation(
        parent: secondaryAnimation,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    return FadeTransition(
      opacity: outgoingOpacity,
      child: ScaleTransition(
        scale: outgoingScale,
        child: FadeTransition(
          opacity: incomingOpacity,
          child: child,
        ),
      ),
    );
  }
}
