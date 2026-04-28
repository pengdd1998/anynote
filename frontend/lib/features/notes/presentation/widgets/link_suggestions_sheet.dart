import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state_widget.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../main.dart';

/// Bottom sheet suggesting notes to link based on content similarity.
///
/// Analyzes note titles and content to find potentially related notes
/// that are not yet linked to the current note.
class LinkSuggestionsSheet extends ConsumerWidget {
  final String noteId;

  const LinkSuggestionsSheet({super.key, required this.noteId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(databaseProvider);
    final l10n = AppLocalizations.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n?.suggestedLinks ?? 'Suggested Links',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Info banner
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      Icons.tips_and_updates_outlined,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n?.similarContentDesc ??
                            'Notes with similar titles or content. Tap to create a link.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Suggestions list
          Expanded(
            child: FutureBuilder<List<Note>>(
              future: _getSuggestions(db, noteId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return ErrorStateWidget(
                    message: '${snapshot.error}',
                    onRetry: () {},
                  );
                }

                final suggestions = snapshot.data ?? [];

                if (suggestions.isEmpty) {
                  return EmptyState(
                    icon: Icons.search_off,
                    title: l10n?.noSuggestions ?? 'No Suggestions',
                    subtitle: l10n?.createMoreNotes ??
                        'Create more notes to get suggestions.',
                  );
                }

                return ListView.builder(
                  controller: scrollController,
                  itemCount: suggestions.length,
                  itemBuilder: (context, index) {
                    final note = suggestions[index];
                    return _SuggestionTile(
                      note: note,
                      sourceId: noteId,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Gets suggested notes based on content similarity.
  Future<List<Note>> _getSuggestions(AppDatabase db, String noteId) async {
    // Get current note
    final currentNote = await db.notesDao.getNoteById(noteId);
    if (currentNote == null) return [];

    // Get all notes except current
    final allNotes = await db.notesDao.getAllNotes();
    final otherNotes = allNotes.where((n) => n.id != noteId).toList();

    // Get existing links
    final outbound = await db.noteLinksDao.getOutboundLinks(noteId);
    final linkedIds = outbound.map((l) => l.targetId).toSet();

    // Filter out already linked notes
    final unlinkedNotes =
        otherNotes.where((n) => !linkedIds.contains(n.id)).toList();

    // Calculate similarity scores
    final scores = <Note, double>{};
    final currentText = _normalizeText(
      '${currentNote.plainTitle ?? ''} ${currentNote.plainContent ?? ''}',
    );

    for (final note in unlinkedNotes) {
      final noteText = _normalizeText(
        '${note.plainTitle ?? ''} ${note.plainContent ?? ''}',
      );
      scores[note] = _calculateSimilarity(currentText, noteText);
    }

    // Sort by similarity score and return top suggestions
    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Return notes with similarity score > 0.1
    return sorted
        .where((e) => e.value > 0.1)
        .take(10)
        .map((e) => e.key)
        .toList();
  }

  /// Normalizes text for comparison (lowercase, remove special chars).
  String _normalizeText(String text) {
    return text.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), ' ');
  }

  /// Calculates simple similarity between two texts.
  /// Uses word overlap as a simple metric.
  double _calculateSimilarity(String text1, String text2) {
    final words1 =
        text1.split(RegExp(r'\s+')).where((w) => w.length > 3).toSet();
    final words2 =
        text2.split(RegExp(r'\s+')).where((w) => w.length > 3).toSet();

    if (words1.isEmpty || words2.isEmpty) return 0;

    final intersection = words1.intersection(words2);
    final union = words1.union(words2);

    return union.isEmpty ? 0 : intersection.length / union.length;
  }
}

class _SuggestionTile extends ConsumerWidget {
  final Note note;
  final String sourceId;

  const _SuggestionTile({
    required this.note,
    required this.sourceId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(databaseProvider);
    final title = note.plainTitle ?? 'Untitled';
    final preview = note.plainContent ?? '';
    final displayPreview =
        preview.length > 80 ? '${preview.substring(0, 80)}...' : preview;

    return ListTile(
      leading: const Icon(Icons.add_circle_outline),
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      subtitle: displayPreview.isNotEmpty
          ? Text(
              displayPreview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            )
          : null,
      trailing: const Icon(Icons.add_link, size: 16),
      onTap: () => _createLink(db, context),
    );
  }

  Future<void> _createLink(AppDatabase db, BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    try {
      // Generate link ID
      final linkId = '${sourceId.substring(0, 8)}-${note.id.substring(0, 8)}';

      await db.noteLinksDao.createLink(
        id: linkId,
        sourceId: sourceId,
        targetId: note.id,
        linkType: 'wiki',
      );

      if (context.mounted) {
        Navigator.of(context).pop();
        AppSnackBar.info(context, message: l10n?.linkCreated ?? 'Link created');
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackBar.error(
          context,
          message: l10n?.failedToCreateLink(e.toString()) ??
              'Failed to create link: $e',
        );
      }
    }
  }
}
