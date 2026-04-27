import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../main.dart';

/// Bottom sheet for suggesting and selecting notes when typing [[wiki links]].
///
/// Shows a searchable list of notes that match the typed text. When a note
/// is selected, inserts a wiki link embed and creates a NoteLink entry.
class WikiLinkPickerSheet extends ConsumerStatefulWidget {
  final String query;
  final String sourceNoteId;
  final void Function(String noteId, String title) onSelect;

  const WikiLinkPickerSheet({
    super.key,
    required this.query,
    required this.sourceNoteId,
    required this.onSelect,
  });

  @override
  ConsumerState<WikiLinkPickerSheet> createState() =>
      _WikiLinkPickerSheetState();
}

class _WikiLinkPickerSheetState extends ConsumerState<WikiLinkPickerSheet> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  List<Note> _filteredNotes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.query;
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
      final allNotes = await db.notesDao.getAllNotes();

      final searchLower = widget.query.toLowerCase();

      final filtered = allNotes.where((note) {
        final title = note.plainTitle ?? '';
        final content = note.plainContent ?? '';

        return title.toLowerCase().contains(searchLower) ||
            content.toLowerCase().contains(searchLower);
      }).toList();

      if (mounted) {
        setState(() {
          _filteredNotes = filtered;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterNotes(String query) {
    final searchLower = query.toLowerCase();

    if (_filteredNotes.isEmpty && !_isLoading) {
      _loadNotes();
      return;
    }

    final filtered = _filteredNotes.where((note) {
      final title = note.plainTitle ?? '';
      final content = note.plainContent ?? '';

      return title.toLowerCase().contains(searchLower) ||
          content.toLowerCase().contains(searchLower);
    }).toList();

    setState(() => _filteredNotes = filtered);
  }

  void _selectNote(Note note) {
    final title = note.plainTitle ?? 'Untitled';
    widget.onSelect(note.id, title);

    final db = ref.read(databaseProvider);
    final linkId = const Uuid().v4();

    db.noteLinksDao.createLink(
      id: linkId,
      sourceId: widget.sourceNoteId,
      targetId: note.id,
      linkType: 'wiki',
    );
  }

  void _createNewNote() {
    final title = _searchController.text.trim();
    if (title.isEmpty) return;

    final newNoteId = const Uuid().v4();
    widget.onSelect(newNoteId, title);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          _buildHeader(context, l10n, theme),
          _buildSearchField(context, l10n, theme),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredNotes.isEmpty
                    ? _buildEmptyState(context, l10n, theme)
                    : _buildNotesList(context, scrollController, l10n, theme),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(
            Icons.link,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            l10n.linkToNote,
            style: theme.textTheme.titleMedium,
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        decoration: InputDecoration(
          hintText: l10n.searchNotes,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _filterNotes('');
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest,
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.note_add_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isEmpty
                ? l10n.startTypingToSearch
                : l10n.noNotesFound,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (_searchController.text.isNotEmpty) ...[
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: _createNewNote,
              icon: const Icon(Icons.add),
              label: Text(l10n.createNewNote),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotesList(
    BuildContext context,
    ScrollController scrollController,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    return ListView.builder(
      controller: scrollController,
      itemCount: _filteredNotes.length,
      itemBuilder: (context, index) {
        final note = _filteredNotes[index];
        final title = note.plainTitle ?? l10n.untitled;
        final preview = note.plainContent ?? '';

        return ListTile(
          leading: const Icon(Icons.note_outlined),
          title: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            preview,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => _selectNote(note),
        );
      },
    );
  }
}
