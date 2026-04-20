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
    final custom = await db.templatesDao.getCustomTemplates();

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
        encryptedContent: template.content,
        plainContent: template.content,
        category: 'built_in',
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
    final lines = plainContent.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return '';
    if (lines.length == 1) return lines.first;
    return '${lines[0]}\n${lines[1]}';
  }

  @override
  Widget build(BuildContext context) {
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
              Text(AppLocalizations.of(context)!.fromTemplate,
                  style: Theme.of(context).textTheme.titleLarge,),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),

        // Tabs
        TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: AppLocalizations.of(context)!.builtInTab),
            Tab(text: AppLocalizations.of(context)!.myTemplatesTab),
          ],
        ),

        const SizedBox(height: 8),

        // Tab content
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.45,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTemplateGrid(_builtInTemplates, canDelete: false),
                    _buildCustomTemplatesTab(),
                  ],
                ),
        ),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildTemplateGrid(List<NoteTemplate> templates,
      {required bool canDelete,}) {
    if (templates.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context)!.noNotesYet,
          style: TextStyle(color: Colors.grey.shade500),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: templates.length,
      itemBuilder: (context, index) {
        final template = templates[index];
        final preview = _preview(template.plainContent);

        return GestureDetector(
          onTap: () {
            final resolved = _resolveContent(template.plainContent ?? '');
            widget.onSelected(resolved);
            Navigator.pop(context);
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
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          template.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Text(
                      preview,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
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
        Expanded(child: _buildTemplateGrid(_customTemplates, canDelete: true)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showCreateTemplateDialog,
              icon: const Icon(Icons.add),
              label: Text(AppLocalizations.of(context)!.create),
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
        title: Text(l10n.deleteTemplateConfirm),
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
    final contentController = TextEditingController();
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.create),
        content: SizedBox(
          width: MediaQuery.of(ctx).size.width * 0.85,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: l10n.templateNameLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentController,
                decoration: InputDecoration(
                  labelText: l10n.contentLabel,
                  hintText: l10n.templateDateHint,
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 8,
              ),
            ],
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
                encryptedContent =
                    await crypto.encryptForItem(id, content);
              } else {
                encryptedContent = content;
              }

              await db.templatesDao.createTemplate(
                id: id,
                name: name,
                encryptedContent: encryptedContent,
                plainContent: content,
                category: 'custom',
                isBuiltIn: false,
              );

              if (ctx.mounted) Navigator.pop(ctx);
              await _loadTemplates();
            },
            child: Text(l10n.create),
          ),
        ],
      ),
    );
  }
}
