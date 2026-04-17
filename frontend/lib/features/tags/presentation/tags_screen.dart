import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../main.dart';
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
    final db = ref.read(databaseProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tags'),
      ),
      body: StreamBuilder<List<Tag>>(
        stream: db.tagsDao.watchAllTags(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final tags = snapshot.data ?? [];

          if (tags.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.label_outline, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text('No tags yet', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey)),
                  const SizedBox(height: 8),
                  const Text('Create tags to organize your notes', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return Wrap(
            spacing: 8,
            runSpacing: 8,
            padding: const EdgeInsets.all(16),
            children: tags.map((tag) {
              return Chip(
                label: Text(tag.plainName ?? '(encrypted)'),
                deleteIcon: const Icon(Icons.close, size: 18),
                onDeleted: () => _deleteTag(db, tag),
              );
            }).toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(db),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showCreateDialog(dynamic db) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Tag'),
        content: TextField(
          controller: _tagNameController,
          decoration: const InputDecoration(labelText: 'Tag name', hintText: 'e.g., ideas, work, personal'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _tagNameController.clear();
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = _tagNameController.text.trim();
              if (name.isNotEmpty) {
                // In production: encrypt name before saving
                await db.tagsDao.createTag(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  encryptedName: name,
                  plainName: name,
                );
              }
              Navigator.pop(ctx);
              _tagNameController.clear();
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _deleteTag(dynamic db, Tag tag) {
    db.tagsDao.deleteTag(tag.id);
  }
}
