import 'package:flutter/material.dart';

// This file exports KeyboardAvoider (renamed from AnimatedKeyboardPadding).
// The import path `animated_keyboard_padding.dart` is kept for compatibility.

import '../constants/app_durations.dart';
import '../theme/animation_config.dart';

/// Provides smooth animated keyboard avoidance for form screens.
///
/// Place inside a Scaffold with `resizeToAvoidBottomInset: false`.
/// The Scaffold won't consume view insets, so this widget can read the raw
/// keyboard height from `MediaQuery.viewInsetsOf` and animate the bottom
/// padding via [AnimatedPadding]. After the padding animation settles,
/// it scrolls the currently focused field into view.
///
/// ```dart
/// Scaffold(
///   resizeToAvoidBottomInset: false,
///   body: SafeArea(
///     child: KeyboardAvoider(
///       child: SingleChildScrollView(child: ...),
///     ),
///   ),
/// )
/// ```
class KeyboardAvoider extends StatefulWidget {
  final Widget child;
  final double extraBottomPadding;

  const KeyboardAvoider({
    super.key,
    required this.child,
    this.extraBottomPadding = 40,
  });

  @override
  State<KeyboardAvoider> createState() => _KeyboardAvoiderState();
}

class _KeyboardAvoiderState extends State<KeyboardAvoider> {
  double _lastInset = 0;
  int _scrollGeneration = 0;

  @override
  Widget build(BuildContext context) {
    final config = AnimationConfig.of(context);
    final inset = MediaQuery.viewInsetsOf(context).bottom;

    if (inset != _lastInset) {
      _lastInset = inset;
      final gen = ++_scrollGeneration;
      Future.delayed(
        config.reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 350),
        () {
          if (gen != _scrollGeneration || !mounted) return;
          _scrollToFocusedField();
        },
      );
    }

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: inset + widget.extraBottomPadding),
      duration: config.duration(AppDurations.animation),
      curve: config.curve(Curves.easeOutCubic),
      child: widget.child,
    );
  }

  void _scrollToFocusedField() {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null) return;
    final ctx = focus.context;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.3,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }
}
