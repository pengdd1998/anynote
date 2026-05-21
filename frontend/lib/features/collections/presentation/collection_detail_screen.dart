import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/crypto/crypto_service.dart';
import '../../../core/database/app_database.dart';
import '../../../core/error/error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state_widget.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart';
import '../../notes/presentation/widgets/note_card.dart';

class CollectionDetailScreen extends ConsumerStatefulWidget {
  final String collectionId;

  const CollectionDetailScreen({super.key, required this.collectionId});

  @override
  ConsumerState<CollectionDetailScreen> createState() =>
      _CollectionDetailScreenState();
}

class _CollectionDetailScreenState
    extends ConsumerState<CollectionDetailScreen> {
  Collection? _collection;
  List<CollectionNote> _collectionNotes = [];
  Map<String, Note> _notesMap = {};

  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final db = ref.read(databaseProvider);

      final collections = await db.collectionsDao.getAllCollections();
      final collection =
          collections.where((c) => c.id == widget.collectionId).firstOrNull;
      if (collection == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _error = 'collectionNotFound';
          });
        }
        return;
      }

      final collectionNotes =
          await db.collectionsDao.getCollectionNotes(widget.collectionId);

      final Map<String, Note> notesMap = {};
      for (final cn in collectionNotes) {
        final note = await db.notesDao.getNoteById(cn.noteId);
        if (note != null && note.deletedAt == null) {
          notesMap[cn.noteId] = note;
        }
      }

      if (mounted) {
        setState(() {
          _collection = collection;
          _collectionNotes = collectionNotes;
          _notesMap = notesMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = ErrorMapper.map(e).toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(_collection?.plainTitle ?? l10n.collectionFallback),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: l10n.renameCollectionTooltip,
            onPressed:
                _collection != null ? () => _showRenameDialog(context) : null,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.deleteCollectionTooltip,
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddNotesSheet,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    final l10n = AppLocalizations.of(context)!;
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      final displayError = _error == 'collectionNotFound'
          ? l10n.collectionNotFound
          : l10n.failedToLoadCollection;
      return ErrorStateWidget(
        message: _error == 'collectionNotFound'
            ? displayError
            : '$displayError\n$_error',
        onRetry: _loadData,
      );
    }

    final validNotes = _collectionNotes
        .where((cn) => _notesMap.containsKey(cn.noteId))
        .toList();

    if (validNotes.isEmpty) {
      return EmptyState(
        icon: Icons.note_add_outlined,
        title: l10n.noNotesInCollection,
        subtitle: l10n.tapToAddNotes,
        actionLabel: l10n.addNotes,
        onAction: _showAddNotesSheet,
      );
    }

    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.s4,
        AppSpacing.md,
        96,
      ),
      itemCount: validNotes.length,
      onReorder: (oldIndex, newIndex) =>
          _onReorder(validNotes, oldIndex, newIndex),
      itemBuilder: (context, index) {
        final cn = validNotes[index];
        final note = _notesMap[cn.noteId]!;
        final title = note.plainTitle ?? l10n.untitled;

        return Padding(
          key: ValueKey(cn.noteId),
          padding: const EdgeInsets.only(bottom: AppSpacing.s8),
          child: Dismissible(
            key: ValueKey(cn.noteId),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.warning.withAlpha(20),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(
                Icons.remove_circle_outline,
                color: AppColors.warning.withAlpha(150),
              ),
            ),
            confirmDismiss: (direction) async {
              return await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  title: Text(l10n.removeFromCollection),
                  content: Text(
                    l10n.removeNoteConfirm(title),
                    style: AppTextStyles.body,
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: Text(l10n.cancel),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: Text(l10n.remove),
                    ),
                  ],
                ),
              );
            },
            onDismissed: (direction) async {
              final db = ref.read(databaseProvider);
              await db.collectionsDao.removeNoteFromCollection(
                widget.collectionId,
                cn.noteId,
              );
              _loadData();
            },
            child: Stack(
              children: [
                NoteCard(
                  note: note,
                  time: _formatTime(note.updatedAt),
                  tags: const [],
                  isSelected: false,
                  onTap: () => context.push('/notes/${cn.noteId}'),
                  onLongPress: null,
                  untitled: l10n.untitled,
                  layout: NoteCardLayout.list,
                  listIndex: index,
                ),
                // Drag handle overlay
                Positioned(
                  top: 0,
                  right: 0,
                  child: ReorderableDragStartListener(
                    index: index,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.darkCardBg.withAlpha(200)
                            : AppColors.lightCardBg.withAlpha(200),
                        borderRadius:
                            BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Icon(
                        Icons.drag_handle,
                        size: 18,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.darkTextTertiary
                            : AppColors.lightTextTertiary,
                      ),
                    ),
                  ),
                ),
                // Remove button overlay
                Positioned(
                  top: 0,
                  right: 40,
                  child: GestureDetector(
                    onTap: () async {
                      final db = ref.read(databaseProvider);
                      await db.collectionsDao.removeNoteFromCollection(
                        widget.collectionId,
                        cn.noteId,
                      );
                      _loadData();
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.darkCardBg.withAlpha(200)
                            : AppColors.lightCardBg.withAlpha(200),
                        borderRadius:
                            BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.darkTextTertiary
                            : AppColors.lightTextTertiary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _onReorder(
    List<CollectionNote> validNotes,
    int oldIndex,
    int newIndex,
  ) {
    if (oldIndex < newIndex) newIndex -= 1;

    setState(() {
      final item = validNotes.removeAt(oldIndex);
      validNotes.insert(newIndex, item);
    });

    _persistSortOrder(validNotes);
  }

  Future<void> _persistSortOrder(List<CollectionNote> notes) async {
    final db = ref.read(databaseProvider);
    for (var i = 0; i < notes.length; i++) {
      final cn = notes[i];
      await db.collectionsDao.removeNoteFromCollection(
        widget.collectionId,
        cn.noteId,
      );
      await db.collectionsDao.addNoteToCollection(
        collectionId: widget.collectionId,
        noteId: cn.noteId,
        sortOrder: i,
      );
    }
  }

  void _showRenameDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final titleController = TextEditingController(
      text: _collection?.plainTitle ?? '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text(l10n.renameCollection),
        content: TextField(
          controller: titleController,
          decoration: InputDecoration(
            labelText: l10n.collectionTitle,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              final newTitle = titleController.text.trim();
              if (newTitle.isEmpty) return;

              final db = ref.read(databaseProvider);
              final crypto = ref.read(cryptoServiceProvider);

              String encryptedTitle = newTitle;
              if (crypto.isUnlocked) {
                encryptedTitle =
                    await crypto.encryptForItem(widget.collectionId, newTitle);
              }

              await db.collectionsDao.updateCollection(
                id: widget.collectionId,
                encryptedTitle: encryptedTitle,
                plainTitle: newTitle,
              );

              if (ctx.mounted) Navigator.of(ctx).pop();
              _loadData();
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text(l10n.deleteCollectionDialogTitle),
        content: Text(
          l10n.deleteCollectionDialogMessage,
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              final db = ref.read(databaseProvider);
              await db.collectionsDao.deleteCollection(widget.collectionId);
              if (context.mounted) {
                Navigator.pop(ctx);
                context.pop();
              }
            },
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  void _showAddNotesSheet() {
    final db = ref.read(databaseProvider);
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) => FutureBuilder<List<Note>>(
          future: db.notesDao.getAllNotes(),
          builder: (ctx, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final allNotes = snapshot.data ?? [];
            final currentNoteIds =
                _collectionNotes.map((cn) => cn.noteId).toSet();

            return Column(
              children: [
                // Drag handle
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
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
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.s8,
                    AppSpacing.md,
                    AppSpacing.s4,
                  ),
                  child: Row(
                    children: [
                      Text(
                        l10n.addNotes,
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: l10n.close,
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  color: isDark
                      ? AppColors.darkDivider.withAlpha(60)
                      : AppColors.lightDivider.withAlpha(80),
                ),
                Expanded(
                  child: allNotes.isEmpty
                      ? Center(
                          child: Text(
                            l10n.noNotesAvailable,
                            style: AppTextStyles.body.copyWith(
                              color: isDark
                                  ? AppColors.darkTextTertiary
                                  : AppColors.lightTextTertiary,
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: allNotes.length,
                          itemBuilder: (ctx, index) {
                            final note = allNotes[index];
                            final isInCollection =
                                currentNoteIds.contains(note.id);
                            final title =
                                note.plainTitle ?? l10n.untitled;

                            return CheckboxListTile(
                              value: isInCollection,
                              title: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.body,
                              ),
                              subtitle: note.plainContent != null &&
                                      note.plainContent!.isNotEmpty
                                  ? Text(
                                      note.plainContent!.length > 60
                                          ? '${note.plainContent!.substring(0, 60)}...'
                                          : note.plainContent!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.caption.copyWith(
                                        fontSize: 12,
                                        color: isDark
                                            ? AppColors.darkTextTertiary
                                            : AppColors.lightTextTertiary,
                                      ),
                                    )
                                  : null,
                              onChanged: (checked) async {
                                if (checked == true) {
                                  final maxSort = _collectionNotes.isEmpty
                                      ? -1
                                      : _collectionNotes
                                          .map((cn) => cn.sortOrder)
                                          .reduce(
                                              (a, b) => a > b ? a : b,);
                                  await db.collectionsDao.addNoteToCollection(
                                    collectionId: widget.collectionId,
                                    noteId: note.id,
                                    sortOrder: maxSort + 1,
                                  );
                                } else {
                                  await db.collectionsDao
                                      .removeNoteFromCollection(
                                    widget.collectionId,
                                    note.id,
                                  );
                                }
                                await _loadData();
                                if (mounted) setState(() {});
                              },
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);

    if (diff.inMinutes < 1) return AppLocalizations.of(context)!.justNow;
    if (diff.inHours < 1) {
      return AppLocalizations.of(context)!.minutesAgo(diff.inMinutes);
    }
    if (diff.inDays < 1) {
      return AppLocalizations.of(context)!.hoursAgo(diff.inHours);
    }
    if (diff.inDays < 7) {
      return AppLocalizations.of(context)!.daysAgo(diff.inDays);
    }
    return '${local.year}-${_pad(local.month)}-${_pad(local.day)}';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}
