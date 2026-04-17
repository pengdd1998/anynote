import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../main.dart';

class NoteDetailScreen extends ConsumerWidget {
  final String noteId;
  const NoteDetailScreen({super.key, required this.noteId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(databaseProvider);

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => context.push('/notes/$noteId')),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context, db),
          ),
          IconButton(icon: const Icon(Icons.share_outlined), onPressed: () {}),
        ],
      ),
      body: FutureBuilder(
        future: db.notesDao.getNoteById(noteId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final note = snapshot.data;
          if (note == null) {
            return const Center(child: Text('Note not found'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.plainTitle ?? 'Untitled',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      'Updated ${note.updatedAt.toLocal().toString().substring(0, 16)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                    if (!note.isSynced) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.cloud_off, size: 14, color: Colors.orange.shade300),
                      const SizedBox(width: 4),
                      Text('Not synced', style: TextStyle(fontSize: 12, color: Colors.orange.shade300)),
                    ],
                  ],
                ),
                const Divider(height: 32),
                Text(note.plainContent ?? '', style: const TextStyle(fontSize: 16, height: 1.6)),
              ],
            ),
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, dynamic db) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text('This note will be moved to trash. You can restore it later.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              await db.notesDao.softDeleteNote(noteId);
              if (context.mounted) {
                Navigator.pop(ctx);
                context.pop();
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
