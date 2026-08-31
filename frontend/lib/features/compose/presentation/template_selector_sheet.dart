import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../main.dart';
import '../data/compose_providers.dart';
import '../domain/post_template.dart';
import 'template_editor_screen.dart';
import 'template_extractor_screen.dart';

/// Bottom sheet for selecting a post template.
///
/// Shows built-in + user-created templates as cards. Includes buttons to
/// create a custom template or extract one from a sample post.
class TemplateSelectorSheet extends ConsumerWidget {
  final PostTemplate? selectedTemplate;
  final ValueChanged<PostTemplate?> onSelected;

  const TemplateSelectorSheet({
    super.key,
    this.selectedTemplate,
    required this.onSelected,
  });

  /// Show the sheet as a modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    PostTemplate? selectedTemplate,
    required ValueChanged<PostTemplate?> onSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (_) => TemplateSelectorSheet(
        selectedTemplate: selectedTemplate,
        onSelected: onSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(allPostTemplatesProvider);
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: AppSpacing.s8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withAlpha(80),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.s16),
              child: Row(
                children: [
                  Text('选择模板', style: AppTextStyles.headline),
                  const Spacer(),
                  // Create custom template
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TemplateEditorScreen(),
                        ),
                      );
                    },
                    tooltip: '创建自定义模板',
                  ),
                  // Extract from post
                  IconButton(
                    icon: const Icon(Icons.auto_fix_high),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TemplateExtractorScreen(),
                        ),
                      );
                    },
                    tooltip: '从文章提取模板',
                  ),
                ],
              ),
            ),
            // Template list
            Expanded(
              child: templatesAsync.when(
                data: (templates) {
                  // Index 0 is the "no template" option; the rest are the
                  // templates from the database.
                  return ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s16,
                    ),
                    itemCount: templates.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _NoTemplateCard(
                          isSelected: selectedTemplate == null,
                          onTap: () => _selectNoTemplate(context, ref),
                        );
                      }
                      final t = templates[index - 1];
                      final isSelected = selectedTemplate?.id == t.id;
                      return _TemplateCard(
                        template: t,
                        isSelected: isSelected,
                        onTap: () {
                          onSelected(t);
                          Navigator.pop(context);
                        },
                        // Built-in templates are not editable.
                        onEditRequest:
                            t.isBuiltIn ? null : () => _editTemplate(context, t),
                        onDeleteRequest: t.isBuiltIn
                            ? null
                            : () => _deleteTemplate(context, ref, t),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) =>
                    const Center(child: Text('加载失败')),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Selects the "no template" option: clears the selection in both the
  /// callback owner and the compose session provider.
  void _selectNoTemplate(BuildContext context, WidgetRef ref) {
    onSelected(null);
    ref.read(composeSessionProvider.notifier).clearTemplate();
    Navigator.pop(context);
  }

  /// Opens the template editor pre-filled with [template] for updating.
  void _editTemplate(BuildContext context, PostTemplate template) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TemplateEditorScreen(existing: template),
      ),
    );
  }

  /// Deletes a user-created template after a confirmation dialog.
  Future<void> _deleteTemplate(
    BuildContext context,
    WidgetRef ref,
    PostTemplate template,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除模板'),
        content: Text('确定要删除「${template.name}」吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(databaseProvider).postTemplateDao.deleteById(template.id);
      if (context.mounted) {
        AppSnackBar.info(context, message: '模板已删除');
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackBar.error(context, message: '删除失败: $e');
      }
    }
  }
}

class _TemplateCard extends StatelessWidget {
  final PostTemplate template;
  final bool isSelected;
  final VoidCallback onTap;

  /// Non-null for user-created templates: opens the editor pre-filled.
  final VoidCallback? onEditRequest;

  /// Non-null for user-created templates: deletes after confirmation.
  final VoidCallback? onDeleteRequest;

  const _TemplateCard({
    required this.template,
    required this.isSelected,
    required this.onTap,
    this.onEditRequest,
    this.onDeleteRequest,
  });

  bool get _isEditable =>
      onEditRequest != null || onDeleteRequest != null;

  /// Shows the edit/delete actions for a user-created template.
  Future<void> _showActions(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('编辑模板'),
              onTap: () => Navigator.pop(sheetContext, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('删除模板'),
              onTap: () => Navigator.pop(sheetContext, 'delete'),
            ),
          ],
        ),
      ),
    ).then((action) {
      if (!context.mounted) return;
      if (action == 'edit') onEditRequest?.call();
      if (action == 'delete') onDeleteRequest?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.s8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: isSelected
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        onLongPress: _isEditable ? () => _showActions(context) : null,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s12),
          child: Row(
            children: [
              Icon(
                template.isBuiltIn ? Icons.bookmark : Icons.person_outline,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(template.name, style: AppTextStyles.title),
                    if (template.description.isNotEmpty)
                      Text(
                        template.description,
                        style: AppTextStyles.caption.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (template.structureHint != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        template.structureHint!,
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 11,
                          color: theme.colorScheme.primary.withAlpha(180),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (_isEditable)
                IconButton(
                  icon: const Icon(Icons.more_vert, size: 20),
                  tooltip: '模板操作',
                  onPressed: () => _showActions(context),
                )
              else if (isSelected)
                Icon(Icons.check_circle, color: theme.colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

/// The "no template" option: clears the current template selection so the AI
/// composes without template constraints.
class _NoTemplateCard extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;

  const _NoTemplateCard({
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.s8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: isSelected
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s12),
          child: Row(
            children: [
              Icon(
                Icons.block,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('无模板', style: AppTextStyles.title),
                    Text(
                      '不套用模板，按默认风格自由创作',
                      style: AppTextStyles.caption.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle, color: theme.colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
