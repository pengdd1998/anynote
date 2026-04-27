import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import 'section_fold_controller.dart';

/// A toolbar bar with fold/unfold controls for the section fold feature.
///
/// Shows "Fold All" and "Unfold All" buttons and displays the count of
/// currently folded sections.
class SectionFoldBar extends StatelessWidget {
  /// The fold controller managing section fold state.
  final SectionFoldController foldController;

  /// Callback when "Fold All" is pressed.
  final VoidCallback? onFoldAll;

  /// Callback when "Unfold All" is pressed.
  final VoidCallback? onUnfoldAll;

  const SectionFoldBar({
    super.key,
    required this.foldController,
    this.onFoldAll,
    this.onUnfoldAll,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: foldController,
      builder: (context, _) {
        final foldedCount = foldController.foldedCount;
        final headingCount = foldController.headingLines.length;

        if (headingCount == 0) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF252220) : const Color(0xFFFFFDFB),
            border: Border(
              bottom: BorderSide(
                color:
                    isDark ? const Color(0xFF332E2B) : const Color(0xFFF0E8DF),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              // Fold All button.
              TextButton.icon(
                onPressed: () {
                  foldController.foldAll();
                  onFoldAll?.call();
                },
                icon: const Icon(Icons.unfold_less, size: 18),
                label: Text(
                  l10n.foldAll,
                  style: const TextStyle(fontSize: 13),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 8),
              // Unfold All button.
              TextButton.icon(
                onPressed: () {
                  foldController.unfoldAll();
                  onUnfoldAll?.call();
                },
                icon: const Icon(Icons.unfold_more, size: 18),
                label: Text(
                  l10n.unfoldAll,
                  style: const TextStyle(fontSize: 13),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const Spacer(),
              // Folded sections count.
              if (foldedCount > 0)
                Text(
                  l10n.foldedSections(foldedCount),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.outline,
                        fontSize: 12,
                      ),
                ),
            ],
          ),
        );
      },
    );
  }
}
