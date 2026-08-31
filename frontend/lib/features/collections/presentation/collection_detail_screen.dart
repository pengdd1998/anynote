import 'dart:io' if (dart.library.js) 'package:anynote/core/stubs/io_stub.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/crypto/crypto_service.dart';
import '../../../core/database/app_database.dart';
import '../../../core/error/error.dart';
import '../../../core/navigation/nav_guard.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/color_utils.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state_widget.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart';

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

  // -- Mockup pastel palette for icon/letter thumbnails ------------------------
  // Parallel to AppColors.accentBackgrounds (peach, yellow, coral, mint).

  static const List<Color> _thumbLightTexts = [
    AppColors.accentPeachText,
    AppColors.accentYellowText,
    AppColors.accentCoralText,
    AppColors.accentMintText,
  ];

  static const List<Color> _thumbDarkTexts = [
    AppColors.accentPeach,
    AppColors.accentYellow,
    AppColors.accentCoral,
    AppColors.accentMint,
  ];

  /// Stable pastel index derived from an entity id.
  static int _pastelIndex(String id) => (id.hashCode & 0x7fffffff) % 4;

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
        titleSpacing: 0,
        title: _buildHeader(l10n),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(AppIcons.edit),
            tooltip: l10n.renameCollectionTooltip,
            onPressed:
                _collection != null ? () => _showRenameDialog(context) : null,
          ),
          IconButton(
            icon: const Icon(AppIcons.delete),
            tooltip: l10n.deleteCollectionTooltip,
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddNotesSheet,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        child: const Icon(AppIcons.add),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header (mockup "Journal" style): thumbnail + handwritten title + count
  // ---------------------------------------------------------------------------

  Widget _buildHeader(AppLocalizations l10n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = _collection?.plainTitle ?? l10n.collectionFallback;

    return Row(
      children: [
        _collectionHeaderThumb(isDark),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.handwritingBody.copyWith(
                  fontSize: 24,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              Text(
                l10n.noteCount(_collectionNotes.length),
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
      ],
    );
  }

  /// Small rounded thumbnail for the header: pastel tile with the collection
  /// icon (the model carries no image, so we always use the icon tile).
  Widget _collectionHeaderThumb(bool isDark) {
    final collection = _collection;
    final i = collection == null ? 0 : _pastelIndex(collection.id);
    final colColor =
        collection == null ? null : parseHexColor(collection.color);

    final Color bg;
    final Color iconColor;
    if (colColor != null) {
      bg = isDark ? colColor.withAlpha(40) : colColor.withAlpha(25);
      iconColor = colColor;
    } else if (isDark) {
      bg = AppColors.darkInputFill;
      iconColor = AppColors.secondary;
    } else {
      bg = AppColors.accentBackgrounds[i];
      iconColor = _thumbLightTexts[i];
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Icon(Icons.folder, size: 24, color: iconColor),
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
            child: GestureDetector(
              onTap: () {
                final target = '/notes/${cn.noteId}';
                if (!NavGuard.canNavigate(target)) return;
                context.push(target);
              },
              child: _buildNoteCard(note, title, index),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Note row card (mockup style): thumbnail + title + date + row actions
  // ---------------------------------------------------------------------------

  Widget _buildNoteCard(Note note, String title, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tertiary =
        isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;
    final previewPath = note.firstImagePath;
    final hasImage = previewPath != null && previewPath.isNotEmpty && !kIsWeb;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBg : AppColors.lightCardBg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          // Leading thumbnail (56px, rounded): preview image if any,
          // otherwise a pastel tile with the first letter of the title.
          if (hasImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.xs),
              child: SizedBox(
                width: 56,
                height: 56,
                child: Image.file(
                  File(previewPath),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      _letterThumb(title, note.id, isDark),
                ),
              ),
            )
          else
            _letterThumb(title, note.id, isDark),
          const SizedBox(width: AppSpacing.s12),
          // Title + date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatTime(note.updatedAt),
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 12,
                    color: tertiary,
                  ),
                ),
              ],
            ),
          ),
          // Remove-from-collection button (kept from previous overlay)
          GestureDetector(
            onTap: () async {
              final db = ref.read(databaseProvider);
              await db.collectionsDao.removeNoteFromCollection(
                widget.collectionId,
                note.id,
              );
              _loadData();
            },
            child: SizedBox(
              width: 32,
              height: 32,
              child: Icon(Icons.close, size: 16, color: tertiary),
            ),
          ),
          // Drag handle for reordering (kept from previous overlay)
          ReorderableDragStartListener(
            index: index,
            child: SizedBox(
              width: 32,
              height: 32,
              child: Icon(Icons.drag_indicator, size: 18, color: tertiary),
            ),
          ),
        ],
      ),
    );
  }

  /// Pastel tile with the first letter of the note title.
  Widget _letterThumb(String title, String noteId, bool isDark) {
    final trimmed = title.trim();
    final letter = trimmed.isEmpty
        ? '-'
        : String.fromCharCode(trimmed.runes.first).toUpperCase();
    final i = _pastelIndex(noteId);
    return Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkInputFill : AppColors.accentBackgrounds[i],
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        letter,
        style: AppTextStyles.title.copyWith(
          fontSize: 20,
          color: isDark ? _thumbDarkTexts[i] : _thumbLightTexts[i],
        ),
      ),
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
          scrollPadding: const EdgeInsets.only(bottom: 120),
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
