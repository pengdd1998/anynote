import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/widgets/error_state_widget.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../main.dart';

/// Bottom sheet displaying outbound links (related notes) for a note.
///
/// Shows notes that this note links TO (outbound links).
/// Uses local database for fat-client architecture.
class RelatedNotesSheet extends ConsumerWidget {
  final String noteId;

  const RelatedNotesSheet({super.key, required this.noteId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final db = ref.read(databaseProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.4,
      minChildSize: 0.2,
      maxChildSize: 0.8,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.call_made_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.relatedNotes,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder(
              future: db.noteLinksDao.getOutboundLinks(noteId),
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

                final links = snapshot.data ?? [];
                if (links.isEmpty) {
                  return Center(child: Text(l10n.noRelatedNotes));
                }
                return ListView.builder(
                  controller: scrollController,
                  itemCount: links.length,
                  itemBuilder: (context, index) {
                    final link = links[index];
                    return _RelatedNoteTile(link: link);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RelatedNoteTile extends ConsumerWidget {
  final NoteLink link;

  const _RelatedNoteTile({required this.link});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(databaseProvider);
    return ListTile(
      leading: const Icon(Icons.note_outlined),
      title: FutureBuilder<String>(
        future: _resolveTitle(db, link.targetId),
        builder: (context, snapshot) {
          final title = snapshot.data ?? link.targetId.substring(0, 8);
          return Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium,
          );
        },
      ),
      subtitle: Text(
        link.linkType,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: const Icon(Icons.arrow_forward, size: 16),
      onTap: () {
        Navigator.of(context).pop();
        context.push('/notes/${link.targetId}');
      },
    );
  }

  Future<String> _resolveTitle(AppDatabase db, String noteId) async {
    try {
      final note = await db.notesDao.getNoteById(noteId);
      if (note != null &&
          note.plainTitle != null &&
          note.plainTitle!.isNotEmpty) {
        return note.plainTitle!;
      }
    } catch (e) {
      // Fall through to truncated UUID.
      debugPrint('[RelatedNotesSheet] failed to resolve note title: $e');
    }
    return noteId.substring(0, 8);
  }
}
