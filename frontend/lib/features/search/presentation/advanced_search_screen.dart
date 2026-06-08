import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart';
import '../../notes/domain/search_query_parser.dart';
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
  Timer? _debounceTimer;
  bool _showHints = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final query = ref.watch(operatorSearchQueryProvider);
    final hasActiveSearch = query.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.search),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
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
      ),
      body: Column(
        children: [
          _buildSearchBar(l10n),
          Expanded(
            child: hasActiveSearch
                ? _buildResults(l10n)
                : _buildIdleState(l10n),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Search bar
  // ---------------------------------------------------------------------------

  Widget _buildSearchBar(AppLocalizations l10n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.s8, AppSpacing.md, AppSpacing.s4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBg : AppColors.lightCardBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.smOf(Theme.of(context).brightness),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        decoration: InputDecoration(
          hintText: l10n.searchNotesHint,
          hintStyle: AppTextStyles.body.copyWith(
            color: isDark
                ? AppColors.darkTextTertiary
                : AppColors.lightTextTertiary,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: isDark
                ? AppColors.darkTextTertiary
                : AppColors.lightTextTertiary,
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_searchController.text.isNotEmpty)
                IconButton(
                  icon: Icon(
                    Icons.clear,
                    size: 20,
                    color: isDark
                        ? AppColors.darkTextTertiary
                        : AppColors.lightTextTertiary,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    ref.read(operatorSearchQueryProvider.notifier).state = '';
                  },
                ),
              IconButton(
                icon: Icon(
                  Icons.bookmark_add_outlined,
                  size: 20,
                  color: _searchController.text.trim().isEmpty
                      ? (isDark
                          ? AppColors.darkDisabled
                          : AppColors.lightDisabled)
                      : AppColors.primary,
                ),
                tooltip: l10n.saveSearch,
                onPressed: _searchController.text.trim().isEmpty
                    ? null
                    : () => _showSaveSearchDialog(l10n),
              ),
            ],
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s16,
            vertical: AppSpacing.s12,
          ),
        ),
        onChanged: (value) {
          _debounceTimer?.cancel();
          _debounceTimer = Timer(const Duration(milliseconds: 300), () {
            ref.read(operatorSearchQueryProvider.notifier).state = value;
          });
          setState(() {});
        },
        onSubmitted: (value) {
          ref.read(operatorSearchQueryProvider.notifier).state = value;
        },
        scrollPadding: const EdgeInsets.only(bottom: 120),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Idle state: hints toggle + recent searches + saved searches
  // ---------------------------------------------------------------------------

  Widget _buildIdleState(AppLocalizations l10n) {
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      children: [
        // Operator hints
        _buildHintsSection(l10n),
        const SizedBox(height: AppSpacing.md),
        // Recent searches
        _buildRecentSection(l10n),
        const SizedBox(height: AppSpacing.md),
        // Saved searches
        _buildSavedSection(l10n),
      ],
    );
  }

  Widget _buildHintsSection(AppLocalizations l10n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _showHints = !_showHints),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.s8,
              AppSpacing.md,
              AppSpacing.s4,
            ),
            child: Row(
              children: [
                AnimatedRotation(
                  turns: _showHints ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.expand_more,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                Text(
                  _showHints ? l10n.hideSearchHints : l10n.showSearchHints,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_showHints)
          Container(
            margin: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.s4,
            ),
            padding: const EdgeInsets.all(AppSpacing.s12),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkInputFill
                  : AppColors.lightInputFill,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHintChip(l10n.searchOperatorTag, isDark),
                _buildHintChip(l10n.searchOperatorStatus, isDark),
                _buildHintChip(l10n.searchOperatorPriority, isDark),
                _buildHintChip(l10n.searchOperatorDate, isDark),
                _buildHintChip(l10n.searchOperatorCollection, isDark),
                _buildHintChip(l10n.searchOperatorLinks, isDark),
                _buildHintChip(l10n.searchOperatorColor, isDark),
                const SizedBox(height: AppSpacing.s4),
                Text(
                  l10n.searchOperatorsExample,
                  style: AppTextStyles.caption.copyWith(
                    color: isDark
                        ? AppColors.darkTextTertiary
                        : AppColors.lightTextTertiary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildHintChip(String hint, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primary.withAlpha(12),
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
        child: Text(
          hint,
          style: AppTextStyles.caption.copyWith(
            fontSize: 12,
            fontFamily: 'monospace',
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildRecentSection(AppLocalizations l10n) {
    final recentAsync = ref.watch(recentSearchesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return recentAsync.when(
      data: (recent) {
        if (recent.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.s8,
                AppSpacing.md,
                AppSpacing.s4,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.history,
                    size: 16,
                    color: isDark
                        ? AppColors.darkTextTertiary
                        : AppColors.lightTextTertiary,
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Text(
                    l10n.searchHistory,
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.darkTextTertiary
                          : AppColors.lightTextTertiary,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () async {
                      await clearRecentSearches();
                      ref.invalidate(recentSearchesProvider);
                    },
                    child: Text(
                      l10n.clearSearchHistory,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Wrap(
                spacing: AppSpacing.s8,
                runSpacing: AppSpacing.s8,
                children: recent.take(8).map((query) {
                  return _buildRecentChip(query, l10n, isDark);
                }).toList(),
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildRecentChip(String query, AppLocalizations l10n, bool isDark) {
    return GestureDetector(
      onTap: () {
        _searchController.text = query;
        ref.read(operatorSearchQueryProvider.notifier).state = query;
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s12,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkInputFill : AppColors.lightInputFill,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                query,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 13,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s4),
            GestureDetector(
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                final existing = prefs.getStringList('recent_searches') ?? [];
                existing.remove(query);
                await prefs.setStringList('recent_searches', existing);
                ref.invalidate(recentSearchesProvider);
              },
              child: Icon(
                Icons.close,
                size: 14,
                color: isDark
                    ? AppColors.darkTextTertiary
                    : AppColors.lightTextTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedSection(AppLocalizations l10n) {
    final savedAsync = ref.watch(savedSearchesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return savedAsync.when(
      data: (saved) {
        if (saved.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.s12,
                AppSpacing.md,
                AppSpacing.s4,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.bookmark_outline,
                    size: 16,
                    color: isDark
                        ? AppColors.darkTextTertiary
                        : AppColors.lightTextTertiary,
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Text(
                    l10n.savedSearches,
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.darkTextTertiary
                          : AppColors.lightTextTertiary,
                    ),
                  ),
                ],
              ),
            ),
            ...saved.map((search) => _buildSavedCard(search, l10n, isDark)),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildSavedCard(
    SavedSearch search,
    AppLocalizations l10n,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.s4,
        AppSpacing.md,
        AppSpacing.s4,
      ),
      child: GestureDetector(
        onTap: () {
          _searchController.text = search.query;
          ref.read(operatorSearchQueryProvider.notifier).state = search.query;
        },
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.s12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCardBg : AppColors.lightCardBg,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: AppShadows.smOf(Theme.of(context).brightness),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(15),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: const Icon(
                  Icons.bookmark,
                  size: 16,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      search.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      search.query,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: isDark
                            ? AppColors.darkTextTertiary
                            : AppColors.lightTextTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _deleteSavedSearch(search),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.error.withAlpha(12),
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                  child: const Icon(
                    Icons.delete_outline,
                    size: 14,
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Results
  // ---------------------------------------------------------------------------

  Widget _buildResults(AppLocalizations l10n) {
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
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.s8,
                AppSpacing.md,
                AppSpacing.s4,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.resultsCount('${results.length}'),
                  style: AppTextStyles.caption.copyWith(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.darkTextTertiary
                        : AppColors.lightTextTertiary,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                itemCount: results.length,
                itemBuilder: (context, index) {
                  return _buildResultCard(results[index], l10n, index);
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text(l10n.searchError('$error'))),
    );
  }

  Widget _buildResultCard(
    OperatorSearchResult result,
    AppLocalizations l10n,
    int index,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final note = result.note;
    final title = note.plainTitle ?? l10n.untitled;
    final time = _formatTime(note.updatedAt);
    final query = ref.read(operatorSearchQueryProvider);
    final parsed = parseSearchQuery(query);

    // Warm pastel cycling for result cards
    const pastels = AppColors.notePastels;
    final pastelBg = pastels[index % pastels.length];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.s4,
        AppSpacing.md,
        AppSpacing.s4,
      ),
      child: GestureDetector(
        onTap: () => context.push('/notes/${note.id}'),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.s12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCardBg : AppColors.lightCardBg,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: AppShadows.smOf(Theme.of(context).brightness),
            border: Border(
              left: BorderSide(
                color: pastelBg,
                width: 3,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row
              Row(
                children: [
                  Expanded(
                    child: _highlightText(
                      title,
                      parsed.fullTextQuery,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    time,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.darkTextTertiary
                          : AppColors.lightTextTertiary,
                    ),
                  ),
                ],
              ),
              // Content snippet
              if (result.contentSnippet.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.s4),
                _highlightSnippet(result.contentSnippet, parsed.fullTextQuery),
              ],
              // Tags + rank
              if (result.tags.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.s8),
                _buildTagChips(result.tags, isDark),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Save / Delete dialogs
  // ---------------------------------------------------------------------------

  Future<void> _showSaveSearchDialog(AppLocalizations l10n) async {
    final nameController = TextEditingController();
    final query = _searchController.text.trim();

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text(l10n.saveSearch),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: l10n.saveSearchName,
            hintText: query,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ),
          autofocus: true,
          scrollPadding: const EdgeInsets.only(bottom: 120),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(ctx).pop(nameController.text.trim()),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text(l10n.deleteSavedSearch),
        content: Text(
          l10n.deleteSavedSearchConfirm(search.name),
          style: AppTextStyles.body,
        ),
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
        style: AppTextStyles.body.copyWith(fontWeight: fontWeight),
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
          style: const TextStyle(
            backgroundColor: AppColors.accentYellowBg,
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

  Widget _highlightSnippet(String snippet, String query) {
    if (snippet.isEmpty) return const SizedBox.shrink();

    if (snippet.contains('**')) {
      return _buildRichSnippet(snippet, maxLines: 2);
    }

    return _highlightText(snippet, query, maxLines: 2);
  }

  Widget _buildRichSnippet(String text, {int maxLines = 2}) {
    final spans = <TextSpan>[];
    final parts = text.split('**');

    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      if (i.isOdd) {
        spans.add(
          TextSpan(
            text: parts[i],
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              backgroundColor: AppColors.accentYellowBg,
            ),
          ),
        );
      } else {
        spans.add(TextSpan(text: parts[i]));
      }
    }

    return RichText(
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: DefaultTextStyle.of(context).style.copyWith(
              fontSize: 13,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
        children: spans,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tag chips for results
  // ---------------------------------------------------------------------------

  Widget _buildTagChips(List<Tag> tags, bool isDark) {
    final displayTags = tags.take(3).toList();
    final accentBgs = [
      AppColors.accentPeachBg,
      AppColors.accentYellowBg,
      AppColors.accentMintBg,
      AppColors.accentPeachBg,
    ];
    final accentTexts = [
      AppColors.accentPeachText,
      AppColors.accentYellowText,
      AppColors.accentMintText,
      AppColors.accentPeachText,
    ];

    return Wrap(
      spacing: AppSpacing.s4,
      runSpacing: AppSpacing.s4,
      children: displayTags.asMap().entries.map((entry) {
        final i = entry.key;
        final tag = entry.value;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: accentBgs[i % accentBgs.length],
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            tag.plainName ?? '...',
            style: AppTextStyles.caption.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: accentTexts[i % accentTexts.length],
            ),
          ),
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
