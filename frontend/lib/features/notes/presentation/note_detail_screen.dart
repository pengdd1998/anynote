import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart';
import '../../../core/crypto/crypto_service.dart';
import '../../../core/crypto/decryption_exception.dart';
import '../../../core/database/app_database.dart';
import '../../../core/error/error.dart';
import '../../../core/export/export_service.dart';
import '../domain/decrypted_note.dart';
import 'widgets/quill_read_only_viewer.dart';
import 'share_sheet.dart';
import 'widgets/export_sheet.dart';
import 'widgets/print_preview_sheet.dart';

/// Maximum content width for comfortable reading.
const _kMaxContentWidth = 720.0;

class NoteDetailScreen extends ConsumerWidget {
  final String noteId;
  const NoteDetailScreen({super.key, required this.noteId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(databaseProvider);
    final crypto = ref.read(cryptoServiceProvider);
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Divider(
            height: 0.5,
            thickness: 0.5,
            color: isDark
                ? AppColors.darkDivider.withAlpha(40)
                : AppColors.lightDivider.withAlpha(60),
          ),
        ),
        actions: [
          // Edit — direct action, most important CTA
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: l10n.editNote,
            onPressed: () => context.push('/notes/$noteId/edit'),
          ),
          // Star / bookmark
          IconButton(
            icon: const Icon(Icons.star_outline),
            tooltip: l10n.moreActions,
            onPressed: () {},
          ),
          // Share
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: l10n.shareViaLink,
            onPressed: () => _openShareSheet(context, ref),
          ),
          // More actions
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz),
            tooltip: l10n.moreActions,
            position: PopupMenuPosition.under,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            onSelected: (value) =>
                _onActionSelected(context, ref, value, db),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'share_link',
                child: ListTile(
                  leading: const Icon(Icons.share),
                  title: Text(l10n.shareViaLink),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'preview',
                child: ListTile(
                  leading: const Icon(Icons.visibility_outlined),
                  title: Text(l10n.markdownPreview),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'history',
                child: ListTile(
                  leading: const Icon(Icons.history),
                  title: Text(l10n.versionHistory),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(
                    Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(
                    l10n.deleteNote,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'markdown',
                child: ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(l10n.exportAsMarkdown),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'html',
                child: ListTile(
                  leading: const Icon(Icons.code),
                  title: Text(l10n.exportAsHTML),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'plaintext',
                child: ListTile(
                  leading: const Icon(Icons.text_snippet_outlined),
                  title: Text(l10n.exportAsPlainText),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'markdown_frontmatter',
                child: ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(l10n.exportWithFrontmatter),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'export_zip',
                child: ListTile(
                  leading: const Icon(Icons.folder_zip_outlined),
                  title: Text(l10n.exportAsZip),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'print',
                child: ListTile(
                  leading: const Icon(Icons.print_outlined),
                  title: Text(l10n.printNote),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: FutureBuilder(
        future: _loadNote(db, crypto, l10n),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _buildErrorState(context, snapshot.error!, l10n, db, crypto);
          }

          final data = snapshot.data;
          if (data == null) {
            return Center(child: Text(l10n.noteNotFound));
          }

          return _buildContent(context, data, isDark);
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Content layout — max-width centered, calm reading experience
  // ---------------------------------------------------------------------------

  Widget _buildContent(BuildContext context, DecryptedNote data, bool isDark) {
    final textColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s20,
        vertical: AppSpacing.s20,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _kMaxContentWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // -- Title --
              Semantics(
                label: AppLocalizations.of(context)!.noteTitleLabel(data.title),
                header: true,
                child: Text(
                  data.title,
                  style: AppTextStyles.headline.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    letterSpacing: -0.5,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // -- Body --
              Semantics(
                label: AppLocalizations.of(context)!.noteContent,
                child: DefaultTextStyle(
                  style: AppTextStyles.body.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.6,
                    color: textColor,
                  ),
                  child: QuillReadOnlyViewer(
                    deltaJson: data.content,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),

              // -- Tags --
              if (data.tags.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.s8,
                  runSpacing: AppSpacing.s4,
                  children: data.tags.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s12,
                        vertical: AppSpacing.s4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.indigo50,
                        borderRadius: BorderRadius.circular(AppRadius.xxs),
                      ),
                      child: Text(
                        '#${tag.plainName}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],

              // -- Date / meta footer --
              const SizedBox(height: AppSpacing.s8),
              _buildMetaFooter(context, data, isDark),

              // Bottom breathing room
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaFooter(
    BuildContext context,
    DecryptedNote data,
    bool isDark,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final metaColor = isDark
        ? AppColors.darkTextTertiary
        : AppColors.lightTextTertiary;

    final minutes = (data.content.length ~/ 250) + 1;
    final dateStr = data.updatedAt.toLocal().toString().substring(0, 16);

    return Row(
      children: [
        Text(
          '${l10n.updatedDate(dateStr)}  ·  $minutes min read',
          style: AppTextStyles.caption.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: metaColor,
          ),
        ),
        if (!data.isSynced) ...[
          const SizedBox(width: AppSpacing.s12),
          const Icon(Icons.cloud_off_outlined, size: 12, color: AppColors.warning),
          const SizedBox(width: AppSpacing.s4),
          Text(
            l10n.notSynced,
            style: AppTextStyles.caption.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppColors.warning,
            ),
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Error state
  // ---------------------------------------------------------------------------

  Widget _buildErrorState(
    BuildContext context,
    Object error,
    AppLocalizations l10n,
    AppDatabase db,
    CryptoService crypto,
  ) {
    final appError = ErrorMapper.map(error);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(AppRadius.md),
                boxShadow: AppShadows.smOf(Theme.of(context).brightness),
              ),
              child: Icon(
                ErrorDisplay.errorIcon(appError),
                size: 32,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.failedToLoadNote,
              style: AppTextStyles.headline.copyWith(
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              ErrorDisplay.userMessage(appError, l10n),
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                color: isDark
                    ? AppColors.darkTextTertiary
                    : AppColors.lightTextTertiary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.tonal(
              onPressed: () => _loadNote(db, crypto, l10n),
              child: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Note loading + decryption
  // ---------------------------------------------------------------------------

  Future<DecryptedNote?> _loadNote(
    AppDatabase db,
    CryptoService crypto,
    AppLocalizations l10n,
  ) async {
    final note = await db.notesDao.getNoteById(noteId);
    if (note == null) return null;

    String title = note.plainTitle ?? l10n.untitled;
    String content = note.plainContent ?? '';

    if (crypto.isUnlocked) {
      try {
        final decryptedContent =
            await crypto.decryptForItem(noteId, note.encryptedContent);
        if (decryptedContent != null) {
          content = decryptedContent;
        }

        if (note.encryptedTitle != null) {
          final decryptedTitle =
              await crypto.decryptForItem(noteId, note.encryptedTitle!);
          if (decryptedTitle != null) {
            title = decryptedTitle;
          }
        }
      } on DecryptionException {
        // Fall back to plain cache values
      }
    }

    final tags = await db.tagsDao.getTagsForNote(noteId);

    // The stored content may be the sync envelope {"content":...,"title":...}
    // (the format sync packs for push) rather than a Quill Delta. Unwrap it
    // so the detail view renders the actual body, not the raw envelope JSON.
    content = _unwrapContentEnvelope(content);

    return DecryptedNote(
      title: title,
      content: content,
      updatedAt: note.updatedAt,
      isSynced: note.isSynced,
      tags: tags,
    );
  }

  /// If [content] is (or contains) the sync envelope {"content":...,"title":
  /// ...}, return its inner "content" (the plain-text body); otherwise return
  /// [content] unchanged. The envelope may be embedded (e.g. a legacy title
  /// prepended), so we locate it rather than requiring the whole string to be
  /// the envelope. A Quill Delta (JSON array) is left intact.
  String _unwrapContentEnvelope(String content) {
    final idx = content.indexOf('{"content"');
    if (idx < 0) return content;
    try {
      final decoded = jsonDecode(content.substring(idx));
      if (decoded is Map<String, dynamic> && decoded.containsKey('content')) {
        final inner = decoded['content'];
        if (inner is String) return inner;
      }
    } catch (_) {
      // Not a parseable envelope — leave as-is.
    }
    return content;
  }

  // ---------------------------------------------------------------------------
  // Actions dispatch
  // ---------------------------------------------------------------------------

  void _onActionSelected(
    BuildContext context,
    WidgetRef ref,
    String action,
    AppDatabase db,
  ) {
    switch (action) {
      case 'preview':
        context.push('/notes/$noteId/preview');
      case 'history':
        context.push('/notes/$noteId/history');
      case 'delete':
        _confirmDelete(context, db);
      case 'share_link':
        _openShareSheet(context, ref);
      case 'print':
        _openPrintPreview(context, ref);
      case 'markdown_frontmatter':
        _openExportSheet(context, scope: ExportScope.currentNote);
      case 'export_zip':
        _openExportSheet(context, scope: ExportScope.allNotes);
      default:
        _exportAs(context, ref, action);
    }
  }

  void _openExportSheet(
    BuildContext context, {
    required ExportScope scope,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => ExportSheet(
        currentNoteId: noteId,
        scope: scope,
      ),
    );
  }

  void _openPrintPreview(BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    final crypto = ref.read(cryptoServiceProvider);
    final l10n = AppLocalizations.of(context)!;
    final noteData = await _loadNote(db, crypto, l10n);
    if (!context.mounted || noteData == null) return;
    final note = await db.notesDao.getNoteById(noteId);
    if (!context.mounted || note == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => PrintPreviewSheet(
        note: note,
        title: noteData.title,
        content: noteData.content,
      ),
    );
  }

  void _exportAs(BuildContext context, WidgetRef ref, String action) async {
    final db = ref.read(databaseProvider);
    final crypto = ref.read(cryptoServiceProvider);
    final l10n = AppLocalizations.of(context)!;
    final noteData = await _loadNote(db, crypto, l10n);

    if (!context.mounted || noteData == null) {
      if (context.mounted) {
        final l10n = AppLocalizations.of(context)!;
        AppSnackBar.error(context, message: l10n.couldNotLoadForExport);
      }
      return;
    }

    try {
      final file = switch (action) {
        'markdown' => await ExportService.exportAsMarkdown(
            noteData.title,
            noteData.content,
            noteId,
          ),
        'html' => await ExportService.exportAsHtml(
            noteData.title,
            noteData.content,
            noteId,
          ),
        'plaintext' => await ExportService.exportAsPlainText(
            noteData.title,
            noteData.content,
            noteId,
          ),
        _ => null,
      };

      if (file != null && context.mounted) {
        await ExportService.shareFile(file, subject: noteData.title);
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackBar.error(
          context,
          message: l10n.exportFailed(ErrorDisplay.displayMessage(e, l10n)),
        );
      }
    }
  }

  void _openShareSheet(BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    final crypto = ref.read(cryptoServiceProvider);
    final l10n = AppLocalizations.of(context)!;
    final noteData = await _loadNote(db, crypto, l10n);

    if (!context.mounted || noteData == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => ShareSheet(
        title: noteData.title,
        content: noteData.content,
      ),
    );
  }

  void _confirmDelete(BuildContext context, AppDatabase db) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => Semantics(
        label: l10n.confirmDeleteNoteDialog,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          title: Text(l10n.deleteNoteDialog),
          content: Text(l10n.deleteNoteDialogMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () async {
                await db.notesDao.softDeleteNote(noteId);
                if (context.mounted) {
                  Navigator.pop(ctx);
                  context.pop();
                }
              },
              child: Text(l10n.delete),
            ),
          ],
        ),
      ),
    );
  }

}
