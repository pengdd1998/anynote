import 'package:flutter/material.dart';

import '../../../../core/widgets/toc_extractor.dart';
import '../../../../l10n/app_localizations.dart';

/// A draggable bottom sheet that displays the table of contents for a note.
///
/// Shows a hierarchical list of headings extracted from markdown content.
/// Tapping a heading calls [onHeadingSelected] with the corresponding
/// [TocEntry] so the caller can scroll to that position.
class TocSheet extends StatelessWidget {
  /// The parsed TOC entries to display.
  final List<TocEntry> entries;

  /// Callback invoked when the user taps a heading.
  final ValueChanged<TocEntry> onHeadingSelected;

  const TocSheet({
    super.key,
    required this.entries,
    required this.onHeadingSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.4,
      minChildSize: 0.3,
      maxChildSize: 0.7,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Drag handle.
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.4,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              // Header row.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n?.tableOfContents ?? 'Table of Contents',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip:
                          MaterialLocalizations.of(context).closeButtonTooltip,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Content.
              Expanded(
                child: entries.isEmpty
                    ? _buildEmptyState(context, l10n, theme)
                    : _buildTocList(context, scrollController, theme),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Empty state shown when there are no headings in the note.
  Widget _buildEmptyState(
    BuildContext context,
    AppLocalizations? l10n,
    ThemeData theme,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.format_list_bulleted_outlined,
                size: 48,
                color:
                    theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n?.noHeadings ?? 'No headings found',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the scrollable list of TOC entries with indentation.
  Widget _buildTocList(
    BuildContext context,
    ScrollController scrollController,
    ThemeData theme,
  ) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        // Indent based on heading level. Level 1 = 0 indent.
        final indent = (entry.level - 1) * 16.0;

        // Choose font size and weight based on heading level.
        final fontSize = switch (entry.level) {
          1 => 15.0,
          2 => 14.0,
          3 => 13.5,
          _ => 13.0,
        };
        final fontWeight = entry.level <= 2
            ? FontWeight.w600
            : entry.level == 3
                ? FontWeight.w500
                : FontWeight.w400;

        // Leading icon varies by level.
        final leadingIcon = switch (entry.level) {
          1 => Icons.title,
          2 => Icons.text_fields,
          _ => Icons.label_outlined,
        };

        return InkWell(
          onTap: () {
            Navigator.of(context).pop();
            onHeadingSelected(entry);
          },
          child: Padding(
            padding: EdgeInsets.only(left: 16.0 + indent),
            child: ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              leading: Icon(
                leadingIcon,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              title: Text(
                entry.text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: fontWeight,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              trailing: Text(
                'H${entry.level}',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.6,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
