import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/error/error.dart' show ErrorDisplay;
import '../../../core/theme/alpha_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_snackbar.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.trash),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
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
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.lightErrorBg,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Icon(
                      Icons.error_outline,
                      size: 28,
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    l10n.failedToLoadTrash,
                    style: AppTextStyles.body.copyWith(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.tonal(
                    onPressed: () => setState(() {}),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                    ),
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
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.s4,
              AppSpacing.md,
              96,
            ),
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
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s8),
                  child: Dismissible(
                    key: ValueKey(note.id),
                    confirmDismiss: (direction) async {
                      if (direction == DismissDirection.startToEnd) {
                        // Restore
                        try {
                          await db.notesDao.restoreNote(note.id);
                          if (context.mounted) {
                            AppSnackBar.info(context, message: l10n.restore);
                          }
                        } catch (e) {
                          if (context.mounted) {
                            AppSnackBar.error(
                              context,
                              message: l10n.failedToRestoreError(ErrorDisplay.displayMessage(e, l10n)),
                            );
                          }
                        }
                        return false;
                      }
                      // Permanent delete -- confirm
                      return await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                          ),
                          title: Text(l10n.permanentlyDelete),
                          content: Text(
                            l10n.permanentlyDeleteNoteConfirm(
                              note.plainTitle ?? l10n.untitled,
                            ),
                            style: AppTextStyles.body,
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: Text(l10n.cancel),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: Text(
                                l10n.delete,
                                style: const TextStyle(color: AppColors.error),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    onDismissed: (direction) {
                      if (direction == DismissDirection.endToStart) {
                        try {
                          db.notesDao.permanentlyDeleteNote(note.id);
                          AppSnackBar.info(
                            context,
                            message: l10n.permanentlyDelete,
                          );
                        } catch (e) {
                          AppSnackBar.error(
                            context,
                            message: l10n.failedToDeleteError(ErrorDisplay.displayMessage(e, l10n)),
                          );
                        }
                      }
                    },
                    background: Container(
                      decoration: BoxDecoration(
                        color: AppColors.success.withAlpha(AppAlpha.medium),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: AppSpacing.lg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.restore, color: AppColors.success),
                          const SizedBox(height: AppSpacing.s2),
                          Text(
                            l10n.restore,
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 11,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                    secondaryBackground: Container(
                      decoration: BoxDecoration(
                        color: AppColors.error.withAlpha(AppAlpha.medium),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: AppSpacing.lg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.delete_forever, color: AppColors.error),
                          const SizedBox(height: AppSpacing.s2),
                          Text(
                            l10n.permanentlyDelete,
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 11,
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                    child: GestureDetector(
                      onTap: () => _showNoteActions(context, note, db),
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkCardBg
                              : AppColors.lightCardBg,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          boxShadow: AppShadows.smOf(Theme.of(context).brightness),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  margin: const EdgeInsets.only(
                                    right: AppSpacing.s12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.error.withAlpha(12),
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.xs,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.delete_outline,
                                    size: 14,
                                    color: AppColors.error.withAlpha(140),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.body.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (preview.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.s8),
                              Text(
                                preview,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.caption.copyWith(
                                  color: isDark
                                      ? AppColors.darkTextTertiary
                                      : AppColors.lightTextTertiary,
                                ),
                              ),
                            ],
                            const SizedBox(height: AppSpacing.s8),
                            Text(
                              note.deletedAt != null
                                  ? l10n.deletedOn(_formatDate(note.deletedAt!))
                                  : '',
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.darkTextTertiary
                                    : AppColors.lightTextTertiary,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.topXl,
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.s8, bottom: AppSpacing.s4),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: (isDark
                          ? AppColors.darkTextTertiary
                          : AppColors.lightTextTertiary)
                      .withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            ListTile(
              leading: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.success.withAlpha(15),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: const Icon(Icons.restore, size: 18, color: AppColors.success),
              ),
              title: Text(l10n.restore, style: AppTextStyles.body),
              onTap: () async {
                try {
                  await db.notesDao.restoreNote(note.id);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  if (context.mounted) {
                    AppSnackBar.info(context, message: l10n.restore);
                  }
                } catch (e) {
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  if (context.mounted) {
                    AppSnackBar.error(
                      context,
                      message: l10n.failedToRestoreError(ErrorDisplay.displayMessage(e, l10n)),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.error.withAlpha(15),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: const Icon(
                  Icons.delete_forever,
                  size: 18,
                  color: AppColors.error,
                ),
              ),
              title: Text(
                l10n.permanentlyDelete,
                style: const TextStyle(color: AppColors.error),
              ),
              onTap: () async {
                Navigator.of(ctx).pop();
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dialogCtx) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    title: Text(l10n.permanentlyDelete),
                    content: Text(
                      l10n.permanentlyDeleteNoteConfirm(
                        note.plainTitle ?? l10n.untitled,
                      ),
                      style: AppTextStyles.body,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogCtx).pop(false),
                        child: Text(l10n.cancel),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(dialogCtx).pop(true),
                        child: Text(
                          l10n.delete,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  try {
                    await db.notesDao.permanentlyDeleteNote(note.id);
                    if (context.mounted) {
                      AppSnackBar.info(
                        context,
                        message: l10n.permanentlyDelete,
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      AppSnackBar.error(
                        context,
                        message: l10n.failedToDeleteError(ErrorDisplay.displayMessage(e, l10n)),
                      );
                    }
                  }
                }
              },
            ),
            const SizedBox(height: AppSpacing.s8),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text(l10n.emptyTrash),
        content: Text(
          l10n.emptyTrashConfirm,
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await db.notesDao.emptyTrash();
              if (context.mounted) {
                AppSnackBar.info(context, message: l10n.emptyTrash);
              }
            },
            child: Text(
              l10n.delete,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
  }
}
