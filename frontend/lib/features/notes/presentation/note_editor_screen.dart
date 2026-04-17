import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../main.dart';

class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({super.key});

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  Timer? _debounce;
  String? _noteId;
  bool _isNew = true;

  @override
  void initState() {
    super.initState();
    _noteId = const Uuid().v4();
    _contentController.addListener(_onContentChanged);
  }

  void _onContentChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), _saveNote);
  }

  Future<void> _saveNote() async {
    final db = ref.read(databaseProvider);
    final title = _titleController.text.trim();
    final content = _contentController.text;

    if (content.isEmpty && title.isEmpty) return;

    // In production: encrypt before saving
    // final encryptKey = await MasterKeyManager.deriveEncryptKey(masterKey);
    // final itemKey = MasterKeyManager.deriveItemKey(encryptKey, _noteId!);
    // final encryptedContent = await Encryptor.encrypt(content, itemKey);

    if (_isNew) {
      await db.notesDao.createNote(
        id: _noteId!,
        encryptedContent: content, // Placeholder: should be encrypted
        plainContent: content,
        plainTitle: title.isEmpty ? null : title,
      );
      _isNew = false;
    } else {
      await db.notesDao.updateNote(
        id: _noteId!,
        plainContent: content,
        plainTitle: title.isEmpty ? null : title,
      );
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        actions: [
          IconButton(icon: const Icon(Icons.tag_add_outlined), onPressed: () {}),
          IconButton(icon: const Icon(Icons.check), onPressed: () async {
            await _saveNote();
            if (context.mounted) context.pop();
          }),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(hintText: 'Title', border: InputBorder.none),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            Expanded(
              child: TextField(
                controller: _contentController,
                decoration: const InputDecoration(hintText: 'Start writing...', border: InputBorder.none),
                maxLines: null,
                style: const TextStyle(fontSize: 16, height: 1.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
