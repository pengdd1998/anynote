import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/alpha_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart';

/// Screen showing all soft-deleted notes with restore and permanent delete.
///
/// Each note can be swiped right to restore or left to permanently delete.
/// Includes an "Empty Trash" action in the AppBar with a confirmation dialog.
class TrashScreen extends ConsumerStatefulWidget {
  const TrashScreen({super.key});

  @override
  ConsumerState<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends ConsumerState<TrashScreen> {
  @override
  Widget build(BuildContext context) {
    final db = ref.read(databaseProvider);
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final cardRadius = BorderRadius.circular(AppTheme.radiusMedium);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.trash),
        actions: [
          StreamBuilder<List<Note>>(
            stream: _watchDeletedNotes(db),
            builder: (context, snapshot) {
              final notes = snapshot.data ?? [];
              if (notes.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.delete_forever),
                tooltip: l10n.emptyTrash,
                onPressed: () => _showEmptyTrashConfirm(context, db, notes),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Note>>(
        stream: _watchDeletedNotes(db),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: colorScheme.error),
                  const SizedBox(height: 16),
                  Text(l10n.failedToLoadTrash),
                  const SizedBox(height: 16),
                  FilledButton.tonal(
                    onPressed: () => setState(() {}),
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final notes = snapshot.data ?? [];

          if (notes.isEmpty) {
            return EmptyState(
              icon: Icons.delete_outline,
              title: l10n.trashEmpty,
              subtitle: l10n.trashEmptyDesc,
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 6),
            itemCount: notes.length,
            itemBuilder: (context, index) {
              final note = notes[index];
              final title = note.plainTitle ?? l10n.untitled;
              final preview =
                  note.plainContent != null && note.plainContent!.length > 100
                      ? '${note.plainContent!.substring(0, 100)}...'
                      : note.plainContent ?? '';

              return Semantics(
                label: l10n.noteSemantics(title),
                child: Dismissible(
                  key: ValueKey(note.id),
                  confirmDismiss: (direction) async {
                    if (direction == DismissDirection.startToEnd) {
                      // Restore
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await db.notesDao.restoreNote(note.id);
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(content: Text(l10n.restore)),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                                content: Text(
                                    l10n.failedToRestoreError(e.toString()))),
                          );
                        }
                      }
                      return false;
                    }
                    // Permanent delete -- confirm
                    return await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(l10n.permanentlyDelete),
                        content: Text(
                          l10n.permanentlyDeleteNoteConfirm(
                            note.plainTitle ?? l10n.untitled,
                          ),
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
                      try {
                        db.notesDao.permanentlyDeleteNote(note.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.permanentlyDelete)),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                Text(l10n.failedToDeleteError(e.toString())),
                          ),
                        );
                      }
                    }
                  },
                  background: Container(
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withAlpha(AppAlpha.medium),
                      borderRadius: cardRadius,
                    ),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 24),
                    margin:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.restore, color: colorScheme.primary),
                        const SizedBox(height: 2),
                        Text(
                          l10n.restore,
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  secondaryBackground: Container(
                    decoration: BoxDecoration(
                      color: colorScheme.error.withAlpha(AppAlpha.medium),
                      borderRadius: cardRadius,
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    margin:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete_forever, color: colorScheme.error),
                        const SizedBox(height: 2),
                        Text(
                          l10n.permanentlyDelete,
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                  child: Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: InkWell(
                      borderRadius: cardRadius,
                      onTap: () => _showNoteActions(context, note, db),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            if (preview.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                preview,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: colorScheme.onSurface
                                          .withAlpha(AppAlpha.nearOpaque),
                                    ),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Text(
                              note.deletedAt != null
                                  ? l10n.deletedOn(_formatDate(note.deletedAt!))
                                  : '',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: colorScheme.onSurface
                                        .withAlpha(AppAlpha.prominent),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Watch deleted notes reactively via a periodic refresh approach.
  /// Uses getDeletedNotes() wrapped in a StreamBuilder-compatible way.
  Stream<List<Note>> _watchDeletedNotes(AppDatabase db) {
    // Use a StreamController that refreshes on changes.
    // Since Drift's select-only queries can be watched, we use
    // a simple approach: watch via a periodic trigger based on
    // the notes table change.
    final controller = StreamController<List<Note>>.broadcast();

    // Initial load.
    db.notesDao.getDeletedNotes().then((notes) {
      if (!controller.isClosed) controller.add(notes);
    });

    // Watch for any changes in the notes table to refresh the list.
    final sub = db.notesDao.watchAllNotes().listen((_) {
      db.notesDao.getDeletedNotes().then((notes) {
        if (!controller.isClosed) controller.add(notes);
      });
    });

    controller.onCancel = () {
      sub.cancel();
      controller.close();
    };

    return controller.stream;
  }

  /// Show bottom sheet with restore / permanent delete actions for a note.
  void _showNoteActions(
    BuildContext context,
    Note note,
    AppDatabase db,
  ) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.restore),
              title: Text(l10n.restore),
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await db.notesDao.restoreNote(note.id);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(content: Text(l10n.restore)),
                    );
                  }
                } catch (e) {
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          l10n.failedToRestoreError(e.toString()),
                        ),
                      ),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete_forever,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                l10n.permanentlyDelete,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.of(ctx).pop();
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dialogCtx) => AlertDialog(
                    title: Text(l10n.permanentlyDelete),
                    content: Text(
                      l10n.permanentlyDeleteNoteConfirm(
                        note.plainTitle ?? l10n.untitled,
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogCtx).pop(false),
                        child: Text(l10n.cancel),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(dialogCtx).pop(true),
                        child: Text(l10n.delete),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  try {
                    await db.notesDao.permanentlyDeleteNote(note.id);
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(content: Text(l10n.permanentlyDelete)),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            l10n.failedToDeleteError(e.toString()),
                          ),
                        ),
                      );
                    }
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Show confirmation dialog for emptying the entire trash.
  void _showEmptyTrashConfirm(
    BuildContext context,
    AppDatabase db,
    List<Note> notes,
  ) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.emptyTrash),
        content: Text(l10n.emptyTrashConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.of(ctx).pop();
              await db.notesDao.emptyTrash();
              if (mounted) {
                messenger.showSnackBar(
                  SnackBar(content: Text(l10n.emptyTrash)),
                );
              }
            },
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
  }
}
