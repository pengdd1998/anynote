import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/accessibility/a11y_utils.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart';
import '../../../core/crypto/crypto_service.dart';
import '../../../core/database/app_database.dart';
import '../../../core/error/error.dart';
import '../../../core/export/export_service.dart';
import '../../../core/widgets/markdown_preview.dart';
import 'share_sheet.dart';

class NoteDetailScreen extends ConsumerWidget {
  final String noteId;
  const NoteDetailScreen({super.key, required this.noteId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(databaseProvider);
    final crypto = ref.read(cryptoServiceProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        actions: [
          A11yUtils.labeledButton(
            label: l10n.markdownPreview,
            child: IconButton(
              icon: const Icon(Icons.visibility_outlined),
              tooltip: l10n.markdownPreview,
              onPressed: () => context.push('/notes/$noteId/preview'),
            ),
          ),
          A11yUtils.labeledButton(
            label: l10n.versionHistory,
            child: IconButton(
              icon: const Icon(Icons.history),
              tooltip: l10n.versionHistory,
              onPressed: () => context.push('/notes/$noteId/history'),
            ),
          ),
          A11yUtils.labeledButton(
            label: l10n.editNote,
            child: IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: l10n.editNote,
              onPressed: () => context.push('/notes/$noteId'),
            ),
          ),
          A11yUtils.labeledButton(
            label: l10n.deleteNote,
            child: IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.deleteNote,
              onPressed: () => _confirmDelete(context, db),
            ),
          ),
          A11yUtils.labeledButton(
            label: l10n.exportOrShare,
            child: PopupMenuButton<String>(
            icon: const Icon(Icons.share_outlined),
            tooltip: l10n.exportOrShare,
            onSelected: (value) => _onExportSelected(context, ref, value),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'share_link',
                child: ListTile(
                  leading: const Icon(Icons.link),
                  title: Text(l10n.shareViaLink),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
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
            ],
          ),
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
            final appError = ErrorMapper.map(snapshot.error!);
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(ErrorDisplay.errorIcon(appError), size: 48, color: Colors.red.shade300),
                    const SizedBox(height: 16),
                    Text(
                      l10n.failedToLoadNote,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ErrorDisplay.userMessage(appError),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.tonal(
                      onPressed: () => _loadNote(db, crypto, l10n),
                      child: Text(l10n.retry),
                    ),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data;
          if (data == null) {
            return Center(child: Text(l10n.noteNotFound));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  label: 'Note title: ${data.title}',
                  header: true,
                  child: Text(
                  data.title,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                Semantics(
                  label: 'Updated ${data.updatedAt.toLocal().toString().substring(0, 16)}${data.isSynced ? '' : ', ${l10n.notSynced}'}',
                  child: Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      'Updated ${data.updatedAt.toLocal().toString().substring(0, 16)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                    if (!data.isSynced) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.cloud_off, size: 14, color: Colors.orange.shade300),
                      const SizedBox(width: 4),
                      Text(l10n.notSynced,
                          style:
                              TextStyle(fontSize: 12, color: Colors.orange.shade300),),
                    ],
                  ],
                  ),
                ),
                const Divider(height: 32),
                Semantics(
                  label: l10n.noteContent,
                  child: MarkdownPreview(
                    content: data.content,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Load the note and decrypt its content.
  /// Falls back to the plain cache if decryption is not possible.
  Future<_DecryptedNote?> _loadNote(
    AppDatabase db,
    CryptoService crypto,
    AppLocalizations l10n,
  ) async {
    final note = await db.notesDao.getNoteById(noteId);
    if (note == null) return null;

    String title = note.plainTitle ?? l10n.untitled;
    String content = note.plainContent ?? '';

    // Attempt decryption if crypto is unlocked. This ensures correctness even
    // if the plain cache was cleared or the note arrived from sync without
    // populated plain fields.
    if (crypto.isUnlocked) {
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
    }

    return _DecryptedNote(
      title: title,
      content: content,
      updatedAt: note.updatedAt,
      isSynced: note.isSynced,
    );
  }

  void _onExportSelected(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    if (action == 'share_link') {
      _openShareSheet(context, ref);
      return;
    }

    final db = ref.read(databaseProvider);
    final crypto = ref.read(cryptoServiceProvider);
    final l10n = AppLocalizations.of(context)!;
    final noteData = await _loadNote(db, crypto, l10n);

    if (!context.mounted || noteData == null) {
      if (context.mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.couldNotLoadForExport)),
        );
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
        await ExportService.shareFile(
          file,
          subject: noteData.title,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
        label: 'Confirm delete note dialog',
        child: AlertDialog(
        title: Text(l10n.deleteNoteDialog),
        content: Text(l10n.deleteNoteDialogMessage),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel),),
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

/// Simple data class for a decrypted note's display properties.
class _DecryptedNote {
  final String title;
  final String content;
  final DateTime updatedAt;
  final bool isSynced;

  _DecryptedNote({
    required this.title,
    required this.content,
    required this.updatedAt,
    required this.isSynced,
  });
}
