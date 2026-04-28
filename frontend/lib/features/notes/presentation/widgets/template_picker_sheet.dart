import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../main.dart';
import '../../../../core/crypto/crypto_service.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/seed_templates.dart';

/// Callback invoked when the user selects a template.
typedef OnTemplateSelected = void Function(String content);

/// Enhanced bottom sheet for picking a template to create a new note.
///
/// Features:
/// - Search bar at top
/// - Category filter chips (All, Work, Personal, Creative)
/// - "Create from Scratch" card at top
/// - 2-column grid of template cards with name, description preview, category badge
/// - Tap to create note from template, incrementing usage count
/// - Long press for preview/edit (user templates only)
class TemplatePickerSheet extends ConsumerStatefulWidget {
  final OnTemplateSelected onSelected;

  const TemplatePickerSheet({super.key, required this.onSelected});

  @override
  ConsumerState<TemplatePickerSheet> createState() =>
      _TemplatePickerSheetState();
}

class _TemplatePickerSheetState extends ConsumerState<TemplatePickerSheet> {
  List<NoteTemplate> _templates = [];
  bool _isLoading = true;
  bool _isSeeded = false;
  String _searchQuery = '';
  String _categoryFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    final db = ref.read(databaseProvider);

    // Seed built-in templates on first load.
    if (!_isSeeded) {
      await _seedBuiltInTemplates(db);
      _isSeeded = true;
    }

    final templates = await db.templatesDao.getAllTemplates();
    if (!mounted) return;
    setState(() {
      _templates = templates;
      _isLoading = false;
    });
  }

  Future<void> _seedBuiltInTemplates(AppDatabase db) async {
    final existing = await db.templatesDao.getBuiltInTemplates();
    if (existing.isNotEmpty) return;

    for (final template in SeedTemplates.builtIn) {
      final id = const Uuid().v4();
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

  /// Extract preview text from plain content.
  String _preview(String? plainContent) {
    if (plainContent == null || plainContent.isEmpty) return '';
    final lines =
        plainContent.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return '';
    if (lines.length == 1) return lines.first;
    return '${lines[0]}\n${lines[1]}';
  }

  /// Filter templates by search query and category.
  List<NoteTemplate> get _filteredTemplates {
    var filtered = _templates;

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
    final theme = Theme.of(context);

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
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Row(
            children: [
              Text(l10n.templatePicker, style: theme.textTheme.titleLarge),
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

        // Template grid
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.45,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildContent(l10n),
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

  Widget _buildContent(AppLocalizations l10n) {
    final filtered = _filteredTemplates;

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.78,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: filtered.length + 1, // +1 for "Create from Scratch" card
      itemBuilder: (context, index) {
        // "Create from Scratch" card at position 0.
        if (index == 0) {
          return _buildCreateFromScratchCard(l10n);
        }

        final template = filtered[index - 1];
        return _buildTemplateCard(template, l10n);
      },
    );
  }

  Widget _buildCreateFromScratchCard(AppLocalizations l10n) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        widget.onSelected('');
        Navigator.pop(context);
      },
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: theme.colorScheme.primary.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_circle_outline,
                size: 32,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.createFromScratch,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTemplateCard(NoteTemplate template, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final preview = _preview(template.plainContent);
    final catLabel = _categoryLabel(template.category, l10n);
    final catColor = _categoryColor(template.category);

    return GestureDetector(
      onTap: () async {
        final db = ref.read(databaseProvider);
        final nav = Navigator.of(context);
        await db.templatesDao.incrementUsageCount(template.id);
        final resolved = _resolveContent(template.plainContent ?? '');
        widget.onSelected(resolved);
        if (mounted) {
          nav.pop();
        }
      },
      onLongPress: () => _showPreview(template),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: theme.colorScheme.outlineVariant,
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
                    color: theme.colorScheme.primary,
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
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
  }

  /// Show a preview dialog for the template.
  void _showPreview(NoteTemplate template) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(template.name),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Text(
              template.plainContent?.isNotEmpty == true
                  ? template.plainContent!
                  : l10n.noNotesYet,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ),
        actions: [
          if (!template.isBuiltIn)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _showEditDialog(template);
              },
              child: Text(l10n.editTemplate),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              final db = ref.read(databaseProvider);
              final nav = Navigator.of(context);
              await db.templatesDao.incrementUsageCount(template.id);
              final resolved = _resolveContent(template.plainContent ?? '');
              widget.onSelected(resolved);
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
              if (mounted) {
                nav.pop();
              }
            },
            child: Text(l10n.create),
          ),
        ],
      ),
    );
  }

  /// Show edit dialog for a user template.
  void _showEditDialog(NoteTemplate template) {
    final nameController = TextEditingController(text: template.name);
    final descController = TextEditingController(text: template.description);
    final contentController =
        TextEditingController(text: template.plainContent ?? '');
    String selectedCategory = template.category;
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l10n.editTemplate),
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
                if (name.isEmpty) return;

                final db = ref.read(databaseProvider);
                final crypto = ref.read(cryptoServiceProvider);

                String encryptedContent = template.encryptedContent;
                if (crypto.isUnlocked && content.isNotEmpty) {
                  encryptedContent =
                      await crypto.encryptForItem(template.id, content);
                }

                await db.templatesDao.updateTemplate(
                  id: template.id,
                  name: name,
                  description: descController.text.trim().isEmpty
                      ? null
                      : descController.text.trim(),
                  encryptedContent: encryptedContent,
                  plainContent: content,
                  category: selectedCategory,
                );

                if (ctx.mounted) Navigator.pop(ctx);
                await _loadTemplates();
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }
}
