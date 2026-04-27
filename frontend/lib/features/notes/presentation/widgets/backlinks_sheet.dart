import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/widgets/error_state_widget.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../main.dart';

/// Bottom sheet displaying backlinks for a note.
///
/// Shows notes that link TO this note (inbound links).
/// Uses local database for fat-client architecture.
class BacklinksSheet extends ConsumerWidget {
  final String noteId;

  const BacklinksSheet({super.key, required this.noteId});

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
                Icon(Icons.link, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  l10n.backlinks,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder(
              future: db.noteLinksDao.getBacklinks(noteId),
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
                  return Center(child: Text(l10n.noBacklinks));
                }
                return ListView.builder(
                  controller: scrollController,
                  itemCount: links.length,
                  itemBuilder: (context, index) {
                    final link = links[index];
                    return _BacklinkTile(link: link);
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

class _BacklinkTile extends ConsumerWidget {
  final NoteLink link;

  const _BacklinkTile({required this.link});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(databaseProvider);
    return ListTile(
      leading: const Icon(Icons.note_outlined),
      title: FutureBuilder<String>(
        future: _resolveTitle(db, link.sourceId),
        builder: (context, snapshot) {
          final title = snapshot.data ?? link.sourceId.substring(0, 8);
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
        context.push('/notes/${link.sourceId}');
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
      debugPrint('[BacklinksSheet] failed to resolve note title: $e');
    }
    return noteId.substring(0, 8);
  }
}
