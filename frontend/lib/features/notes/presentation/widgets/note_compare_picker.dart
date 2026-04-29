import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../main.dart';

/// Bottom sheet for selecting exactly two notes to compare.
///
/// Shows a searchable list of notes with checkbox-style selection.
/// The "Compare" button is only enabled when exactly 2 notes are selected.
class NoteComparePicker extends ConsumerStatefulWidget {
  const NoteComparePicker({super.key});

  @override
  ConsumerState<NoteComparePicker> createState() => _NoteComparePickerState();
}

class _NoteComparePickerState extends ConsumerState<NoteComparePicker> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<String> _selectedIds = {};
  List<dynamic>? _notes;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    final db = ref.read(databaseProvider);
    final notes = await db.notesDao.getAllNotes();
    if (mounted) {
      setState(() {
        _notes = notes;
      });
    }
  }

  List<dynamic> get _filteredNotes {
    if (_notes == null) return [];
    if (_searchQuery.isEmpty) return _notes!;
    final query = _searchQuery.toLowerCase();
    return _notes!.where((note) {
      final title = (note.plainTitle ?? '').toLowerCase();
      return title.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final filtered = _filteredNotes;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle bar.
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.selectNotesToCompare,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  // Compare button.
                  FilledButton(
                    onPressed: _selectedIds.length == 2 ? _onCompare : null,
                    child: Text(l10n.compareNotes),
                  ),
                ],
              ),
            ),
            // Selection hint.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _selectedIds.length == 2
                      ? l10n.compareNotes
                      : l10n.selectTwoNotes,
                  style: TextStyle(
                    fontSize: 12,
                    color: _selectedIds.length > 2
                        ? Colors.orange.shade700
                        : Colors.grey.shade500,
                  ),
                ),
              ),
            ),
            // Search bar.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: l10n.searchNotes,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  isDense: true,
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                },
              ),
            ),
            const Divider(height: 1),
            // Note list.
            Expanded(
              child: _notes == null
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? Center(
                          child: Text(
                            l10n.noNotesYet,
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final note = filtered[index];
                            final noteId = note.id;
                            final isSelected = _selectedIds.contains(noteId);
                            final title = note.plainTitle ?? l10n.untitled;
                            final updatedAt = note.updatedAt;

                            return CheckboxListTile(
                              value: isSelected,
                              onChanged: (bool? value) {
                                setState(() {
                                  if (value == true) {
                                    if (_selectedIds.length < 2) {
                                      _selectedIds.add(noteId);
                                    } else {
                                      // Replace the oldest selection.
                                      _selectedIds.remove(_selectedIds.first);
                                      _selectedIds.add(noteId);
                                    }
                                  } else {
                                    _selectedIds.remove(noteId);
                                  }
                                });
                              },
                              title: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                _formatDate(updatedAt),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              controlAffinity: ListTileControlAffinity.leading,
                              dense: true,
                            );
                          },
                        ),
            ),
          ],
        );
      },
    );
  }

  void _onCompare() {
    if (_selectedIds.length != 2) return;
    final ids = _selectedIds.toList();
    Navigator.of(context).pop(ids);
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    return '${local.year}-${_pad(local.month)}-${_pad(local.day)} '
        '${_pad(local.hour)}:${_pad(local.minute)}';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}
