import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state_widget.dart';
import '../../../../main.dart';

/// Bottom sheet showing notes with no connections (orphaned notes).
///
/// Orphaned notes are notes that have neither inbound nor outbound links.
/// These notes are disconnected from the knowledge graph.
class OrphanedNotesSheet extends ConsumerWidget {
  const OrphanedNotesSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(databaseProvider);

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
                  Icons.scatter_plot_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Orphaned Notes',
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
                      Icons.info_outline,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Notes with no connections to other notes.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Orphaned notes list
          Expanded(
            child: FutureBuilder<List<Note>>(
              future: _findOrphanedNotes(db),
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

                final orphans = snapshot.data ?? [];

                if (orphans.isEmpty) {
                  return const EmptyState(
                    icon: Icons.check_circle_outline,
                    title: 'No Orphaned Notes',
                    subtitle: 'All your notes are connected!',
                  );
                }

                return ListView.builder(
                  controller: scrollController,
                  itemCount: orphans.length,
                  itemBuilder: (context, index) {
                    final note = orphans[index];
                    return _OrphanedNoteTile(note: note);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Finds notes that have no inbound or outbound links.
  Future<List<Note>> _findOrphanedNotes(AppDatabase db) async {
    // Get all notes
    final allNotes = await db.notesDao.getAllNotes();
    // Get all links
    final allLinks = await db.noteLinksDao.getAllLinks();

    // Collect all note IDs that participate in links
    final linkedNoteIds = <String>{};
    for (final link in allLinks) {
      linkedNoteIds.add(link.sourceId);
      linkedNoteIds.add(link.targetId);
    }

    // Filter notes that are not in any link
    final orphans =
        allNotes.where((note) => !linkedNoteIds.contains(note.id)).toList();

    // Sort by updated date
    orphans.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return orphans;
  }
}

class _OrphanedNoteTile extends ConsumerWidget {
  final Note note;

  const _OrphanedNoteTile({required this.note});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = note.plainTitle ?? 'Untitled';
    final preview = note.plainContent ?? '';
    final displayPreview =
        preview.length > 100 ? '${preview.substring(0, 100)}...' : preview;

    return ListTile(
      leading: const Icon(Icons.note_outlined),
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
      trailing: const Icon(Icons.link_off, size: 16),
      onTap: () {
        Navigator.of(context).pop();
        context.push('/notes/${note.id}');
      },
    );
  }
}
