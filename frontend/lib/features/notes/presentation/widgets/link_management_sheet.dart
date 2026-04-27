import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/widgets/error_state_widget.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../main.dart';

/// Bottom sheet for managing all links of a note.
///
/// Shows both inbound (backlinks) and outbound (related notes) links
/// with ability to delete unwanted connections.
class LinkManagementSheet extends ConsumerStatefulWidget {
  final String noteId;

  const LinkManagementSheet({super.key, required this.noteId});

  @override
  ConsumerState<LinkManagementSheet> createState() =>
      _LinkManagementSheetState();
}

class _LinkManagementSheetState extends ConsumerState<LinkManagementSheet> {
  bool _showBacklinks = true;
  bool _showOutbound = true;

  @override
  Widget build(BuildContext context) {
    final db = ref.read(databaseProvider);
    final l10n = AppLocalizations.of(context)!;

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
                  Icons.link,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.linkManagementTitle,
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

          // Filter chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: Text(l10n.backlinks),
                  selected: _showBacklinks,
                  onSelected: (value) => setState(() => _showBacklinks = value),
                  avatar:
                      _showBacklinks ? const Icon(Icons.check, size: 16) : null,
                ),
                FilterChip(
                  label: Text(l10n.outboundLinks),
                  selected: _showOutbound,
                  onSelected: (value) => setState(() => _showOutbound = value),
                  avatar:
                      _showOutbound ? const Icon(Icons.check, size: 16) : null,
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Links list
          Expanded(
            child: FutureBuilder(
              future: Future.wait([
                if (_showBacklinks)
                  db.noteLinksDao.getBacklinks(widget.noteId)
                else
                  Future.value(<NoteLink>[]),
                if (_showOutbound)
                  db.noteLinksDao.getOutboundLinks(widget.noteId)
                else
                  Future.value(<NoteLink>[]),
              ]),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return ErrorStateWidget(
                    message: '${snapshot.error}',
                    onRetry: () => setState(() {}),
                  );
                }

                final backlinks = snapshot.data?[0] ?? <NoteLink>[];
                final outbound = snapshot.data?[1] ?? <NoteLink>[];
                final allLinks = [
                  ...backlinks
                      .map((l) => _LinkItem(link: l, type: _LinkType.backlink)),
                  ...outbound
                      .map((l) => _LinkItem(link: l, type: _LinkType.outbound)),
                ];

                if (allLinks.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        l10n.noLinksToDisplay,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  controller: scrollController,
                  itemCount: allLinks.length,
                  itemBuilder: (context, index) {
                    final item = allLinks[index];
                    return _ManageableLinkTile(
                      item: item,
                      currentNoteId: widget.noteId,
                      onDelete: () => _deleteLink(db, item),
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

  Future<void> _deleteLink(AppDatabase db, _LinkItem item) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteLinkTitle),
        content: Text(l10n.removeLinkConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final link = item.link;
      await db.noteLinksDao.deleteLink(link.sourceId, link.targetId);
      setState(() {
        // Refresh the list
      });
    }
  }
}

enum _LinkType { backlink, outbound }

class _LinkItem {
  final NoteLink link;
  final _LinkType type;
  _LinkItem({required this.link, required this.type});
}

class _ManageableLinkTile extends ConsumerWidget {
  final _LinkItem item;
  final String currentNoteId;
  final VoidCallback onDelete;

  const _ManageableLinkTile({
    required this.item,
    required this.currentNoteId,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(databaseProvider);
    final l10n = AppLocalizations.of(context)!;
    final isBacklink = item.type == _LinkType.backlink;
    final otherId = isBacklink ? item.link.sourceId : item.link.targetId;

    return ListTile(
      leading: Icon(
        isBacklink ? Icons.call_received : Icons.call_made,
        color: isBacklink
            ? Theme.of(context).colorScheme.secondary
            : Theme.of(context).colorScheme.primary,
      ),
      title: FutureBuilder<String>(
        future: _resolveTitle(db, otherId),
        builder: (context, snapshot) {
          final title = snapshot.data ?? otherId.substring(0, 8);
          return Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium,
          );
        },
      ),
      subtitle: Text(
        isBacklink ? l10n.linksToThisNote : l10n.thisNoteLinksTo,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: l10n.deleteLinkTooltip,
        onPressed: onDelete,
      ),
      onTap: () {
        Navigator.of(context).pop();
        context.push('/notes/$otherId');
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
      debugPrint('[LinkManagementSheet] failed to resolve note title: $e');
    }
    return noteId.substring(0, 8);
  }
}
