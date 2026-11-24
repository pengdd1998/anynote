import 'package:flutter/material.dart';
import '../theme/app_animation.dart';

/// Scrolls the nearest [Scrollable] ancestor so the widget at [focusNode]
/// is positioned at [alignment] (0 = top, 0.5 = center, 1 = bottom) in the
/// visible viewport.
///
/// Uses two post-frame callbacks to wait for the Scaffold resize (from
/// `resizeToAvoidBottomInset`) and layout rebuild to complete before
/// calculating the scroll target.
///
/// Wire this into each [FocusNode]'s listener:
/// ```dart
/// _emailFocus.addListener(() => ensureVisibleOnFocus(_emailFocus));
/// ```
void ensureVisibleOnFocus(FocusNode focusNode, {double alignment = 0.5}) {
  if (!focusNode.hasFocus) return;

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!focusNode.hasFocus) return;
    final ctx = focusNode.context;
    if (ctx == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!focusNode.hasFocus) return;
      final ctx = focusNode.context;
      if (ctx == null) return;

      Scrollable.ensureVisible(
        ctx,
        alignment: alignment,
        duration: AppAnimation.emphasized,
        curve: AppAnimation.arrive,
      );
    });
  });
}
