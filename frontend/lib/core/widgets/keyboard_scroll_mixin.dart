import 'package:flutter/material.dart';

/// Mixin that scrolls the focused input field into view after the keyboard
/// appears or disappears.
///
/// Add `with KeyboardScrollMixin` to a `ConsumerStatefulWidget` state.
/// The mixin adds itself as a [WidgetsBindingObserver] and, on every
/// metrics change (keyboard open/close, rotation), scrolls the primary
/// focus node into the visible area with a short animation.
///
/// The host [State] class must also mix in [WidgetsBindingObserver].
///
/// ```dart
/// class _MyScreenState extends ConsumerState<MyScreen>
///     with WidgetsBindingObserver, KeyboardScrollMixin {
///   ...
/// }
/// ```
mixin KeyboardScrollMixin<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
  }

  /// Call from [WidgetsBindingObserver.didChangeMetrics].
  ///
  /// ```dart
  /// @override
  /// void didChangeMetrics() {
  ///   super.didChangeMetrics();
  ///   onKeyboardMetricsChanged();
  /// }
  /// ```
  void onKeyboardMetricsChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final focus = FocusManager.instance.primaryFocus;
      if (focus == null) return;
      final ctx = focus.context;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.2,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }
}
