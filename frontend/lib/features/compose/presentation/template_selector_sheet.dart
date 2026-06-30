import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
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
    final l10n = Theme.of(context);

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
                color: l10n.colorScheme.outline.withAlpha(80),
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
                  if (templates.isEmpty) {
                    return const Center(child: Text('暂无模板'));
                  }
                  return ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s16),
                    itemCount: templates.length,
                    itemBuilder: (context, index) {
                      final t = templates[index];
                      final isSelected =
                          selectedTemplate?.id == t.id;
                      return _TemplateCard(
                        template: t,
                        isSelected: isSelected,
                        onTap: () {
                          onSelected(t);
                          Navigator.pop(context);
                        },
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
}

class _TemplateCard extends StatelessWidget {
  final PostTemplate template;
  final bool isSelected;
  final VoidCallback onTap;

  const _TemplateCard({
    required this.template,
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
              if (isSelected)
                Icon(Icons.check_circle, color: theme.colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
