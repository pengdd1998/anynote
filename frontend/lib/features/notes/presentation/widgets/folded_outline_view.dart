import 'package:flutter/material.dart';

import '../../../../core/constants/app_durations.dart';
import '../../../../l10n/app_localizations.dart';
import 'section_fold_controller.dart';

/// A structured outline view showing note content organized by headings.
///
/// Each heading section can be expanded or collapsed. This is an alternative
/// view mode to the rich editor, sharing the same underlying content.
/// Tapping a heading can navigate back to the editor at that position.
class FoldedOutlineView extends StatefulWidget {
  /// The plain text content to parse headings from.
  final String content;

  /// Controller managing fold state.
  final SectionFoldController foldController;

  /// Called when the user taps a heading to navigate back to the editor.
  /// Provides the character offset of the heading in the document.
  final void Function(int characterOffset)? onNavigateToHeading;

  const FoldedOutlineView({
    super.key,
    required this.content,
    required this.foldController,
    this.onNavigateToHeading,
  });

  @override
  State<FoldedOutlineView> createState() => _FoldedOutlineViewState();
}

class _FoldedOutlineViewState extends State<FoldedOutlineView> {
  @override
  void initState() {
    super.initState();
    _updateHeadings();
    widget.foldController.addListener(_onFoldChanged);
  }

  @override
  void didUpdateWidget(covariant FoldedOutlineView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content ||
        oldWidget.foldController != widget.foldController) {
      oldWidget.foldController.removeListener(_onFoldChanged);
      widget.foldController.addListener(_onFoldChanged);
      _updateHeadings();
    }
  }

  @override
  void dispose() {
    widget.foldController.removeListener(_onFoldChanged);
    super.dispose();
  }

  void _onFoldChanged() {
    if (mounted) setState(() {});
  }

  void _updateHeadings() {
    final lines = widget.content.split('\n');
    final headingIndices = <int>[];
    for (var i = 0; i < lines.length; i++) {
      if (_isHeadingLine(lines[i])) {
        headingIndices.add(i);
      }
    }
    widget.foldController.updateHeadings(headingIndices);
  }

  /// Parses heading sections from the content.
  List<_HeadingSection> _parseSections() {
    final lines = widget.content.split('\n');
    final headings = <_HeadingSection>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (_isHeadingLine(line)) {
        final level = _headingLevel(line);
        final title = _headingTitle(line);
        // Calculate the character offset for this heading line.
        int offset = 0;
        for (var j = 0; j < i; j++) {
          offset += lines[j].length + 1; // +1 for newline
        }

        // Collect content lines until the next heading or end.
        final contentLines = <String>[];
        for (var j = i + 1; j < lines.length; j++) {
          if (_isHeadingLine(lines[j])) break;
          contentLines.add(lines[j]);
        }

        headings.add(
          _HeadingSection(
            lineIndex: i,
            level: level,
            title: title,
            contentLines: contentLines,
            characterOffset: offset,
          ),
        );
      }
    }

    return headings;
  }

  bool _isHeadingLine(String line) {
    final trimmed = line.trimLeft();
    return trimmed.startsWith('# ') ||
        trimmed.startsWith('## ') ||
        trimmed.startsWith('### ') ||
        trimmed.startsWith('#### ') ||
        trimmed.startsWith('##### ') ||
        trimmed.startsWith('###### ');
  }

  int _headingLevel(String line) {
    final trimmed = line.trimLeft();
    var level = 0;
    while (level < trimmed.length && trimmed[level] == '#') {
      level++;
    }
    return level.clamp(1, 6);
  }

  String _headingTitle(String line) {
    final trimmed = line.trimLeft();
    final spaceIndex = trimmed.indexOf(' ');
    if (spaceIndex < 0) return trimmed;
    return trimmed.substring(spaceIndex + 1).trim();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final sections = _parseSections();

    if (sections.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.outlined_flag,
                size: 48,
                color: colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                'No headings found',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add headings (lines starting with #) to use the fold view.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.outline,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final totalLines = widget.content.split('\n').length;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: sections.length,
      itemBuilder: (context, index) {
        final section = sections[index];
        final isFolded = widget.foldController.isFolded(section.lineIndex);
        final hiddenCount = widget.foldController.foldedLineCountResolved(
          section.lineIndex,
          totalLines,
        );

        return _buildSectionTile(
          context,
          l10n,
          colorScheme,
          section,
          isFolded,
          hiddenCount,
        );
      },
    );
  }

  Widget _buildSectionTile(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme colorScheme,
    _HeadingSection section,
    bool isFolded,
    int hiddenCount,
  ) {
    final indent = (section.level - 1) * 16.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Heading row with fold toggle.
        InkWell(
          onTap: () {
            widget.onNavigateToHeading?.call(section.characterOffset);
          },
          child: Padding(
            padding: EdgeInsets.only(left: indent),
            child: Row(
              children: [
                // Fold chevron.
                IconButton(
                  icon: AnimatedRotation(
                    duration: AppDurations.shortAnimation,
                    turns: isFolded ? -0.25 : 0.0,
                    child: Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  tooltip: l10n.toggleFold,
                  onPressed: () {
                    widget.foldController.toggleFold(section.lineIndex);
                  },
                ),
                // Heading text.
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      widget.onNavigateToHeading?.call(section.characterOffset);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        section.title,
                        style: _headingStyle(
                          context,
                          section.level,
                          colorScheme,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                // Folded line count badge.
                if (isFolded && hiddenCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      l10n.sectionLines(hiddenCount),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.outline,
                          ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        // Section content (visible when not folded).
        if (!isFolded && section.contentLines.isNotEmpty)
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: EdgeInsets.only(left: indent + 48),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                ),
                padding: const EdgeInsets.only(left: 12, top: 4, bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final line in section.contentLines.take(10))
                      if (line.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            line,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  height: 1.4,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    if (section.contentLines.length > 10)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '... ${section.contentLines.length - 10} more lines',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colorScheme.outline,
                                  ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            crossFadeState: CrossFadeState.showSecond,
            duration: AppDurations.shortAnimation,
            sizeCurve: Curves.easeOutCubic,
          ),
      ],
    );
  }

  TextStyle? _headingStyle(
    BuildContext context,
    int level,
    ColorScheme colorScheme,
  ) {
    final base = Theme.of(context).textTheme;
    return switch (level) {
      1 => base.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: colorScheme.onSurface,
        ),
      2 => base.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      3 => base.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      _ => base.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
    };
  }
}

/// Data class representing a heading section parsed from note content.
class _HeadingSection {
  final int lineIndex;
  final int level;
  final String title;
  final List<String> contentLines;
  final int characterOffset;

  const _HeadingSection({
    required this.lineIndex,
    required this.level,
    required this.title,
    required this.contentLines,
    required this.characterOffset,
  });
}
