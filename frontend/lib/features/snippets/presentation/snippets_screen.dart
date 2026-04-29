import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/snippets_dao.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart';
import 'snippet_detail_sheet.dart';
import 'snippet_editor_sheet.dart';

/// Provider that exposes the SnippetsDao from the global database.
final snippetsDaoProvider = Provider<SnippetsDao>((ref) {
  final db = ref.read(databaseProvider);
  return SnippetsDao(db);
});

/// Reactive stream of all snippets, ordered by most recently updated.
final allSnippetsProvider = StreamProvider<List<Snippet>>((ref) {
  final dao = ref.read(snippetsDaoProvider);
  return dao.watchAllSnippets();
});

/// Screen that lists all code snippets with search and filtering.
class SnippetsScreen extends ConsumerStatefulWidget {
  const SnippetsScreen({super.key});

  @override
  ConsumerState<SnippetsScreen> createState() => _SnippetsScreenState();
}

class _SnippetsScreenState extends ConsumerState<SnippetsScreen> {
  String _searchQuery = '';
  String? _languageFilter;
  String? _categoryFilter;

  List<String> _availableLanguages = [];
  List<String> _availableCategories = [];

  @override
  void initState() {
    super.initState();
    _loadFilters();
  }

  Future<void> _loadFilters() async {
    final dao = ref.read(snippetsDaoProvider);
    final languages = await dao.getAllLanguages();
    final categories = await dao.getAllCategories();
    if (mounted) {
      setState(() {
        _availableLanguages = languages;
        _availableCategories = categories;
      });
    }
  }

  List<Snippet> _applyFilters(List<Snippet> snippets) {
    var result = snippets;

    if (_searchQuery.isNotEmpty) {
      final lower = _searchQuery.toLowerCase();
      result = result
          .where(
            (s) =>
                s.title.toLowerCase().contains(lower) ||
                s.language.toLowerCase().contains(lower) ||
                s.category.toLowerCase().contains(lower) ||
                s.tags.toLowerCase().contains(lower) ||
                s.code.toLowerCase().contains(lower),
          )
          .toList();
    }

    if (_languageFilter != null) {
      result = result.where((s) => s.language == _languageFilter).toList();
    }

    if (_categoryFilter != null) {
      result = result.where((s) => s.category == _categoryFilter).toList();
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final snippetsAsync = ref.watch(allSnippetsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.snippets),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.newSnippet,
            onPressed: () => _showEditor(context),
          ),
        ],
      ),
      body: Column(
        children: [
          _SnippetsFilterBar(
            searchQuery: _searchQuery,
            onSearchChanged: (v) => setState(() => _searchQuery = v),
            languageFilter: _languageFilter,
            onLanguageChanged: (v) => setState(() => _languageFilter = v),
            categoryFilter: _categoryFilter,
            onCategoryChanged: (v) => setState(() => _categoryFilter = v),
            availableLanguages: _availableLanguages,
            availableCategories: _availableCategories,
            l10n: l10n,
          ),
          const Divider(height: 1),
          Expanded(
            child: _SnippetsListBody(
              snippetsAsync: snippetsAsync,
              filterFn: _applyFilters,
              onSnippetTap: _showDetail,
              onSnippetLongPress: _showContextMenu,
              theme: theme,
              l10n: l10n,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditor(context),
        tooltip: l10n.newSnippet,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showEditor(BuildContext context, {Snippet? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SnippetEditorSheet(
        existing: existing,
        onSave: (companion) async {
          final dao = ref.read(snippetsDaoProvider);
          if (existing == null) {
            await dao.insertSnippet(companion);
          } else {
            await dao.updateSnippet(companion);
          }
          _loadFilters();
        },
      ),
    );
  }

  void _showDetail(BuildContext context, Snippet snippet) {
    final dao = ref.read(snippetsDaoProvider);
    dao.incrementUsageCount(snippet.id);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SnippetDetailSheet(
        snippet: snippet,
        onEdit: () {
          Navigator.pop(context);
          _showEditor(context, existing: snippet);
        },
        onDelete: () async {
          final dao = ref.read(snippetsDaoProvider);
          await dao.deleteSnippet(snippet.id);
          if (mounted && context.mounted) {
            Navigator.pop(context);
            _loadFilters();
          }
        },
      ),
    );
  }

  void _showContextMenu(BuildContext context, Snippet snippet) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(l10n.editSnippet),
              onTap: () {
                Navigator.pop(context);
                _showEditor(context, existing: snippet);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: Text(l10n.copyCode),
              onTap: () {
                Clipboard.setData(ClipboardData(text: snippet.code));
                Navigator.pop(context);
                AppSnackBar.info(context, message: l10n.codeCopied);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: Text(
                l10n.deleteSnippet,
                style: const TextStyle(color: Colors.red),
              ),
              onTap: () async {
                Navigator.pop(context);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(l10n.deleteSnippet),
                    content: Text(l10n.deleteSnippetConfirm),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(l10n.cancel),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(l10n.delete),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  final dao = ref.read(snippetsDaoProvider);
                  await dao.deleteSnippet(snippet.id);
                  _loadFilters();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Search bar and language/category filter row.
class _SnippetsFilterBar extends StatelessWidget {
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final String? languageFilter;
  final ValueChanged<String?> onLanguageChanged;
  final String? categoryFilter;
  final ValueChanged<String?> onCategoryChanged;
  final List<String> availableLanguages;
  final List<String> availableCategories;
  final AppLocalizations l10n;

  const _SnippetsFilterBar({
    required this.searchQuery,
    required this.onSearchChanged,
    required this.languageFilter,
    required this.onLanguageChanged,
    required this.categoryFilter,
    required this.onCategoryChanged,
    required this.availableLanguages,
    required this.availableCategories,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            decoration: InputDecoration(
              hintText: l10n.searchSnippets,
              prefixIcon: const Icon(Icons.search, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              isDense: true,
            ),
            onChanged: onSearchChanged,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: DropdownButton<String>(
                  value: languageFilter,
                  hint: Text(l10n.allLanguages,
                      style: const TextStyle(fontSize: 13),),
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  items: [
                    DropdownMenuItem<String>(
                      value: null,
                      child: Text(l10n.allLanguages),
                    ),
                    ...availableLanguages.map(
                      (lang) => DropdownMenuItem(
                        value: lang,
                        child: Text(lang, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: onLanguageChanged,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<String>(
                  value: categoryFilter,
                  hint: Text(l10n.allCategories,
                      style: const TextStyle(fontSize: 13),),
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  items: [
                    DropdownMenuItem<String>(
                      value: null,
                      child: Text(l10n.allCategories),
                    ),
                    ...availableCategories.map(
                      (cat) => DropdownMenuItem(
                        value: cat,
                        child: Text(cat, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: onCategoryChanged,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Async-aware snippet list with empty state.
class _SnippetsListBody extends StatelessWidget {
  final AsyncValue<List<Snippet>> snippetsAsync;
  final List<Snippet> Function(List<Snippet>) filterFn;
  final void Function(BuildContext, Snippet) onSnippetTap;
  final void Function(BuildContext, Snippet) onSnippetLongPress;
  final ThemeData theme;
  final AppLocalizations l10n;

  const _SnippetsListBody({
    required this.snippetsAsync,
    required this.filterFn,
    required this.onSnippetTap,
    required this.onSnippetLongPress,
    required this.theme,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return snippetsAsync.when(
      data: (snippets) {
        final filtered = filterFn(snippets);
        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.code_off_outlined,
                    size: 64, color: theme.disabledColor,),
                const SizedBox(height: 16),
                Text(
                  l10n.noSnippets,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: theme.disabledColor),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final snippet = filtered[index];
            return _SnippetCard(
              snippet: snippet,
              onTap: () => onSnippetTap(context, snippet),
              onLongPress: () => onSnippetLongPress(context, snippet),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text(error.toString())),
    );
  }
}

/// A single card displaying a snippet's summary.
class _SnippetCard extends StatelessWidget {
  final Snippet snippet;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _SnippetCard({
    required this.snippet,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final codePreview = _buildCodePreview(snippet.code);

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    snippet.title,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (snippet.language.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      snippet.language,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Text(
                  l10n.usageCount(snippet.usageCount),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.disabledColor),
                ),
              ],
            ),
            if (snippet.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                snippet.description,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                codePreview,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Extract the first few non-empty lines for a preview.
  String _buildCodePreview(String code) {
    final lines = code.split('\n').where((l) => l.trim().isNotEmpty).toList();
    return lines.take(3).join('\n');
  }
}
