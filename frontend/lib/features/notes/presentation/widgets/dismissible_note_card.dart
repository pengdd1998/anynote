import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/theme/alpha_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import 'note_card.dart';

/// A note card wrapped in a Dismissible for swipe actions.
///
/// Swipe right (start-to-end) toggles pin with warm primary background.
/// Swipe left (end-to-start) deletes with warm error background.
/// Both backgrounds have rounded corners matching the card shape.
///
/// Extracted from `NotesListScreen._buildDismissibleNoteCard`.
class DismissibleNoteCard extends StatelessWidget {
  /// The note to display.
  final Note note;

  /// Database instance for pin toggle and delete operations.
  final AppDatabase db;

  /// Whether to render in grid layout (true) or list layout (false).
  final bool isGrid;

  /// Human-readable time description (e.g. "2 hours ago").
  final String time;

  /// Tags associated with this note.
  final List<Tag> tags;

  /// Whether this card is currently selected.
  final bool isSelected;

  /// Whether swipe gestures are disabled (e.g., during batch selection).
  final bool disableSwipe;

  /// Called when the user taps the card.
  final VoidCallback onTap;

  /// Called when the user long-presses the card.
  final VoidCallback onLongPress;

  /// Called after a delete is confirmed (for parent state cleanup).
  final VoidCallback? onDeleted;

  /// Localized "untitled" fallback string.
  final String untitled;

  const DismissibleNoteCard({
    super.key,
    required this.note,
    required this.db,
    required this.isGrid,
    required this.time,
    required this.tags,
    required this.isSelected,
    this.disableSwipe = false,
    required this.onTap,
    required this.onLongPress,
    required this.onDeleted,
    required this.untitled,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final cardRadius = BorderRadius.circular(AppTheme.radiusMedium);

    final card = NoteCard(
      note: note,
      time: time,
      tags: tags,
      isSelected: isSelected,
      onTap: onTap,
      onLongPress: onLongPress,
      untitled: untitled,
      layout: isGrid ? NoteCardLayout.grid : NoteCardLayout.list,
    );

    // When swipe is disabled (e.g., selection mode), just return the card.
    if (disableSwipe) {
      return card;
    }

    return Dismissible(
      key: ValueKey(note.id),
      direction: DismissDirection.horizontal,
      dismissThresholds: const {
        DismissDirection.startToEnd: 0.35,
        DismissDirection.endToStart: 0.4,
      },
      // Right swipe: pin/unpin with warm primary color.
      background: Container(
        decoration: BoxDecoration(
          color: colorScheme.primary.withAlpha(AppAlpha.medium),
          borderRadius: cardRadius,
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Semantics(
          label: note.isPinned ? l10n.unpinNote : l10n.pinNote,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                note.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 2),
              Text(
                note.isPinned ? l10n.unpinNote : l10n.pinNote,
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
      // Left swipe: delete with warm error color.
      secondaryBackground: Container(
        decoration: BoxDecoration(
          color: colorScheme.error.withAlpha(AppAlpha.medium),
          borderRadius: cardRadius,
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Semantics(
          label: l10n.deleteNote,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.delete_outline, color: colorScheme.error),
              const SizedBox(height: 2),
              Text(
                l10n.deleteNote,
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.error,
                ),
              ),
            ],
          ),
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Pin/unpin does not dismiss; just toggle and return false.
          await db.notesDao.togglePin(note.id);
          return false;
        }
        // Delete: confirm via dialog.
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.deleteNoteQuestion),
            content: Text(
              l10n.deleteNoteConfirm(note.plainTitle ?? l10n.untitled),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(l10n.delete),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          db.notesDao.softDeleteNote(note.id);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.noteDeleted),
              action: SnackBarAction(
                label: l10n.undo,
                onPressed: () async {
                  await (db.update(db.notes)
                        ..where((n) => n.id.equals(note.id)))
                      .write(
                    const NotesCompanion(
                      deletedAt: Value(null),
                      isSynced: Value(false),
                    ),
                  );
                },
              ),
            ),
          );
          onDeleted?.call();
        }
      },
      child: card,
    );
  }
}
