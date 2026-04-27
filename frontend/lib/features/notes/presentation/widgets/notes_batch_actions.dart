import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../core/database/app_database.dart';

/// Batch action bar displayed at the bottom of the notes list during
/// multi-selection mode. Provides pin, color, lock, delete, export,
/// compare, collection move, and batch tag actions.
class NotesBatchActionBar extends ConsumerWidget {
  /// The set of currently selected note IDs.
  final Set<String> selectedNoteIds;

  /// The full list of loaded notes (used to check pinned status).
  final List<Note> notes;

  /// Callbacks for batch operations.
  final VoidCallback onTogglePin;
  final VoidCallback onColor;
  final VoidCallback onLock;
  final VoidCallback onDelete;
  final VoidCallback onExport;
  final VoidCallback? onCompare;
  final VoidCallback onMoveToCollection;
  final VoidCallback onAddTags;

  const NotesBatchActionBar({
    super.key,
    required this.selectedNoteIds,
    required this.notes,
    required this.onTogglePin,
    required this.onColor,
    required this.onLock,
    required this.onDelete,
    required this.onExport,
    this.onCompare,
    required this.onMoveToCollection,
    required this.onAddTags,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final hasPinned = selectedNoteIds.any((id) {
      final note = notes.firstWhereOrNull((n) => n.id == id);
      return note?.isPinned ?? false;
    });

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // Pin/Unpin button
              IconButton(
                icon:
                    Icon(hasPinned ? Icons.push_pin : Icons.push_pin_outlined),
                tooltip: hasPinned ? l10n.batchUnpin : l10n.batchPin,
                onPressed: selectedNoteIds.isEmpty ? null : onTogglePin,
              ),
              // Batch color button
              IconButton(
                icon: const Icon(Icons.palette_outlined),
                tooltip: l10n.batchColor,
                onPressed: selectedNoteIds.isEmpty ? null : onColor,
              ),
              // Batch lock/unlock button
              IconButton(
                icon: const Icon(Icons.lock_outline),
                tooltip: l10n.batchLock,
                onPressed: selectedNoteIds.isEmpty ? null : onLock,
              ),
              // Delete button
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: l10n.batchDelete,
                onPressed: selectedNoteIds.isEmpty ? null : onDelete,
              ),
              // Export button
              IconButton(
                icon: const Icon(Icons.file_download_outlined),
                tooltip: l10n.exportSelectedNotes,
                onPressed: selectedNoteIds.isEmpty ? null : onExport,
              ),
              // Compare button (only when exactly 2 notes selected)
              if (onCompare != null)
                IconButton(
                  icon: const Icon(Icons.compare),
                  tooltip: l10n.compareNotes,
                  onPressed: onCompare,
                ),
              // Move to Collection button
              IconButton(
                icon: const Icon(Icons.create_new_folder_outlined),
                tooltip: l10n.addToCollection,
                onPressed: selectedNoteIds.isEmpty ? null : onMoveToCollection,
              ),
              const Spacer(),
              // Add Tags button
              FilledButton.tonalIcon(
                icon: const Icon(Icons.add_circle),
                label: Text(l10n.batchAddTags),
                onPressed: selectedNoteIds.isEmpty ? null : onAddTags,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialog for selecting tags to add to notes in batch mode.
class TagPickerDialog extends StatefulWidget {
  final List<Tag> existingTags;

  const TagPickerDialog({super.key, required this.existingTags});

  @override
  State<TagPickerDialog> createState() => _TagPickerDialogState();

  /// Convenience method to show this dialog and return the selected tag IDs.
  static Future<List<String>?> show(
    BuildContext context, {
    required List<Tag> existingTags,
  }) {
    return showDialog<List<String>>(
      context: context,
      builder: (ctx) => TagPickerDialog(existingTags: existingTags),
    );
  }
}

class _TagPickerDialogState extends State<TagPickerDialog> {
  final Set<String> _selectedTagIds = {};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(l10n.batchAddTags),
      content: SizedBox(
        width: double.maxFinite,
        child: widget.existingTags.isEmpty
            ? Text(l10n.noTagsYet)
            : ListView.builder(
                shrinkWrap: true,
                itemCount: widget.existingTags.length,
                itemBuilder: (context, index) {
                  final tag = widget.existingTags[index];
                  final tagId = tag.id;
                  final isSelected = _selectedTagIds.contains(tagId);
                  final tagName = tag.plainName ?? l10n.encrypted;

                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          _selectedTagIds.add(tagId);
                        } else {
                          _selectedTagIds.remove(tagId);
                        }
                      });
                    },
                    title: Text(tagName),
                    controlAffinity: ListTileControlAffinity.leading,
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: _selectedTagIds.isEmpty
              ? null
              : () => Navigator.of(context).pop(_selectedTagIds.toList()),
          child: Text(l10n.add),
        ),
      ],
    );
  }
}
