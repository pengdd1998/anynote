import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../l10n/app_localizations.dart';
import '../data/search_providers.dart';

class AdvancedSearchScreen extends ConsumerStatefulWidget {
  const AdvancedSearchScreen({super.key});

  @override
  ConsumerState<AdvancedSearchScreen> createState() =>
      _AdvancedSearchScreenState();
}

class _AdvancedSearchScreenState extends ConsumerState<AdvancedSearchScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Auto-focus the search field.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final filters = ref.watch(searchFiltersProvider);
    final resultsAsync = ref.watch(searchResultsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.search),
        actions: [
          if (filters.hasActiveFilters)
            IconButton(
              icon: const Icon(Icons.filter_list_off),
              tooltip: l10n.clearAllFilters,
              onPressed: () {
                ref.read(searchFiltersProvider.notifier).clearAll();
                _searchController.clear();
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Search text field.
          _buildSearchField(filters),

          // Filter chips row.
          _buildFilterChips(filters),

          // Active filter chips (removable).
          if (filters.hasActiveFilters) _buildActiveFilters(filters),

          const Divider(height: 1),

          // Body: recent searches, results, or empty state.
          Expanded(
            child: filters.canSearch
                ? _buildResultsBody(resultsAsync, filters)
                : _buildRecentSearches(),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Search field
  // ---------------------------------------------------------------------------

  Widget _buildSearchField(SearchFilterState filters) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
                    ref.read(searchFiltersProvider.notifier).setQuery('');
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          filled: true,
        ),
        onChanged: (value) {
          ref.read(searchFiltersProvider.notifier).setQuery(value);
        },
        onSubmitted: (value) {
          _performSearch(value);
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Filter chips
  // ---------------------------------------------------------------------------

  Widget _buildFilterChips(SearchFilterState filters) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip(
              label: filters.dateRange != null
                  ? _formatDateRange(filters.dateRange!)
                  : l10n.dateRange,
              icon: Icons.date_range,
              isActive: filters.dateRange != null,
              onTap: () => _showDateRangePicker(filters),
              onClear: filters.dateRange != null
                  ? () =>
                      ref.read(searchFiltersProvider.notifier).clearDateRange()
                  : null,
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: filters.selectedTagIds.isNotEmpty
                  ? l10n.tagsCount(filters.selectedTagIds.length)
                  : l10n.tagsFilter,
              icon: Icons.label_outline,
              isActive: filters.selectedTagIds.isNotEmpty,
              onTap: () => _showTagPicker(filters),
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: filters.selectedCollectionIds.isNotEmpty
                  ? l10n.collectionsCount(filters.selectedCollectionIds.length)
                  : l10n.collectionsFilter,
              icon: Icons.folder_outlined,
              isActive: filters.selectedCollectionIds.isNotEmpty,
              onTap: () => _showCollectionPicker(filters),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return InputChip(
      label: Text(label),
      avatar: Icon(icon, size: 18),
      selected: isActive,
      onPressed: onTap,
      onDeleted: onClear,
      deleteIconColor: onClear != null ? null : Colors.transparent,
    );
  }

  // ---------------------------------------------------------------------------
  // Active filters display
  // ---------------------------------------------------------------------------

  Widget _buildActiveFilters(SearchFilterState filters) {
    return Consumer(
      builder: (context, ref, _) {
        final tagsAsync = ref.watch(allTagsProvider);
        final collectionsAsync = ref.watch(allCollectionsProvider);

        final chips = <Widget>[];

        // Date range chip.
        if (filters.dateRange != null) {
          chips.add(_buildRemovableChip(
            label: _formatDateRange(filters.dateRange!),
            onRemove: () =>
                ref.read(searchFiltersProvider.notifier).clearDateRange(),
          ),);
        }

        // Tag chips.
        tagsAsync.whenData((allTags) {
          for (final tagId in filters.selectedTagIds) {
            final tag = allTags.where((t) => t.id == tagId).firstOrNull;
            if (tag != null) {
              chips.add(_buildRemovableChip(
                label: tag.plainName ?? '...',
                onRemove: () =>
                    ref.read(searchFiltersProvider.notifier).removeTag(tagId),
              ),);
            }
          }
        });

        // Collection chips.
        collectionsAsync.whenData((allCollections) {
          for (final colId in filters.selectedCollectionIds) {
            final col = allCollections.where((c) => c.id == colId).firstOrNull;
            if (col != null) {
              chips.add(_buildRemovableChip(
                label: col.plainTitle ?? '...',
                onRemove: () => ref
                    .read(searchFiltersProvider.notifier)
                    .removeCollection(colId),
              ),);
            }
          }
        });

        if (chips.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: chips,
          ),
        );
      },
    );
  }

  Widget _buildRemovableChip({
    required String label,
    required VoidCallback onRemove,
  }) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      deleteIcon: const Icon(Icons.close, size: 16),
      onDeleted: onRemove,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  // ---------------------------------------------------------------------------
  // Recent searches
  // ---------------------------------------------------------------------------

  Widget _buildRecentSearches() {
    final recentAsync = ref.watch(recentSearchesProvider);

    return recentAsync.when(
      data: (recent) {
        if (recent.isEmpty) {
          final l10n = AppLocalizations.of(context)!;
          return EmptyState(
            icon: Icons.search,
            title: l10n.searchYourNotes,
            subtitle: l10n.enterQueryOrFilters,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppLocalizations.of(context)!.recentSearches,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await clearRecentSearches();
                      ref.invalidate(recentSearchesProvider);
                    },
                    child: Text(AppLocalizations.of(context)!.clearAll),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: recent.map((query) {
                  return ActionChip(
                    label: Text(query),
                    onPressed: () {
                      _searchController.text = query;
                      ref.read(searchFiltersProvider.notifier).setQuery(query);
                      _performSearch(query);
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  // ---------------------------------------------------------------------------
  // Search results body
  // ---------------------------------------------------------------------------

  Widget _buildResultsBody(
    AsyncValue<List<AdvancedSearchResult>> resultsAsync,
    SearchFilterState filters,
  ) {
    return resultsAsync.when(
      data: (results) {
        final l10n = AppLocalizations.of(context)!;
        if (results.isEmpty) {
          return EmptyState(
            icon: Icons.search_off,
            title: l10n.noResultsFound,
            subtitle: l10n.tryAdjustingSearch,
          );
        }

        // Show total count if available.
        final totalCount = ref.read(searchResultCountProvider);
        final countLabel = totalCount > results.length
            ? '${results.length} / $totalCount'
            : '${results.length}';

        return Column(
          children: [
            // Results count header.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.resultsCount(countLabel),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: results.length,
                itemBuilder: (context, index) {
                  return _buildResultCard(results[index], filters.query);
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text(AppLocalizations.of(context)?.searchError('$error') ?? 'Search error: $error'),
      ),
    );
  }

  Widget _buildResultCard(AdvancedSearchResult result, String query) {
    final l10n = AppLocalizations.of(context)!;
    final note = result.note;
    final title = note.plainTitle ?? l10n.untitled;
    final time = _formatTime(note.updatedAt);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        title: _highlightText(title, query, fontWeight: FontWeight.bold),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (result.contentPreview.isNotEmpty)
              _highlightText(result.contentPreview, query, maxLines: 2),
            if (result.tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _buildTagChips(result.tags),
              ),
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
        onTap: () => context.push('/notes/${note.id}'),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Text highlighting
  // ---------------------------------------------------------------------------

  /// Highlights occurrences of [query] in [text] using yellow background
  /// and bold weight. Case-insensitive matching.
  Widget _highlightText(
    String text,
    String query, {
    int maxLines = 10,
    FontWeight fontWeight = FontWeight.normal,
  }) {
    if (query.isEmpty || text.isEmpty) {
      return Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontWeight: fontWeight),
      );
    }

    final spans = <TextSpan>[];
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    int start = 0;

    while (start < text.length) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        spans.add(TextSpan(
          text: text.substring(start),
          style: TextStyle(fontWeight: fontWeight),
        ),);
        break;
      }

      if (index > start) {
        spans.add(TextSpan(
          text: text.substring(start, index),
          style: TextStyle(fontWeight: fontWeight),
        ),);
      }

      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: const TextStyle(
          backgroundColor: Colors.yellow,
          fontWeight: FontWeight.bold,
        ),
      ),);

      start = index + query.length;
    }

    return RichText(
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: DefaultTextStyle.of(context).style,
        children: spans,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tag chips for results
  // ---------------------------------------------------------------------------

  Widget _buildTagChips(List<Tag> tags) {
    final displayTags = tags.take(3).toList();
    return Wrap(
      spacing: 4,
      runSpacing: 2,
      children: displayTags.map((tag) {
        return Chip(
          label: Text(
            tag.plainName ?? '...',
            style: const TextStyle(fontSize: 11),
          ),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: EdgeInsets.zero,
          labelPadding: const EdgeInsets.symmetric(horizontal: 6),
        );
      }).toList(),
    );
  }

  // ---------------------------------------------------------------------------
  // Filter dialogs
  // ---------------------------------------------------------------------------

  Future<void> _showDateRangePicker(SearchFilterState filters) async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: filters.dateRange,
    );
    if (range != null && mounted) {
      ref.read(searchFiltersProvider.notifier).setDateRange(range);
    }
  }

  Future<void> _showTagPicker(SearchFilterState filters) async {
    final allTagsAsync = ref.read(allTagsProvider);

    final allTags = allTagsAsync.valueOrNull ?? [];
    if (allTags.isEmpty) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.noTagsAvailable)),
        );
      }
      return;
    }

    final selectedIds = Set<String>.from(filters.selectedTagIds);

    final result = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) => _TagPickerDialog(
        allTags: allTags,
        initialSelected: selectedIds,
      ),
    );

    if (result != null && mounted) {
      ref.read(searchFiltersProvider.notifier).setSelectedTagIds(result);
    }
  }

  Future<void> _showCollectionPicker(SearchFilterState filters) async {
    final allColsAsync = ref.read(allCollectionsProvider);

    final allCols = allColsAsync.valueOrNull ?? [];
    if (allCols.isEmpty) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.noCollectionsAvailable)),
        );
      }
      return;
    }

    final selectedIds = Set<String>.from(filters.selectedCollectionIds);

    final result = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) => _CollectionPickerDialog(
        allCollections: allCols,
        initialSelected: selectedIds,
      ),
    );

    if (result != null && mounted) {
      ref.read(searchFiltersProvider.notifier).setSelectedCollectionIds(result);
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _performSearch(String query) {
    if (query.trim().isNotEmpty) {
      addRecentSearch(query.trim()).then((_) {
        ref.invalidate(recentSearchesProvider);
      });
    }
    // Invalidate the results provider to trigger a new search.
    ref.invalidate(searchResultsProvider);
  }

  String _formatDateRange(DateTimeRange range) {
    // Use locale-aware short date format.
    final start =
        '${range.start.month}/${range.start.day}/${range.start.year}';
    final end = '${range.end.month}/${range.end.day}/${range.end.year}';
    return '$start - $end';
    // TODO(localization): Replace this date range format with a localized
    // format string from .arb files. The M/D/YYYY order is US-centric.
  }

  String _formatTime(DateTime dt) {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return l10n.justNow;
    if (diff.inHours < 1) return l10n.minutesAgo(diff.inMinutes);
    if (diff.inDays < 1) return l10n.hoursAgo(diff.inHours);
    if (diff.inDays < 7) return l10n.daysAgo(diff.inDays);
    if (diff.inDays < 30) {
      // Approximate months for older dates.
      final months = diff.inDays ~/ 30;
      if (months > 0) return l10n.monthsAgo(months);
    }
    return '${dt.month}/${dt.day}';
  }
}

// =============================================================================
// Tag picker dialog
// =============================================================================

class _TagPickerDialog extends StatefulWidget {
  final List<Tag> allTags;
  final Set<String> initialSelected;

  const _TagPickerDialog({
    required this.allTags,
    required this.initialSelected,
  });

  @override
  State<_TagPickerDialog> createState() => _TagPickerDialogState();
}

class _TagPickerDialogState extends State<_TagPickerDialog> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.initialSelected);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.selectTags),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: widget.allTags.length,
          itemBuilder: (context, index) {
            final tag = widget.allTags[index];
            final isSelected = _selected.contains(tag.id);
            return CheckboxListTile(
              value: isSelected,
              title: Text(tag.plainName ?? '...'),
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              onChanged: (checked) {
                setState(() {
                  if (checked == true) {
                    _selected.add(tag.id);
                  } else {
                    _selected.remove(tag.id);
                  }
                });
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selected),
          child: Text(l10n.apply),
        ),
      ],
    );
  }
}

// =============================================================================
// Collection picker dialog
// =============================================================================

class _CollectionPickerDialog extends StatefulWidget {
  final List<Collection> allCollections;
  final Set<String> initialSelected;

  const _CollectionPickerDialog({
    required this.allCollections,
    required this.initialSelected,
  });

  @override
  State<_CollectionPickerDialog> createState() =>
      _CollectionPickerDialogState();
}

class _CollectionPickerDialogState extends State<_CollectionPickerDialog> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.initialSelected);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.selectCollections),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: widget.allCollections.length,
          itemBuilder: (context, index) {
            final col = widget.allCollections[index];
            final isSelected = _selected.contains(col.id);
            return CheckboxListTile(
              value: isSelected,
              title: Text(col.plainTitle ?? '...'),
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              onChanged: (checked) {
                setState(() {
                  if (checked == true) {
                    _selected.add(col.id);
                  } else {
                    _selected.remove(col.id);
                  }
                });
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selected),
          child: Text(l10n.apply),
        ),
      ],
    );
  }
}
