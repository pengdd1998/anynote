import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../main.dart';
import '../../../../core/crypto/crypto_service.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/widgets/app_snackbar.dart';

/// Full-screen template management page.
///
/// Lists all templates (built-in + user) with edit, create, delete, and
/// duplicate operations. Accessible via /settings/templates route.
class TemplateManagementScreen extends ConsumerStatefulWidget {
  const TemplateManagementScreen({super.key});

  @override
  ConsumerState<TemplateManagementScreen> createState() =>
      _TemplateManagementScreenState();
}

class _TemplateManagementScreenState
    extends ConsumerState<TemplateManagementScreen> {
  List<NoteTemplate> _builtInTemplates = [];
  List<NoteTemplate> _userTemplates = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    final db = ref.read(databaseProvider);
    final builtIn = await db.templatesDao.getBuiltInTemplates();
    final user = await db.templatesDao.getUserTemplates();
    if (!mounted) return;
    setState(() {
      _builtInTemplates = builtIn;
      _userTemplates = user;
      _isLoading = false;
    });
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

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.templateManagement),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(),
        tooltip: l10n.newTemplate,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTemplates,
              child: ListView(
                children: [
                  // Built-in templates section
                  if (_builtInTemplates.isNotEmpty) ...[
                    _buildSectionHeader(l10n.builtInTemplates, Icons.bookmark),
                    ..._builtInTemplates.map(
                      (t) => _buildTemplateTile(t, l10n, isBuiltIn: true),
                    ),
                    const Divider(height: 32),
                  ],

                  // User templates section
                  _buildSectionHeader(l10n.userTemplates, Icons.description),
                  if (_userTemplates.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          l10n.noTemplates,
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ),
                    )
                  else
                    ..._userTemplates.map(
                      (t) => _buildTemplateTile(t, l10n, isBuiltIn: false),
                    ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateTile(
    NoteTemplate template,
    AppLocalizations l10n, {
    required bool isBuiltIn,
  }) {
    final theme = Theme.of(context);
    final catColor = _categoryColor(template.category);
    final catLabel = _categoryLabel(template.category, l10n);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: catColor.withValues(alpha: 0.15),
        child: Icon(
          isBuiltIn ? Icons.bookmark_outlined : Icons.description_outlined,
          size: 20,
          color: catColor,
        ),
      ),
      title: Row(
        children: [
          Expanded(child: Text(template.name)),
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
        ],
      ),
      subtitle: Text(
        template.description?.isNotEmpty == true
            ? template.description!
            : l10n.templateUsed(template.usageCount),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade600,
        ),
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (action) => _onAction(action, template),
        itemBuilder: (ctx) => [
          if (isBuiltIn)
            PopupMenuItem(
              value: 'duplicate',
              child: ListTile(
                leading: const Icon(Icons.copy),
                title: Text(l10n.duplicateTemplate),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          if (!isBuiltIn) ...[
            PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(l10n.editTemplate),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: 'duplicate',
              child: ListTile(
                leading: const Icon(Icons.copy),
                title: Text(l10n.duplicateTemplate),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading:
                    Icon(Icons.delete_outline, color: theme.colorScheme.error),
                title: Text(
                  l10n.deleteTemplate,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _onAction(String action, NoteTemplate template) {
    switch (action) {
      case 'edit':
        _showEditDialog(template);
        break;
      case 'duplicate':
        _duplicateTemplate(template);
        break;
      case 'delete':
        _confirmDelete(template);
        break;
    }
  }

  Future<void> _duplicateTemplate(NoteTemplate template) async {
    final db = ref.read(databaseProvider);
    final crypto = ref.read(cryptoServiceProvider);
    final l10n = AppLocalizations.of(context)!;
    final id = const Uuid().v4();

    final content = template.plainContent ?? '';
    String encryptedContent;
    if (crypto.isUnlocked && content.isNotEmpty) {
      encryptedContent = await crypto.encryptForItem(id, content);
    } else {
      encryptedContent = template.encryptedContent;
    }

    await db.templatesDao.createTemplate(
      id: id,
      name: '${template.name} (copy)',
      description: template.description,
      encryptedContent: encryptedContent,
      plainContent: content,
      category: template.category,
      isBuiltIn: false,
    );

    if (!mounted) return;
    AppSnackBar.info(context, message: l10n.templateSaved);
    await _loadTemplates();
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
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  void _showCreateDialog() {
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
                if (mounted) {
                  AppSnackBar.info(context, message: l10n.templateSaved);
                }
                await _loadTemplates();
              },
              child: Text(l10n.create),
            ),
          ],
        ),
      ),
    );
  }

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
                if (mounted) {
                  AppSnackBar.info(context, message: l10n.templateSaved);
                }
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
