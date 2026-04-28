import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/app_database.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart';
import '../data/search_providers.dart';
import '../../notes/domain/search_query_parser.dart';

class AdvancedSearchScreen extends ConsumerStatefulWidget {
  const AdvancedSearchScreen({super.key});

  @override
  ConsumerState<AdvancedSearchScreen> createState() =>
      _AdvancedSearchScreenState();
}

class _AdvancedSearchScreenState extends ConsumerState<AdvancedSearchScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  late final TabController _tabController;
  Timer? _debounceTimer;
  bool _showHints = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Auto-focus the search field.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final query = ref.watch(operatorSearchQueryProvider);
    final hasActiveSearch = query.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.search),
        actions: [
          if (hasActiveSearch)
            IconButton(
              icon: const Icon(Icons.clear_all),
              tooltip: l10n.clearAllFilters,
              onPressed: () {
                _searchController.clear();
                ref.read(operatorSearchQueryProvider.notifier).state = '';
              },
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.search),
            Tab(text: l10n.savedSearches),
            Tab(text: l10n.searchHistory),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Search with operators.
          _buildSearchTab(l10n, hasActiveSearch),
          // Tab 2: Saved searches.
          _buildSavedSearchesTab(l10n),
          // Tab 3: Search history.
          _buildHistoryTab(l10n),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 1: Search
  // ---------------------------------------------------------------------------

  Widget _buildSearchTab(AppLocalizations l10n, bool hasActiveSearch) {
    return Column(
      children: [
        // Search text field.
        _buildSearchField(l10n),

        // Operator hints (collapsible).
        _buildHintsToggle(l10n),

        // Body: results or empty state.
        Expanded(
          child: hasActiveSearch
              ? _buildOperatorResultsBody(l10n)
              : _buildEmptySearchBody(l10n),
        ),
      ],
    );
  }

  Widget _buildSearchField(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        decoration: InputDecoration(
          hintText: l10n.searchNotesHint,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_searchController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    ref.read(operatorSearchQueryProvider.notifier).state = '';
                  },
                ),
              // Save search button.
              IconButton(
                icon: const Icon(Icons.bookmark_add_outlined),
                tooltip: l10n.saveSearch,
                onPressed: _searchController.text.trim().isEmpty
                    ? null
                    : () => _showSaveSearchDialog(l10n),
              ),
            ],
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          filled: true,
        ),
        onChanged: (value) {
          // Debounce the search by 300ms.
          _debounceTimer?.cancel();
          _debounceTimer = Timer(const Duration(milliseconds: 300), () {
            ref.read(operatorSearchQueryProvider.notifier).state = value;
          });
          // Rebuild to toggle the clear/save buttons.
          setState(() {});
        },
        onSubmitted: (value) {
          ref.read(operatorSearchQueryProvider.notifier).state = value;
        },
      ),
    );
  }

  Widget _buildHintsToggle(AppLocalizations l10n) {
    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _showHints = !_showHints),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  _showHints ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  _showHints ? l10n.hideSearchHints : l10n.showSearchHints,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_showHints) _buildHintsContent(l10n),
      ],
    );
  }

  Widget _buildHintsContent(AppLocalizations l10n) {
    final hints = [
      l10n.searchOperatorTag,
      l10n.searchOperatorStatus,
      l10n.searchOperatorPriority,
      l10n.searchOperatorDate,
      l10n.searchOperatorCollection,
      l10n.searchOperatorLinks,
      l10n.searchOperatorColor,
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.searchOperators,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          ...hints.map(
            (hint) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                hint,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.searchOperatorsExample,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySearchBody(AppLocalizations l10n) {
    return EmptyState(
      icon: Icons.search,
      title: l10n.searchYourNotes,
      subtitle: l10n.enterQueryOrOperators,
    );
  }

  Widget _buildOperatorResultsBody(AppLocalizations l10n) {
    final resultsAsync = ref.watch(operatorSearchResultsProvider);

    return resultsAsync.when(
      data: (results) {
        if (results.isEmpty) {
          return EmptyState(
            icon: Icons.search_off,
            title: l10n.noResultsFound,
            subtitle: l10n.tryAdjustingSearch,
          );
        }

        return Column(
          children: [
            // Results count header.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.resultsCount('${results.length}'),
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
                  return _buildOperatorResultCard(results[index]);
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text(l10n.searchError('$error')),
      ),
    );
  }

  Widget _buildOperatorResultCard(OperatorSearchResult result) {
    final l10n = AppLocalizations.of(context)!;
    final note = result.note;
    final title = note.plainTitle ?? l10n.untitled;
    final time = _formatTime(note.updatedAt);
    final query = ref.read(operatorSearchQueryProvider);
    // Extract only the full-text portion for highlighting.
    final parsed = parseSearchQuery(query);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        title: _highlightText(
          title,
          parsed.fullTextQuery,
          fontWeight: FontWeight.bold,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (result.contentSnippet.isNotEmpty)
              _highlightSnippet(result.contentSnippet, parsed.fullTextQuery),
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
  // Tab 2: Saved Searches
  // ---------------------------------------------------------------------------

  Widget _buildSavedSearchesTab(AppLocalizations l10n) {
    final savedAsync = ref.watch(savedSearchesProvider);

    return savedAsync.when(
      data: (saved) {
        if (saved.isEmpty) {
          return EmptyState(
            icon: Icons.bookmark_outline,
            title: l10n.noSavedSearches,
            subtitle: l10n.saveSearchHint,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: saved.length,
          itemBuilder: (context, index) {
            final search = saved[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                leading: const Icon(Icons.bookmark),
                title: Text(search.name),
                subtitle: Text(
                  search.query,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  tooltip: l10n.deleteSavedSearch,
                  onPressed: () => _deleteSavedSearch(search),
                ),
                onTap: () {
                  _searchController.text = search.query;
                  ref.read(operatorSearchQueryProvider.notifier).state =
                      search.query;
                  _tabController.animateTo(0);
                },
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => EmptyState(
        icon: Icons.error_outline,
        title: l10n.noSavedSearches,
        subtitle: '',
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 3: Search History
  // ---------------------------------------------------------------------------

  Widget _buildHistoryTab(AppLocalizations l10n) {
    final recentAsync = ref.watch(recentSearchesProvider);

    return recentAsync.when(
      data: (recent) {
        if (recent.isEmpty) {
          return EmptyState(
            icon: Icons.history,
            title: l10n.noSearchHistory,
            subtitle: '',
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
                    l10n.searchHistory,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await clearRecentSearches();
                      ref.invalidate(recentSearchesProvider);
                    },
                    child: Text(l10n.clearSearchHistory),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: recent.length,
                itemBuilder: (context, index) {
                  final query = recent[index];
                  return ListTile(
                    leading: const Icon(Icons.history, size: 20),
                    title: Text(
                      query,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        // ignore: unnecessary_non_null_assertion
                        final existing =
                            prefs.getStringList('recent_searches')!;
                        existing.remove(query);
                        await prefs.setStringList('recent_searches', existing);
                        ref.invalidate(recentSearchesProvider);
                      },
                    ),
                    onTap: () {
                      _searchController.text = query;
                      ref.read(operatorSearchQueryProvider.notifier).state =
                          query;
                      _tabController.animateTo(0);
                    },
                  );
                },
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
  // Save Search Dialog
  // ---------------------------------------------------------------------------

  Future<void> _showSaveSearchDialog(AppLocalizations l10n) async {
    final nameController = TextEditingController();
    final query = _searchController.text.trim();

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.saveSearch),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: l10n.saveSearchName,
            hintText: query,
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(nameController.text.trim()),
            child: Text(l10n.save),
          ),
        ],
      ),
    );

    nameController.dispose();

    if (result != null && mounted) {
      final name = result.isEmpty ? query : result;
      final db = ref.read(databaseProvider);
      await db.savedSearchesDao.create(name: name, query: query);
      if (mounted) {
        AppSnackBar.info(context, message: l10n.searchSaved);
      }
    }
  }

  Future<void> _deleteSavedSearch(SavedSearch search) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteSavedSearch),
        content: Text(l10n.deleteSavedSearchConfirm(search.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final db = ref.read(databaseProvider);
      await db.savedSearchesDao.deleteSearch(search.id);
    }
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
        spans.add(
          TextSpan(
            text: text.substring(start),
            style: TextStyle(fontWeight: fontWeight),
          ),
        );
        break;
      }

      if (index > start) {
        spans.add(
          TextSpan(
            text: text.substring(start, index),
            style: TextStyle(fontWeight: fontWeight),
          ),
        );
      }

      spans.add(
        TextSpan(
          text: text.substring(index, index + query.length),
          style: TextStyle(
            backgroundColor: Theme.of(context)
                .colorScheme
                .primaryContainer
                .withValues(alpha: 0.4),
            fontWeight: FontWeight.bold,
          ),
        ),
      );

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

  /// Renders a snippet that may contain ** markers from FTS5 highlight()
  /// as bold styled text.
  Widget _highlightSnippet(String snippet, String query) {
    if (snippet.isEmpty) return const SizedBox.shrink();

    // If the snippet has FTS5 ** markers, parse them for bold display.
    if (snippet.contains('**')) {
      return _buildRichSnippet(snippet, maxLines: 2);
    }

    // Otherwise do manual highlighting.
    return _highlightText(snippet, query, maxLines: 2);
  }

  /// Parses a string with **markers** into a RichText widget.
  Widget _buildRichSnippet(String text, {int maxLines = 2}) {
    final spans = <TextSpan>[];
    final parts = text.split('**');

    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      if (i.isOdd) {
        // Odd indices are between ** markers -- highlighted text.
        spans.add(
          TextSpan(
            text: parts[i],
            style: TextStyle(
              fontWeight: FontWeight.bold,
              backgroundColor: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: 0.4),
            ),
          ),
        );
      } else {
        spans.add(
          TextSpan(text: parts[i]),
        );
      }
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
  // Helpers
  // ---------------------------------------------------------------------------

  String _formatTime(DateTime dt) {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return l10n.justNow;
    if (diff.inHours < 1) return l10n.minutesAgo(diff.inMinutes);
    if (diff.inDays < 1) return l10n.hoursAgo(diff.inHours);
    if (diff.inDays < 7) return l10n.daysAgo(diff.inDays);
    if (diff.inDays < 30) {
      final months = diff.inDays ~/ 30;
      if (months > 0) return l10n.monthsAgo(months);
    }
    return '${dt.month}/${dt.day}';
  }
}
