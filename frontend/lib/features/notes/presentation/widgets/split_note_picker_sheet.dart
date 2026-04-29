import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../main.dart';

/// Bottom sheet for selecting a note to open in split view.
///
/// Shows a searchable list of all notes (excluding soft-deleted ones).
/// When a note is selected, the [onSelect] callback is invoked with the
/// note ID and title.
class SplitNotePickerSheet extends ConsumerStatefulWidget {
  /// Note IDs to exclude from the list (e.g. the currently open note).
  final Set<String> excludeIds;

  /// Called when a note is selected.
  final void Function(String noteId, String title) onSelect;

  const SplitNotePickerSheet({
    super.key,
    this.excludeIds = const {},
    required this.onSelect,
  });

  @override
  ConsumerState<SplitNotePickerSheet> createState() =>
      _SplitNotePickerSheetState();
}

class _SplitNotePickerSheetState extends ConsumerState<SplitNotePickerSheet> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  List<Note> _filteredNotes = [];
  List<Note> _allNotes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.requestFocus();
    _loadNotes();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _filterNotes(_searchController.text);
  }

  Future<void> _loadNotes() async {
    setState(() => _isLoading = true);

    try {
      final db = ref.read(databaseProvider);
      // Load all non-deleted notes, limited to 200 for performance.
      final notes = await db.notesDao.getPaginatedNotes(200, 0);
      if (!mounted) return;
      setState(() {
        _allNotes =
            notes.where((n) => !widget.excludeIds.contains(n.id)).toList();
        _isLoading = false;
      });
      _filterNotes(_searchController.text);
    } catch (e) {
      debugPrint('[SplitNotePickerSheet] failed to load notes: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterNotes(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredNotes = _allNotes;
      });
      return;
    }

    final lowerQuery = query.toLowerCase();
    setState(() {
      _filteredNotes = _allNotes.where((note) {
        final title = note.plainTitle?.toLowerCase() ?? '';
        return title.contains(lowerQuery);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return SafeArea(
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
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Text(
                  l10n.selectNoteForSplit,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: l10n.searchNotes,
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Note list
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: _isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : _filteredNotes.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          l10n.noNotesFound,
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _filteredNotes.length,
                        itemBuilder: (context, index) {
                          final note = _filteredNotes[index];
                          final title = note.plainTitle ?? l10n.untitled;
                          return ListTile(
                            dense: true,
                            leading: const Icon(
                              Icons.article_outlined,
                              size: 20,
                            ),
                            title: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () {
                              widget.onSelect(note.id, title);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
