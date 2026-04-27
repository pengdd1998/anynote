import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../core/crypto/crypto_service.dart';
import '../../../../core/database/app_database.dart';
import '../../domain/decrypted_note.dart';

/// Placeholder shown in the detail pane when no note is selected on desktop.
class InlineDetailPlaceholder extends StatelessWidget {
  const InlineDetailPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.article_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.selectNoteToView,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

/// Inline note detail widget for the master-detail layout on desktop.
///
/// Loads and decrypts the note content, then renders it as Markdown
/// (similar to NoteDetailScreen but without its own Scaffold).
class InlineNoteDetail extends ConsumerStatefulWidget {
  final String noteId;
  final AppDatabase db;
  final CryptoService crypto;

  /// Optional callback to activate split view. Null when split view is
  /// already active (the button is hidden).
  final VoidCallback? onSplitViewToggle;

  const InlineNoteDetail({
    super.key,
    required this.noteId,
    required this.db,
    required this.crypto,
    this.onSplitViewToggle,
  });

  @override
  ConsumerState<InlineNoteDetail> createState() => _InlineNoteDetailState();
}

class _InlineNoteDetailState extends ConsumerState<InlineNoteDetail> {
  DecryptedNote? _data;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNote();
  }

  @override
  void didUpdateWidget(InlineNoteDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.noteId != widget.noteId) {
      _loadNote();
    }
  }

  Future<void> _loadNote() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final note = await widget.db.notesDao.getNoteById(widget.noteId);
      if (!mounted) return;
      if (note == null) {
        setState(() {
          _data = null;
          _isLoading = false;
        });
        return;
      }

      final l10n = AppLocalizations.of(context)!;
      String title = note.plainTitle ?? l10n.untitled;
      String content = note.plainContent ?? '';

      if (widget.crypto.isUnlocked) {
        final decryptedContent = await widget.crypto
            .decryptForItem(widget.noteId, note.encryptedContent);
        if (decryptedContent != null) {
          content = decryptedContent;
        }
        if (note.encryptedTitle != null) {
          final decryptedTitle = await widget.crypto
              .decryptForItem(widget.noteId, note.encryptedTitle!);
          if (decryptedTitle != null) {
            title = decryptedTitle;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _data = DecryptedNote(
          title: title,
          content: content,
          updatedAt: note.updatedAt,
          isSynced: note.isSynced,
        );
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(
                l10n.failedToLoadNote,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 16),
              FilledButton.tonal(onPressed: _loadNote, child: Text(l10n.retry)),
            ],
          ),
        ),
      );
    }

    if (_data == null) {
      return Center(child: Text(l10n.noteNotFound));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mini toolbar for the detail pane
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _data!.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                tooltip: l10n.editNote,
                onPressed: () => context.push('/notes/${widget.noteId}'),
              ),
              if (widget.onSplitViewToggle != null)
                IconButton(
                  icon: const Icon(Icons.vertical_split_outlined, size: 20),
                  tooltip: l10n.splitView,
                  onPressed: widget.onSplitViewToggle,
                ),
              IconButton(
                icon: const Icon(Icons.history, size: 20),
                tooltip: l10n.versionHistory,
                onPressed: () =>
                    context.push('/notes/${widget.noteId}/history'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Updated ${_data!.updatedAt.toLocal().toString().substring(0, 16)}',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                    if (!_data!.isSynced) ...[
                      const SizedBox(width: 12),
                      Icon(
                        Icons.cloud_off,
                        size: 14,
                        color: Colors.orange.shade300,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        l10n.notSynced,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade300,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                MarkdownBody(
                  data: _data!.content,
                  selectable: true,
                  sizedImageBuilder: (config) {
                    final uri = config.uri;
                    if (!kIsWeb && uri.scheme == 'file') {
                      return Image.file(
                        File.fromUri(uri),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.broken_image, size: 48),
                      );
                    }
                    return Image.network(
                      uri.toString(),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.broken_image, size: 48),
                    );
                  },
                  styleSheet: MarkdownStyleSheet(
                    p: const TextStyle(fontSize: 14, height: 1.6),
                    h1: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    h2: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    h3: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    code: TextStyle(
                      fontSize: 13,
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    blockquote: TextStyle(
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
