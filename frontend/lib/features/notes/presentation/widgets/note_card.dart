import 'package:flutter/material.dart';

import '../../../../core/accessibility/a11y_utils.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/theme/alpha_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/sync_status_badge.dart';
import 'tag_chips_row.dart';

/// Layout variant for [NoteCard].
enum NoteCardLayout {
  list,
  grid,
}

/// Card widget for displaying a note in list or grid layout.
///
/// Extracted from `NotesListScreen._buildListCard` and
/// `_buildGridCard`. Layout-specific styling is controlled via
/// [layout]. All user interactions are forwarded to the parent
/// via callback parameters.
class NoteCard extends StatelessWidget {
  final Note note;
  final String time;
  final List<Tag> tags;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final String untitled;
  final NoteCardLayout layout;

  const NoteCard({
    super.key,
    required this.note,
    required this.time,
    required this.tags,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    required this.untitled,
    this.layout = NoteCardLayout.list,
  });

  bool get _isGrid => layout == NoteCardLayout.grid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final title = note.plainTitle ?? untitled;
    final previewLen = _isGrid ? 80 : 100;
    final preview =
        note.plainContent != null && note.plainContent!.length > previewLen
            ? '${note.plainContent!.substring(0, previewLen)}...'
            : note.plainContent ?? '';

    final card = Card(
      color: isSelected
          ? colorScheme.primaryContainer.withAlpha(AppAlpha.bold)
          : null,
      margin: _isGrid ? const EdgeInsets.all(4) : EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        splashColor: colorScheme.primary.withAlpha(AppAlpha.light),
        highlightColor: colorScheme.primary.withAlpha(AppAlpha.subtle),
        child: Padding(
          padding: _isGrid
              ? const EdgeInsets.all(12)
              : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTitleRow(theme, colorScheme),
              SizedBox(height: _isGrid ? 8 : 6),
              _buildPreview(theme, colorScheme, preview),
              if (tags.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: _isGrid ? 4 : 6),
                  child: TagChipsRow(tags: tags),
                ),
              SizedBox(height: _isGrid ? 4 : 6),
              _buildDate(theme, colorScheme),
            ],
          ),
        ),
      ),
    );

    return Semantics(
      label: A11yUtils.noteCardLabel(
        title: title,
        timeDescription: time,
        isPinned: note.isPinned,
        isSynced: note.isSynced,
      ),
      button: true,
      child: _isGrid
          ? card
          : Material(
              color: Colors.transparent,
              child: card,
            ),
    );
  }

  Widget _buildTitleRow(ThemeData theme, ColorScheme colorScheme) {
    final title = note.plainTitle ?? untitled;
    return Row(
      children: [
        if (note.isPinned)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Icon(
              Icons.push_pin,
              size: _isGrid ? 14 : 16,
              color: colorScheme.primary,
            ),
          ),
        Expanded(
          child: Text(
            title,
            maxLines: _isGrid ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: (_isGrid
                    ? theme.textTheme.titleSmall
                    : theme.textTheme.titleLarge)
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        SyncStatusBadge(isSynced: note.isSynced),
      ],
    );
  }

  Widget _buildPreview(
    ThemeData theme,
    ColorScheme colorScheme,
    String preview,
  ) {
    final text = Text(
      preview,
      maxLines: _isGrid ? 4 : 2,
      overflow: TextOverflow.ellipsis,
      style: (_isGrid ? theme.textTheme.bodySmall : theme.textTheme.bodyMedium)
          ?.copyWith(
        color: colorScheme.onSurface.withAlpha(AppAlpha.nearOpaque),
      ),
    );
    // In grid layout, preview expands to fill remaining vertical space.
    return _isGrid ? Expanded(child: text) : text;
  }

  Widget _buildDate(ThemeData theme, ColorScheme colorScheme) {
    return Text(
      time,
      style: (_isGrid ? theme.textTheme.labelSmall : theme.textTheme.bodySmall)
          ?.copyWith(
        color: colorScheme.onSurface.withAlpha(AppAlpha.prominent),
      ),
    );
  }
}
