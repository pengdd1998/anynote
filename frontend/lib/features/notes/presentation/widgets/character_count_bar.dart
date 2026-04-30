import 'package:flutter/material.dart';

import '../../../../core/constants/app_durations.dart';
import '../../../../core/accessibility/a11y_utils.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';

/// Animated word/character count bar displayed at the bottom of the editor.
///
/// Shows word count and character count with a subtle scale+opacity transition
/// when counts change. Includes a zen mode toggle button when not in zen mode.
///
/// Extracted from `NoteEditorScreen._buildCountBar`.
class CharacterCountBar extends StatelessWidget {
  /// Current word count.
  final int wordCount;

  /// Current character count.
  final int charCount;

  /// Whether the editor is currently in zen mode.
  final bool isZenMode;

  /// Called when the user taps the zen mode toggle button.
  final VoidCallback onToggleZenMode;

  const CharacterCountBar({
    super.key,
    required this.wordCount,
    required this.charCount,
    required this.isZenMode,
    required this.onToggleZenMode,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Use warm secondary color for the caption text.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final captionColor = isDark
        ? AppColors
            .darkTextSecondary // warm medium grey (WCAG AA on dark surface)
        : AppColors.lightTextSecondary; // warm brown-grey

    return SafeArea(
      top: false,
      bottom: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Zen mode toggle button (visible when not in zen mode).
            if (!isZenMode)
              A11yUtils.ensureTouchTarget(
                child: Semantics(
                  button: true,
                  label: l10n.enterZenMode,
                  child: IconButton(
                    icon: Icon(
                      Icons.fullscreen,
                      size: 18,
                      color: captionColor,
                    ),
                    tooltip: l10n.enterZenMode,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 24,
                    ),
                    onPressed: onToggleZenMode,
                  ),
                ),
              ),
            const Spacer(),
            // Animated word count.
            _AnimatedCountChip(
              text: l10n.wordCount(wordCount),
              color: captionColor,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                '|',
                style: TextStyle(
                  color: captionColor.withValues(alpha: 0.4),
                  fontSize: 12,
                ),
              ),
            ),
            // Animated character count.
            _AnimatedCountChip(
              text: l10n.charCount(charCount),
              color: captionColor,
            ),
          ],
        ),
      ),
    );
  }
}

/// Displays a word or character count string with a subtle scale+opacity
/// animation when the text changes. This gives a gentle pulse effect that
/// draws the eye without being distracting.
class _AnimatedCountChip extends StatelessWidget {
  final String text;
  final Color color;

  const _AnimatedCountChip({
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    // Use AnimatedSwitcher to cross-fade between old and new count text.
    // The transition applies a slight scale-up on the incoming text.
    return AnimatedSwitcher(
      duration: AppDurations.shortAnimation,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (Widget child, Animation<double> animation) {
        // Subtle scale from 0.85 to 1.0 combined with opacity fade.
        final scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: scaleAnimation,
            child: child,
          ),
        );
      },
      child: Text(
        text,
        key: ValueKey(text), // key change triggers animation
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
