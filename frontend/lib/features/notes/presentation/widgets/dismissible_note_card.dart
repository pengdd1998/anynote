import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../l10n/app_localizations.dart';
import 'note_card.dart';

/// A note card wrapped in a Dismissible for swipe actions.
///
/// Swipe right (start-to-end) toggles pin with warm primary background.
/// Swipe left (end-to-start) deletes with warm error background.
/// Both backgrounds use AppRadius and design token styling.
class DismissibleNoteCard extends StatelessWidget {
  final Note note;
  final AppDatabase db;
  final bool isGrid;
  final String time;
  final List<Tag> tags;
  final bool isSelected;
  final bool disableSwipe;
  final VoidCallback onTap;
  final ValueChanged<Offset>? onLongPress;
  final VoidCallback? onDeleted;
  final String untitled;
  final VoidCallback? onStatusTap;
  final VoidCallback? onPriorityTap;
  final bool isLocked;
  final List<NoteProperty>? properties;
  final Widget? trailing;
  final int listIndex;
  final String? previewImagePath;

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
    this.onStatusTap,
    this.onPriorityTap,
    this.isLocked = false,
    this.properties,
    this.trailing,
    this.listIndex = 0,
    this.previewImagePath,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final cardRadius = BorderRadius.circular(isGrid ? AppRadius.md : AppRadius.sm);

    final card = NoteCard(
      note: note,
      time: time,
      tags: tags,
      isSelected: isSelected,
      onTap: onTap,
      onLongPress: onLongPress,
      untitled: untitled,
      layout: isGrid ? NoteCardLayout.grid : NoteCardLayout.list,
      onStatusTap: onStatusTap,
      onPriorityTap: onPriorityTap,
      isLocked: isLocked,
      properties: properties,
      listIndex: listIndex,
      previewImagePath: previewImagePath ?? note.firstImagePath,
    );

    if (disableSwipe) {
      if (trailing != null) {
        return Row(
          children: [
            Expanded(child: card),
            trailing!,
          ],
        );
      }
      return card;
    }

    return Semantics(
      label: l10n.noteSemantics(note.plainTitle ?? untitled),
      child: Dismissible(
        key: ValueKey(note.id),
        direction: DismissDirection.horizontal,
        dismissThresholds: const {
          DismissDirection.startToEnd: 0.35,
          DismissDirection.endToStart: 0.4,
        },
        // Right swipe: pin/unpin with warm primary color
        background: Container(
          decoration: BoxDecoration(
            color: colorScheme.primary.withAlpha(40),
            borderRadius: cardRadius,
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: AppSpacing.lg),
          margin: EdgeInsets.symmetric(
            horizontal: isGrid ? AppSpacing.s4 : 0,
            vertical: AppSpacing.s4,
          ),
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
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 11,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Left swipe: delete with warm error color
        secondaryBackground: Container(
          decoration: BoxDecoration(
            color: colorScheme.error.withAlpha(40),
            borderRadius: cardRadius,
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: AppSpacing.lg),
          margin: EdgeInsets.symmetric(
            horizontal: isGrid ? AppSpacing.s4 : 0,
            vertical: AppSpacing.s4,
          ),
          child: Semantics(
            label: l10n.deleteNote,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.delete_outline, color: colorScheme.error),
                const SizedBox(height: 2),
                Text(
                  l10n.deleteNote,
                  style: AppTextStyles.caption.copyWith(
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
            await db.notesDao.togglePin(note.id);
            return false;
          }
          return await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
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
            HapticFeedback.mediumImpact();
            db.notesDao.softDeleteNote(note.id);
            AppSnackBar.info(
              context,
              message: l10n.noteDeleted,
              actionLabel: l10n.undo,
              onAction: () async {
                await (db.update(db.notes)..where((n) => n.id.equals(note.id)))
                    .write(
                  const NotesCompanion(
                    deletedAt: Value(null),
                    isSynced: Value(false),
                  ),
                );
              },
            );
            onDeleted?.call();
          }
        },
        child: card,
      ),
    );
  }
}
