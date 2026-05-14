import 'dart:io' if (dart.library.js) 'package:anynote/core/stubs/io_stub.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

    final card = Container(
      margin: _isGrid
          ? const EdgeInsets.all(4)
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected
            ? colorScheme.primaryContainer.withAlpha(AppAlpha.bold)
            : colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: isSelected
            ? Border.all(color: colorScheme.primary.withAlpha(60), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withAlpha(isSelected ? 18 : 10),
            blurRadius: isSelected ? 8 : 4,
            offset: Offset(0, isSelected ? 2 : 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        clipBehavior: Clip.antiAlias,
        child: GestureDetector(
          onLongPressStart: onLongPress != null
              ? (details) {
                  HapticFeedback.mediumImpact();
                  onLongPress!(details.globalPosition);
                }
              : null,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            splashColor: colorScheme.primary.withAlpha(AppAlpha.light),
            highlightColor: colorScheme.primary.withAlpha(AppAlpha.subtle),
            child: Stack(
              children: [
                // Color accent bar on left (list) or top (grid)
                if (noteColor != null)
                  Positioned(
                    left: _isGrid ? 0 : null,
                    top: _isGrid ? 0 : null,
                    child: Container(
                      width: _isGrid ? double.infinity : 4,
                      height: _isGrid ? 4 : double.infinity,
                      decoration: BoxDecoration(
                        color: noteColor,
                        borderRadius: _isGrid
                            ? const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                              )
                            : const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                bottomLeft: Radius.circular(16),
                              ),
                      ),
                    ),
                  ),
                Padding(
                  padding: _isGrid
                      ? const EdgeInsets.fromLTRB(12, 16, 12, 12)
                      : EdgeInsets.only(
                          left: noteColor != null ? 20 : 16,
                          right: 16,
                          top: 14,
                          bottom: 14,
                        ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTitleRow(context, theme, colorScheme),
                      if (!skipPropertyBadges)
                        PropertyBadges(
                          noteId: note.id,
                          onStatusTap: onStatusTap,
                          onPriorityTap: onPriorityTap,
                        ),
                      SizedBox(height: _isGrid ? 8 : 8),
                      _buildPreview(theme, colorScheme, preview),
                      if (tags.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(top: _isGrid ? 4 : 8),
                          child: TagChipsRow(tags: tags),
                        ),
                      SizedBox(height: _isGrid ? 6 : 10),
                      _buildDate(theme, colorScheme),
                    ],
                  ),
                ),
                if (isSelected)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.check,
                        color: colorScheme.onPrimary,
                        size: _isGrid ? 16 : 18,
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
      child: card,
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
                ?.copyWith(fontWeight: _isGrid ? FontWeight.w600 : FontWeight.w700),
          ),
        ),
        SyncStatusBadge(isSynced: note.isSynced, iconSize: _isGrid ? 16 : 18),
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
        color: colorScheme.onSurface.withAlpha(AppAlpha.prominent),
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.schedule,
          size: _isGrid ? 12 : 13,
          color: colorScheme.onSurfaceVariant.withAlpha(AppAlpha.medium),
        ),
        const SizedBox(width: 4),
        Text(
          time,
          style: (_isGrid
                  ? theme.textTheme.labelSmall
                  : theme.textTheme.bodySmall)
              ?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
