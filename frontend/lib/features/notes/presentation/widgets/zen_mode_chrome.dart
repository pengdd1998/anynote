import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// Minimal chrome shown at the top of the screen in zen mode.
///
/// Displays a back arrow (to exit), a fullscreen-exit icon, and toggles for
/// focus mode and typewriter scrolling. The chrome fades in/out based on the
/// provided animation controller.
class ZenModeChrome extends StatelessWidget {
  /// Animation controller driving the chrome fade transition.
  /// Should have value 1.0 when chrome is visible, 0.0 when hidden.
  final Animation<double> animation;

  /// Called when the user taps the back button to exit zen mode.
  final VoidCallback onExit;

  /// Called when the user taps the fullscreen-exit toggle.
  final VoidCallback onToggle;

  /// Whether focus mode (dim non-current lines) is active.
  final bool isFocusMode;

  /// Whether typewriter scrolling is active.
  final bool isTypewriterScroll;

  /// Called when the user taps the focus mode toggle.
  final VoidCallback onToggleFocusMode;

  /// Called when the user taps the typewriter scroll toggle.
  final VoidCallback onToggleTypewriterScroll;

  const ZenModeChrome({
    super.key,
    required this.animation,
    required this.onExit,
    required this.onToggle,
    required this.isFocusMode,
    required this.isTypewriterScroll,
    required this.onToggleFocusMode,
    required this.onToggleTypewriterScroll,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final iconColor = colorScheme.onSurface.withValues(alpha: 0.5);

    return FadeTransition(
      opacity: animation,
      child: Row(
        children: [
          // Back button to exit zen mode.
          IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: iconColor,
              size: 20,
            ),
            tooltip: l10n.exitZenMode,
            onPressed: onExit,
          ),
          // Focus mode toggle.
          IconButton(
            icon: Icon(
              isFocusMode ? Icons.highlight : Icons.highlight_outlined,
              color: isFocusMode ? colorScheme.primary : iconColor,
              size: 18,
            ),
            tooltip: l10n.focusMode,
            onPressed: onToggleFocusMode,
          ),
          // Typewriter scroll toggle.
          IconButton(
            icon: Icon(
              isTypewriterScroll
                  ? Icons.vertical_align_center
                  : Icons.vertical_align_top_outlined,
              color: isTypewriterScroll ? colorScheme.primary : iconColor,
              size: 18,
            ),
            tooltip: l10n.typewriterScroll,
            onPressed: onToggleTypewriterScroll,
          ),
          const Spacer(),
          // Toggle button to exit zen mode.
          IconButton(
            icon: Icon(
              Icons.fullscreen_exit,
              color: iconColor,
              size: 20,
            ),
            tooltip: l10n.exitZenMode,
            onPressed: onToggle,
          ),
        ],
      ),
    );
  }
}
