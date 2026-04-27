import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../l10n/app_localizations.dart';
import '../../../main.dart';
import '../../../core/crypto/crypto_service.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/seed_templates.dart';

/// Callback invoked when the user selects a template.
/// Returns the template content with placeholders resolved.
typedef TemplateSelectedCallback = void Function(String content);

/// Shows a bottom sheet with template cards organized by category.
/// Built-in templates appear under "Built-in" tab, user-created ones under
/// "My Templates". Tapping a card invokes [onSelected] with the resolved content.
class TemplatePicker extends ConsumerStatefulWidget {
  final TemplateSelectedCallback onSelected;

  const TemplatePicker({super.key, required this.onSelected});

  @override
  ConsumerState<TemplatePicker> createState() => _TemplatePickerState();
}

class _TemplatePickerState extends ConsumerState<TemplatePicker>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<NoteTemplate> _builtInTemplates = [];
  List<NoteTemplate> _customTemplates = [];
  bool _isLoading = true;
  bool _isSeeded = false;

  // Search and category filter state.
  String _searchQuery = '';
  String _categoryFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTemplates();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTemplates() async {
    final db = ref.read(databaseProvider);

    // Seed built-in templates on first load.
    if (!_isSeeded) {
      await _seedBuiltInTemplates(db);
      _isSeeded = true;
    }

    final builtIn = await db.templatesDao.getBuiltInTemplates();
    final custom = await db.templatesDao.getUserTemplates();

    if (!mounted) return;
    setState(() {
      _builtInTemplates = builtIn;
      _customTemplates = custom;
      _isLoading = false;
    });
  }

  Future<void> _seedBuiltInTemplates(AppDatabase db) async {
    final existing = await db.templatesDao.getBuiltInTemplates();
    if (existing.isNotEmpty) return;

    for (final template in SeedTemplates.builtIn) {
      final id = const Uuid().v4();
      // Built-in templates use their plain content directly as the encrypted
      // content field (they are not user secrets and need no per-item key).
      await db.templatesDao.createTemplate(
        id: id,
        name: template.name,
        description: template.description,
        encryptedContent: template.content,
        plainContent: template.content,
        category: template.category,
        isBuiltIn: true,
      );
    }
  }

  /// Resolve {{date}} placeholder with the current date.
  String _resolveContent(String content) {
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return content.replaceAll('{{date}}', dateStr);
  }

  /// Extract the first two non-empty lines for a preview.
  String _preview(String? plainContent) {
    if (plainContent == null || plainContent.isEmpty) return '';
    final lines =
        plainContent.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return '';
    if (lines.length == 1) return lines.first;
    return '${lines[0]}\n${lines[1]}';
  }

  /// Filter templates by search query and category.
  List<NoteTemplate> _filterTemplates(List<NoteTemplate> templates) {
    var filtered = templates;

    if (_categoryFilter != 'all') {
      filtered = filtered.where((t) => t.category == _categoryFilter).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final lower = _searchQuery.toLowerCase();
      filtered = filtered.where((t) {
        final nameMatch = t.name.toLowerCase().contains(lower);
        final descMatch = (t.description ?? '').toLowerCase().contains(lower);
        return nameMatch || descMatch;
      }).toList();
    }

    return filtered;
  }

  /// Category color for badges.
  Color _categoryColor(String category) {
    switch (category) {
      case 'work':
        return Colors.blue;
      case 'personal':
        return Colors.green;
      case 'creative':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  /// Category display name from l10n.
  String _categoryLabel(String category, AppLocalizations l10n) {
    switch (category) {
      case 'work':
        return l10n.categoryWork;
      case 'personal':
        return l10n.categoryPersonal;
      case 'creative':
        return l10n.categoryCreative;
      default:
        return category;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
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
              Text(
                l10n.templatePicker,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),

        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            decoration: InputDecoration(
              hintText: l10n.searchNotes,
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value);
            },
          ),
        ),

        // Category filter chips
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            children: [
              _buildCategoryChip('all', l10n.all),
              const SizedBox(width: 6),
              _buildCategoryChip('work', l10n.categoryWork),
              const SizedBox(width: 6),
              _buildCategoryChip('personal', l10n.categoryPersonal),
              const SizedBox(width: 6),
              _buildCategoryChip('creative', l10n.categoryCreative),
            ],
          ),
        ),

        // Tabs
        TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.builtInTab),
            Tab(text: l10n.myTemplatesTab),
          ],
        ),

        const SizedBox(height: 8),

        // Tab content
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.40,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTemplateGrid(
                      _filterTemplates(_builtInTemplates),
                      canDelete: false,
                    ),
                    _buildCustomTemplatesTab(),
                  ],
                ),
        ),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildCategoryChip(String value, String label) {
    final isSelected = _categoryFilter == value;
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _categoryFilter = value);
      },
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildTemplateGrid(
    List<NoteTemplate> templates, {
    required bool canDelete,
  }) {
    final l10n = AppLocalizations.of(context)!;

    if (templates.isEmpty) {
      return Center(
        child: Text(
          l10n.noTemplates,
          style: TextStyle(color: Colors.grey.shade500),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.80,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: templates.length,
      itemBuilder: (context, index) {
        final template = templates[index];
        final preview = _preview(template.plainContent);
        final catLabel = _categoryLabel(template.category, l10n);
        final catColor = _categoryColor(template.category);

        return GestureDetector(
          onTap: () async {
            final db = ref.read(databaseProvider);
            await db.templatesDao.incrementUsageCount(template.id);
            final resolved = _resolveContent(template.plainContent ?? '');
            widget.onSelected(resolved);
            if (context.mounted) Navigator.pop(context);
          },
          onLongPress: canDelete ? () => _confirmDelete(template) : null,
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        template.isBuiltIn
                            ? Icons.bookmark_outlined
                            : Icons.description_outlined,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          template.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (template.description != null &&
                      template.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      template.description!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  // Category badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: catColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      catLabel,
                      style: TextStyle(
                        fontSize: 10,
                        color: catColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Text(
                      preview,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCustomTemplatesTab() {
    return Column(
      children: [
        Expanded(
          child: _buildTemplateGrid(
            _filterTemplates(_customTemplates),
            canDelete: true,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showCreateTemplateDialog,
              icon: const Icon(Icons.add),
              label: Text(AppLocalizations.of(context)!.newTemplate),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  void _confirmDelete(NoteTemplate template) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteTemplate),
        content: Text(l10n.deleteTemplateMessage(template.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              final db = ref.read(databaseProvider);
              await db.templatesDao.deleteTemplate(template.id);
              if (ctx.mounted) Navigator.pop(ctx);
              await _loadTemplates();
            },
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  void _showCreateTemplateDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final contentController = TextEditingController();
    String selectedCategory = 'personal';
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l10n.newTemplate),
          content: SizedBox(
            width: MediaQuery.of(ctx).size.width * 0.85,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: l10n.templateName,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    decoration: InputDecoration(
                      labelText: l10n.templateDescription,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Category selector
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    decoration: InputDecoration(
                      labelText: l10n.templateCategory,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'work',
                        child: Text(l10n.categoryWork),
                      ),
                      DropdownMenuItem(
                        value: 'personal',
                        child: Text(l10n.categoryPersonal),
                      ),
                      DropdownMenuItem(
                        value: 'creative',
                        child: Text(l10n.categoryCreative),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedCategory = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contentController,
                    decoration: InputDecoration(
                      labelText: l10n.templateContent,
                      hintText: l10n.templateDateHint,
                      border: const OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 8,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final content = contentController.text.trim();
                if (name.isEmpty || content.isEmpty) return;

                final db = ref.read(databaseProvider);
                final crypto = ref.read(cryptoServiceProvider);
                final id = const Uuid().v4();

                String encryptedContent;
                if (crypto.isUnlocked) {
                  encryptedContent = await crypto.encryptForItem(id, content);
                } else {
                  encryptedContent = content;
                }

                await db.templatesDao.createTemplate(
                  id: id,
                  name: name,
                  description: descController.text.trim().isEmpty
                      ? null
                      : descController.text.trim(),
                  encryptedContent: encryptedContent,
                  plainContent: content,
                  category: selectedCategory,
                  isBuiltIn: false,
                );

                if (ctx.mounted) Navigator.pop(ctx);
                await _loadTemplates();
              },
              child: Text(l10n.create),
            ),
          ],
        ),
      ),
    );
  }
}
