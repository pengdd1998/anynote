import 'dart:io' if (dart.library.js) 'package:anynote/core/stubs/io_stub.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../../core/accessibility/a11y_utils.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/theme/alpha_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/color_utils.dart';
import '../../../../core/widgets/sync_status_badge.dart';
import '../../../../l10n/app_localizations.dart';
import 'property_badges.dart';
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
  final ValueChanged<Offset>? onLongPress;
  final String untitled;
  final NoteCardLayout layout;
  final VoidCallback? onStatusTap;
  final VoidCallback? onPriorityTap;

  /// Whether the note is locked (read-only). Shows a lock icon on the card.
  final bool isLocked;

  /// Test-only: if true, skips rendering PropertyBadges to avoid timer leaks.
  final bool skipPropertyBadges;

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
    this.onStatusTap,
    this.onPriorityTap,
    this.isLocked = false,
    this.skipPropertyBadges = false,
  });

  bool get _isGrid => layout == NoteCardLayout.grid;

  /// Parsed note color, or null if no color is set.
  Color? get _noteColor {
    final hex = note.color;
    if (hex == null) return null;
    return parseHexColor(hex);
  }

  /// Extract the first image file path from the note content, if any.
  /// Looks for markdown image references like `![image](file://...)`.
  String? get _firstImagePath {
    final content = note.plainContent;
    if (content == null) return null;
    final regex = RegExp(r'!\[.*?\]\(file://([^)]+)\)');
    final match = regex.firstMatch(content);
    return match?.group(1);
  }

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
    final noteColor = _noteColor;

    // When the note has a color, show a left border accent in list layout
    // or a top border accent in grid layout.
    final card = Card(
      color: isSelected
          ? colorScheme.primaryContainer.withAlpha(AppAlpha.bold)
          : null,
      margin: _isGrid ? const EdgeInsets.all(4) : EdgeInsets.zero,
      child: Container(
        // Colored left/top accent border via decoration.
        decoration: noteColor != null
            ? BoxDecoration(
                border: Border(
                  left: _isGrid
                      ? BorderSide.none
                      : BorderSide(color: noteColor, width: 4),
                  top: _isGrid
                      ? BorderSide(color: noteColor, width: 4)
                      : BorderSide.none,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              )
            : null,
        child: GestureDetector(
          onLongPressStart: onLongPress != null
              ? (details) => onLongPress!(details.globalPosition)
              : null,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            splashColor: colorScheme.primary.withAlpha(AppAlpha.light),
            highlightColor: colorScheme.primary.withAlpha(AppAlpha.subtle),
            child: Stack(
              children: [
                Padding(
                  padding: _isGrid
                      ? const EdgeInsets.all(12)
                      : const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12,),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTitleRow(context, theme, colorScheme),
                      // Property badges (status, priority, dates)
                      if (!skipPropertyBadges)
                        PropertyBadges(
                          noteId: note.id,
                          onStatusTap: onStatusTap,
                          onPriorityTap: onPriorityTap,
                        ),
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
                // Checkbox overlay when selected
                if (isSelected)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.check,
                        color: colorScheme.onPrimary,
                        size: _isGrid ? 16 : 20,
                      ),
                    ),
                  ),
              ],
            ),
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

  Widget _buildTitleRow(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final title = note.plainTitle ?? untitled;
    final l10n = AppLocalizations.of(context);
    final noteColor = _noteColor;
    return Row(
      children: [
        if (note.isPinned)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Semantics(
              label: l10n?.pinnedNote,
              child: ExcludeSemantics(
                child: Icon(
                  Icons.push_pin,
                  size: _isGrid ? 14 : 16,
                  color: colorScheme.primary,
                ),
              ),
            ),
          ),
        // Lock icon for locked (read-only) notes.
        if (isLocked)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: ExcludeSemantics(
              child: Icon(
                Icons.lock_outline,
                size: _isGrid ? 12 : 14,
                color: colorScheme.onSurface.withAlpha(120),
              ),
            ),
          ),
        // Color dot indicator next to title.
        if (noteColor != null)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ExcludeSemantics(
              child: Container(
                width: _isGrid ? 10 : 12,
                height: _isGrid ? 10 : 12,
                decoration: BoxDecoration(
                  color: noteColor,
                  shape: BoxShape.circle,
                ),
              ),
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

    if (_isGrid) {
      final imagePath = _firstImagePath;
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imagePath != null && !kIsWeb)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    height: 120,
                    width: double.infinity,
                    child: Image.file(
                      File(imagePath),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            Expanded(child: text),
          ],
        ),
      );
    }
    return text;
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
