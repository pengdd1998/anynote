import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/sync_status_widget.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart';
import '../../../core/crypto/crypto_service.dart';
import '../../../core/database/app_database.dart';

class TagsScreen extends ConsumerStatefulWidget {
  const TagsScreen({super.key});

  @override
  ConsumerState<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends ConsumerState<TagsScreen> {
  final _tagNameController = TextEditingController();

  @override
  void dispose() {
    _tagNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final db = ref.read(databaseProvider);
    final crypto = ref.read(cryptoServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tagsTitle),
        actions: const [SyncStatusWidget()],
      ),
      body: StreamBuilder<List<Tag>>(
        stream: db.tagsDao.watchAllTags(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final tags = snapshot.data ?? [];

          if (tags.isEmpty) {
            return EmptyState(
              icon: Icons.label_outline,
              title: l10n.noTags,
              subtitle: l10n.createTagsToOrganize,
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              // Refresh the stream by re-querying; the StreamBuilder will
              // pick up the latest data automatically. This also provides
              // pull-to-refresh UX feedback.
              await db.tagsDao.getAllTags();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: tags.map((tag) {
                  return Chip(
                    label: Text(tag.plainName ?? l10n.encrypted),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () => _deleteTag(db, tag),
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(db, crypto),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showCreateDialog(AppDatabase db, CryptoService crypto) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.newTag),
        content: TextField(
          controller: _tagNameController,
          decoration: InputDecoration(labelText: l10n.tagName, hintText: l10n.tagNameHint),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _tagNameController.clear();
            },
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              final name = _tagNameController.text.trim();
              if (name.isNotEmpty) {
                final tagId = const Uuid().v4();
                final encryptedName = await crypto.encryptForItem(tagId, name);
                await db.tagsDao.createTag(
                  id: tagId,
                  encryptedName: encryptedName,
                  plainName: name,
                );
              }
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
              _tagNameController.clear();
            },
            child: Text(l10n.create),
          ),
        ],
      ),
    );
  }

  void _deleteTag(AppDatabase db, Tag tag) {
    db.tagsDao.deleteTag(tag.id);
  }
}
