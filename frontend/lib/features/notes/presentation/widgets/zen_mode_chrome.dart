import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// Minimal chrome shown at the top of the screen in zen mode.
///
/// Displays a back arrow (to exit) and a fullscreen-exit icon toggle.
/// The chrome fades in/out based on the provided animation controller.
///
/// Extracted from `NoteEditorScreen._buildZenChrome`.
class ZenModeChrome extends StatelessWidget {
  /// Animation controller driving the chrome fade transition.
  /// Should have value 1.0 when chrome is visible, 0.0 when hidden.
  final Animation<double> animation;

  /// Called when the user taps the back button to exit zen mode.
  final VoidCallback onExit;

  /// Called when the user taps the fullscreen-exit toggle.
  final VoidCallback onToggle;

  const ZenModeChrome({
    super.key,
    required this.animation,
    required this.onExit,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return FadeTransition(
      opacity: animation,
      child: Row(
        children: [
          // Back button to exit zen mode.
          IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: colorScheme.onSurface.withValues(alpha: 0.5),
              size: 20,
            ),
            tooltip: l10n.exitZenMode,
            onPressed: onExit,
          ),
          const Spacer(),
          // Toggle button to exit zen mode.
          IconButton(
            icon: Icon(
              Icons.fullscreen_exit,
              color: colorScheme.onSurface.withValues(alpha: 0.5),
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
