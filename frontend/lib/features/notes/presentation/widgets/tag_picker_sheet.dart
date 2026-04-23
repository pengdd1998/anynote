import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/crypto/crypto_service.dart';
import '../../../../core/database/app_database.dart';
import '../../../../l10n/app_localizations.dart';

/// Bottom sheet for picking and creating tags for a note.
///
/// Shows all available tags with checkboxes indicating assignment status.
/// Includes an inline text field for creating new tags on the fly.
///
/// Extracted from `NoteEditorScreen._TagPickerSheet`.
class TagPickerSheet extends ConsumerStatefulWidget {
  /// The ID of the note whose tags are being managed.
  final String noteId;

  /// Database instance for tag CRUD operations.
  final AppDatabase db;

  /// Crypto service for encrypting new tag names.
  final CryptoService crypto;

  const TagPickerSheet({
    super.key,
    required this.noteId,
    required this.db,
    required this.crypto,
  });

  @override
  ConsumerState<TagPickerSheet> createState() => _TagPickerSheetState();
}

class _TagPickerSheetState extends ConsumerState<TagPickerSheet> {
  final _newTagController = TextEditingController();
  List<Tag> _allTags = [];
  Set<String> _assignedTagIds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  @override
  void dispose() {
    _newTagController.dispose();
    super.dispose();
  }

  Future<void> _loadTags() async {
    final allTags = await widget.db.tagsDao.getAllTags();
    final noteTags = await widget.db.tagsDao.getTagsForNote(widget.noteId);
    if (!mounted) return;
    setState(() {
      _allTags = allTags;
      _assignedTagIds = noteTags.map((t) => t.id).toSet();
      _isLoading = false;
    });
  }

  Future<void> _createAndAssignTag() async {
    final tagName = _newTagController.text.trim();
    if (tagName.isEmpty) return;

    final tagId = const Uuid().v4();
    String encryptedName;
    if (widget.crypto.isUnlocked) {
      encryptedName = await widget.crypto.encryptForItem(tagId, tagName);
    } else {
      encryptedName = tagName;
    }

    await widget.db.tagsDao.createTag(
      id: tagId,
      encryptedName: encryptedName,
      plainName: tagName,
    );
    await widget.db.notesDao.addTagToNote(widget.noteId, tagId);

    _newTagController.clear();
    await _loadTags();
  }

  Future<void> _toggleTag(Tag tag, bool isAssigned) async {
    if (isAssigned) {
      await widget.db.notesDao.removeTagFromNote(widget.noteId, tag.id);
    } else {
      await widget.db.notesDao.addTagToNote(widget.noteId, tag.id);
    }
    await _loadTags();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              children: [
                Text(l10n.tags, style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: l10n.closeTagPicker,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Inline tag creation
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    label: l10n.newTagName,
                    child: TextField(
                      controller: _newTagController,
                      decoration: InputDecoration(
                        hintText: l10n.newTagName,
                        border: const OutlineInputBorder(),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: (_) => _createAndAssignTag(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  button: true,
                  label: 'Create and assign tag',
                  child: FilledButton(
                    onPressed: _createAndAssignTag,
                    child: Text(l10n.add),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Tag list with checkboxes
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            )
          else if (_allTags.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                l10n.noTagsYet,
                style: TextStyle(color: Colors.grey.shade500),
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _allTags.length,
                itemBuilder: (context, index) {
                  final tag = _allTags[index];
                  final isAssigned = _assignedTagIds.contains(tag.id);
                  final displayName = tag.plainName ?? tag.id.substring(0, 8);

                  return CheckboxListTile(
                    value: isAssigned,
                    title: Text(displayName),
                    onChanged: (checked) => _toggleTag(tag, isAssigned),
                  );
                },
              ),
            ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
