import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/paper_tokens.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/paper_surface.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart';
import '../../../core/crypto/crypto_service.dart';
import '../../../core/crypto/decryption_exception.dart';
import '../../../core/database/app_database.dart';
import '../../../core/error/error.dart';
import '../../../core/export/export_service.dart';
import '../domain/decrypted_note.dart';
import '../domain/note_envelope.dart';
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
      // Paper tokens carry the desk color: the note reads as a sheet of
      // paper resting on the desk (matches the notes home surface).
      backgroundColor: PaperTokens.of(context).desk,
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
          // Star / bookmark — toggles the note's pinned (favorite) state.
          _StarButton(noteId: noteId),
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
    final l10n = AppLocalizations.of(context)!;
    final paper = PaperTokens.of(context);
    // Hide the title row when the note has no real title.
    final hasTitle = data.title.isNotEmpty && data.title != l10n.untitled;

    // The whole note reads as one sheet of paper on the desk: title,
    // body, tags and meta share the sheet, inked in the paper voice.
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.s8,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _kMaxContentWidth),
          child: PaperSurface(
            tilted: false,
            tone: isDark ? AppColors.darkCardBg : AppColors.lightCardBg,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // -- Title — handwritten display voice per the design mockup --
                  if (hasTitle) ...[
                    Text(
                      stripObjectPlaceholders(data.title),
                      style: AppTextStyles.handwritingTitle.copyWith(
                        fontSize: 30,
                        color: paper.ink,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // -- Body --
                  // Render via the same read-only Quill viewer the editor uses.
                  // A design-tuned Quill style theme is applied (Inter body
                  // 16/1.6, warm headings, lavender blockquotes) so the read
                  // view matches the mockup's calm reading experience.
                  Semantics(
                    label: l10n.noteContent,
                    child: QuillReadOnlyViewer(
                      deltaJson: data.content,
                      padding: EdgeInsets.zero,
                      customStyles: _buildReaderStyles(isDark),
                    ),
                  ),

                  // -- Tags --
                  if (data.tags.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.s8,
                      runSpacing: AppSpacing.s8,
                      children: data.tags.map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.s12,
                            vertical: AppSpacing.s4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius:
                                BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            '#${tag.plainName}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryText,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  // -- Date / meta footer --
                  const SizedBox(height: AppSpacing.s8),
                  _buildMetaFooter(context, data, isDark, paper.inkMuted),

                  // Bottom breathing room
                  const SizedBox(height: AppSpacing.xs),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the read-view Quill style theme matching the design mockup:
  /// Inter body 16/1.6 near-black, strong headings, lavender blockquotes
  /// and soft-tinted code blocks.
  quill.DefaultStyles _buildReaderStyles(bool isDark) {
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final codeBg = isDark ? AppColors.darkInputFill : AppColors.slate50;
    final quoteBg = isDark
        ? AppColors.primarySoft.withAlpha(30)
        : AppColors.primarySoft;

    final base = TextStyle(
      fontFamily: AppTextStyles.fontFamily,
      fontSize: 16,
      height: 1.6,
      color: textColor,
    );
    final monoBase = base.copyWith(
      // RobotoMono is registered in pubspec and gives consistent code blocks
      // family used by AppTextStyles.mono is not registered in pubspec.
      fontFamily: 'RobotoMono',
      fontSize: 14,
      height: 1.5,
    );

    return quill.DefaultStyles(
      h1: quill.DefaultTextBlockStyle(
        base.copyWith(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          height: 1.3,
          letterSpacing: -0.5,
        ),
        quill.HorizontalSpacing.zero,
        const quill.VerticalSpacing(16, 8),
        quill.VerticalSpacing.zero,
        null,
      ),
      h2: quill.DefaultTextBlockStyle(
        base.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          height: 1.3,
          letterSpacing: -0.3,
        ),
        quill.HorizontalSpacing.zero,
        const quill.VerticalSpacing(14, 6),
        quill.VerticalSpacing.zero,
        null,
      ),
      h3: quill.DefaultTextBlockStyle(
        base.copyWith(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          height: 1.35,
        ),
        quill.HorizontalSpacing.zero,
        const quill.VerticalSpacing(12, 4),
        quill.VerticalSpacing.zero,
        null,
      ),
      paragraph: quill.DefaultTextBlockStyle(
        base,
        quill.HorizontalSpacing.zero,
        const quill.VerticalSpacing(6, 0),
        quill.VerticalSpacing.zero,
        null,
      ),
      lists: quill.DefaultListBlockStyle(
        base,
        quill.HorizontalSpacing.zero,
        const quill.VerticalSpacing(4, 4),
        quill.VerticalSpacing.zero,
        null,
        null,
      ),
      quote: quill.DefaultTextBlockStyle(
        base.copyWith(
          color: isDark ? AppColors.secondary : AppColors.primaryText,
          fontStyle: FontStyle.italic,
        ),
        quill.HorizontalSpacing.zero,
        const quill.VerticalSpacing(8, 8),
        quill.VerticalSpacing.zero,
        BoxDecoration(
          color: quoteBg,
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
      ),
      code: quill.DefaultTextBlockStyle(
        monoBase,
        quill.HorizontalSpacing.zero,
        const quill.VerticalSpacing(8, 8),
        quill.VerticalSpacing.zero,
        BoxDecoration(
          color: codeBg,
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
      ),
      inlineCode: quill.InlineCodeStyle(
        style: monoBase.copyWith(color: textColor),
        backgroundColor: codeBg,
        radius: const Radius.circular(AppRadius.xxs),
      ),
      link: base.copyWith(
        color: isDark ? AppColors.secondary : AppColors.primaryText,
        decoration: TextDecoration.underline,
      ),
      color: textColor,
    );
  }

  Widget _buildMetaFooter(
    BuildContext context,
    DecryptedNote data,
    bool isDark, [
    Color? metaColorOverride,
  ]) {
    final l10n = AppLocalizations.of(context)!;
    final metaColor = metaColorOverride ??
        (isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary);

    final minutes = (data.content.length ~/ 250) + 1;
    final dateStr = data.updatedAt.toLocal().toString().substring(0, 16);

    return Row(
      children: [
        Text(
          '${l10n.updatedDate(dateStr)} · $minutes min read',
          style: AppTextStyles.caption.copyWith(
            fontSize: 12,
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
              fontSize: 12,
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

    // Notes saved without an explicit title keep it only as the first
    // content line (the home cards derive it the same way). Derive it here
    // too and drop that line from the body so the title is not rendered
    // twice — once in the handwritten title voice, once as plain body text.
    if (title.isEmpty || title == l10n.untitled) {
      final derived = _deriveTitleFromBody(content);
      if (derived != null) {
        title = derived;
        content = _stripFirstLineFromBody(content);
      }
    }

    return DecryptedNote(
      title: title,
      content: content,
      updatedAt: note.updatedAt,
      isSynced: note.isSynced,
      tags: tags,
    );
  }

  /// First non-empty line of the note body, or null when the body is empty.
  /// Mirrors NoteCard's title derivation.
  String? _deriveTitleFromBody(String content) {
    final plain = plainTextFromStoredContent(content);
    for (final line in plain.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }

  /// Removes everything up to and including the first line break so the
  /// derived title line does not duplicate inside the body viewer. Delta
  /// JSON loses its first text run's line; plain content loses line one.
  String _stripFirstLineFromBody(String content) {
    final trimmed = content.trim();
    if (trimmed.startsWith('[')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is List) {
          final ops = sanitizeDeltaOps(decoded);
          var seenFirstBreak = false;
          final remaining = <Map<String, dynamic>>[];
          for (final op in ops) {
            final insert = op['insert'];
            if (insert is! String) {
              if (seenFirstBreak) remaining.add(op);
              continue;
            }
            if (!seenFirstBreak) {
              final idx = insert.indexOf('\n');
              if (idx < 0) continue; // whole op is part of the title line
              seenFirstBreak = true;
              final rest = insert.substring(idx + 1);
              if (rest.isNotEmpty) {
                remaining.add({...op, 'insert': rest});
              }
              continue;
            }
            remaining.add(op);
          }
          if (seenFirstBreak) return jsonEncode(remaining);
          return content;
        }
      } catch (_) {
        // Not Delta JSON — fall through to plain handling.
      }
    }
    final idx = content.indexOf('\n');
    return idx < 0 ? '' : content.substring(idx + 1);
  }

  /// Delegate to the shared [unwrapSyncEnvelope] (see note_envelope.dart),
  /// which extracts a balanced JSON envelope even when it's baked into a
  /// Quill Delta's text.
  String _unwrapContentEnvelope(String content) => unwrapSyncEnvelope(content);

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

/// Star action in the app bar: toggles the note's pinned (favorite) state
/// via [NotesDao.togglePin], the same property the note list uses for its
/// pin badge. Self-contained so the stateless detail screen does not need
/// to rebuild when the pin state changes.
class _StarButton extends ConsumerStatefulWidget {
  final String noteId;

  const _StarButton({required this.noteId});

  @override
  ConsumerState<_StarButton> createState() => _StarButtonState();
}

class _StarButtonState extends ConsumerState<_StarButton> {
  bool _isPinned = false;

  @override
  void initState() {
    super.initState();
    _loadPinState();
  }

  Future<void> _loadPinState() async {
    final db = ref.read(databaseProvider);
    final note = await db.notesDao.getNoteById(widget.noteId);
    if (mounted) {
      setState(() => _isPinned = note?.isPinned ?? false);
    }
  }

  Future<void> _togglePin() async {
    final db = ref.read(databaseProvider);
    await db.notesDao.togglePin(widget.noteId);
    if (!mounted) return;
    setState(() => _isPinned = !_isPinned);
    final l10n = AppLocalizations.of(context)!;
    AppSnackBar.info(
      context,
      message: _isPinned ? l10n.pinNote : l10n.unpinNote,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return IconButton(
      icon: Icon(_isPinned ? Icons.star : Icons.star_outline),
      color: _isPinned ? AppColors.primary : null,
      tooltip: _isPinned ? l10n.unpinNote : l10n.pinNote,
      onPressed: _togglePin,
    );
  }
}
