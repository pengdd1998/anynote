import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// Save status enumeration for the editor.
enum SaveStatus {
  /// Content is actively being saved.
  saving,

  /// Content has unsaved changes.
  dirty,

  /// Content is saved and up-to-date.
  saved,
}

/// A collapsible find-and-replace bar for the editor.
///
/// Shows a search input with previous/next navigation and match count,
/// plus an optional replace input with replace/replace-all buttons.
/// Intended to be placed above the editor area.
///
/// Usage:
/// ```dart
/// FindReplaceBar(
///   isVisible: _showFindReplace,
///   searchTextController: _findController,
///   replaceTextController: _replaceController,
///   matchIndex: _currentMatchIndex,
///   matchCount: _totalMatches,
///   onSearchChanged: _updateSearch,
///   onPrevious: _goToPreviousMatch,
///   onNext: _goToNextMatch,
///   onReplace: _replaceCurrentMatch,
///   onReplaceAll: _replaceAllMatches,
///   onClose: () => setState(() => _showFindReplace = false),
/// )
/// ```
class FindReplaceBar extends StatefulWidget {
  /// Whether the bar is visible.
  final bool isVisible;

  /// Controller for the search/find text field.
  final TextEditingController searchTextController;

  /// Controller for the replace text field.
  final TextEditingController replaceTextController;

  /// The index of the currently highlighted match (0-based).
  /// -1 indicates no active match.
  final int matchIndex;

  /// The total number of matches found.
  final int matchCount;

  /// Called when the search text changes.
  final ValueChanged<String> onSearchChanged;

  /// Called when the user taps the previous-match button.
  final VoidCallback onPrevious;

  /// Called when the user taps the next-match button.
  final VoidCallback onNext;

  /// Called when the user taps the replace button.
  final VoidCallback onReplace;

  /// Called when the user taps the replace-all button.
  final VoidCallback onReplaceAll;

  /// Called when the user taps the close button.
  final VoidCallback onClose;

  const FindReplaceBar({
    super.key,
    required this.isVisible,
    required this.searchTextController,
    required this.replaceTextController,
    required this.matchIndex,
    required this.matchCount,
    required this.onSearchChanged,
    required this.onPrevious,
    required this.onNext,
    required this.onReplace,
    required this.onReplaceAll,
    required this.onClose,
  });

  @override
  State<FindReplaceBar> createState() => _FindReplaceBarState();
}

class _FindReplaceBarState extends State<FindReplaceBar> {
  bool _showReplace = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // --- Find row ---
          Row(
            children: [
              Expanded(
                child: _buildSearchField(
                  controller: widget.searchTextController,
                  hint: l10n.findInNote,
                  onChanged: widget.onSearchChanged,
                ),
              ),
              const SizedBox(width: 4),
              _buildMatchCountLabel(l10n),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_up, size: 20),
                tooltip: l10n.findPrevious,
                onPressed: widget.onPrevious,
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                tooltip: l10n.findNext,
                onPressed: widget.onNext,
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                icon: Icon(
                  _showReplace ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                ),
                tooltip: _showReplace ? 'Hide replace' : 'Show replace',
                onPressed: () => setState(() => _showReplace = !_showReplace),
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: l10n.closeFindBar,
                onPressed: widget.onClose,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          // --- Replace row (collapsible) ---
          if (_showReplace)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Expanded(
                    child: _buildSearchField(
                      controller: widget.replaceTextController,
                      hint: l10n.replaceWith,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.find_replace, size: 18),
                    tooltip: l10n.replaceMatch,
                    onPressed: widget.onReplace,
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    icon: const Icon(Icons.find_replace_outlined, size: 18),
                    tooltip: l10n.replaceAllMatches,
                    onPressed: widget.onReplaceAll,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Builds a compact text field used for both find and replace inputs.
  Widget _buildSearchField({
    required TextEditingController controller,
    required String hint,
    ValueChanged<String>? onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 32,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: colorScheme.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: colorScheme.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  /// Builds the match count label (e.g., "3/15" or "No matches").
  Widget _buildMatchCountLabel(AppLocalizations l10n) {
    final String text;
    if (widget.matchCount == 0) {
      text = l10n.noMatches;
    } else {
      text = l10n.matchCount(widget.matchIndex + 1, widget.matchCount);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// Helper class that performs find/replace operations on editor content.
///
/// Works with both plain text (via [TextEditingController]) and rich text
/// (via [QuillController] by searching in the plain text representation).
/// This is a pure logic class with no UI.
class FindReplaceController {
  /// The text content to search within.
  String content;

  /// Current search query.
  String searchQuery = '';

  /// Index of the currently highlighted match (-1 if none).
  int currentMatchIndex = -1;

  /// All match offsets within the content.
  List<_TextMatch> _matches = [];

  FindReplaceController({this.content = ''});

  /// Updates the content and re-runs the search if a query is active.
  void updateContent(String newContent) {
    content = newContent;
    if (searchQuery.isNotEmpty) {
      _findMatches();
    }
  }

  /// Sets a new search query and finds all matches.
  void setSearchQuery(String query) {
    searchQuery = query;
    currentMatchIndex = -1;
    _matches = [];
    if (query.isNotEmpty) {
      _findMatches();
      if (_matches.isNotEmpty) {
        currentMatchIndex = 0;
      }
    }
  }

  /// Returns the total number of matches.
  int get matchCount => _matches.length;

  /// Advances to the next match and returns its offset range, or null.
  _TextMatch? nextMatch() {
    if (_matches.isEmpty) return null;
    currentMatchIndex = (currentMatchIndex + 1) % _matches.length;
    return _matches[currentMatchIndex];
  }

  /// Goes to the previous match and returns its offset range, or null.
  _TextMatch? previousMatch() {
    if (_matches.isEmpty) return null;
    currentMatchIndex =
        (currentMatchIndex - 1 + _matches.length) % _matches.length;
    return _matches[currentMatchIndex];
  }

  /// Returns the current match, or null.
  _TextMatch? currentMatch() {
    if (_matches.isEmpty || currentMatchIndex < 0) return null;
    return _matches[currentMatchIndex];
  }

  /// Replaces the current match with [replacement] and returns the updated
  /// content string. Returns null if there is no current match.
  String? replaceCurrent(String replacement) {
    if (currentMatchIndex < 0 || currentMatchIndex >= _matches.length) {
      return null;
    }
    final match = _matches[currentMatchIndex];
    final newContent = content.replaceRange(
      match.start,
      match.end,
      replacement,
    );
    content = newContent;
    // Re-run search after replacement.
    _findMatches();
    // Clamp index after matches changed.
    if (_matches.isEmpty) {
      currentMatchIndex = -1;
    } else if (currentMatchIndex >= _matches.length) {
      currentMatchIndex = _matches.length - 1;
    }
    return content;
  }

  /// Replaces all matches with [replacement] and returns the updated content.
  /// Returns null if there are no matches.
  String? replaceAll(String replacement) {
    if (_matches.isEmpty) return null;
    // Replace from the end to keep offsets valid.
    for (var i = _matches.length - 1; i >= 0; i--) {
      final match = _matches[i];
      content = content.replaceRange(match.start, match.end, replacement);
    }
    final _ = _matches.length;
    _matches = [];
    currentMatchIndex = -1;
    // Preserve search query so caller can see results cleared.
    if (searchQuery.isNotEmpty) {
      _findMatches();
      if (_matches.isNotEmpty) {
        currentMatchIndex = 0;
      }
    }
    return content;
  }

  /// Returns all match start/end offsets.
  List<TextRange> get matchRanges =>
      _matches.map((m) => TextRange(start: m.start, end: m.end)).toList();

  void _findMatches() {
    _matches = [];
    if (searchQuery.isEmpty || content.isEmpty) return;

    // Case-insensitive search.
    final queryLower = searchQuery.toLowerCase();
    final contentLower = content.toLowerCase();
    var start = 0;
    while (start < contentLower.length) {
      final index = contentLower.indexOf(queryLower, start);
      if (index == -1) break;
      _matches.add(_TextMatch(start: index, end: index + searchQuery.length));
      start = index + 1;
    }
  }
}

/// Internal representation of a text match with start/end offsets.
class _TextMatch {
  final int start;
  final int end;

  const _TextMatch({required this.start, required this.end});
}
