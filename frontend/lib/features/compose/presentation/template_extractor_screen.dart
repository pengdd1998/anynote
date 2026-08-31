import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../main.dart';
import '../data/compose_providers.dart';
import '../domain/post_template.dart';

/// Extract a post template from a sample post using the AI agent.
///
/// The user pastes a sample post, the AI analyzes its structure/tone/format,
/// and creates a reusable template that's saved to the database.
class TemplateExtractorScreen extends ConsumerStatefulWidget {
  const TemplateExtractorScreen({super.key});

  @override
  ConsumerState<TemplateExtractorScreen> createState() =>
      _TemplateExtractorScreenState();
}

class _TemplateExtractorScreenState
    extends ConsumerState<TemplateExtractorScreen> {
  final _sampleController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isExtracting = false;
  PostTemplate? _extracted;

  @override
  void dispose() {
    _sampleController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _extract() async {
    final sample = _sampleController.text.trim();
    if (sample.isEmpty || sample.length < 20) {
      AppSnackBar.error(context, message: '请输入至少 20 字的示例文章');
      return;
    }

    setState(() {
      _isExtracting = true;
      _extracted = null;
    });

    try {
      final result = await extractTemplateFromPost(
        sample,
        ref: ref,
      );

      if (result != null) {
        setState(() {
          _extracted = result;
          _nameController.text = result.name;
        });
        AppSnackBar.info(context, message: '模板提取成功，请确认后保存');
      } else {
        AppSnackBar.error(context, message: '提取失败，请检查 AI 配额后重试');
      }
    } catch (e) {
      AppSnackBar.error(context, message: '提取失败: $e');
    } finally {
      if (mounted) setState(() => _isExtracting = false);
    }
  }

  Future<void> _save() async {
    final template = _extracted;
    if (template == null) return;

    final name = _nameController.text.trim().isEmpty
        ? template.name
        : _nameController.text.trim();

    try {
      final db = ref.read(databaseProvider);
      final id = const Uuid().v4();
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.customStatement(
        'INSERT INTO post_templates '
        '(id, name, description, system_prompt, structure_hint, '
        'tone_hint, is_built_in, created_at) '
        'VALUES (?, ?, ?, ?, ?, ?, 0, ?)',
        [
          id,
          name,
          template.description,
          template.systemPrompt,
          template.structureHint,
          template.toneHint,
          now,
        ],
      );
      if (mounted) {
        AppSnackBar.info(context, message: '模板已保存');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, message: '保存失败: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('从文章提取模板')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // Sample post input
          Text('粘贴示例文章，AI 将分析其结构、语气和格式：',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.s8),
          TextField(
            controller: _sampleController,
            maxLines: 10,
            enabled: _extracted == null && !_isExtracting,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '在此粘贴一篇你喜欢的文章...',
            ),
          ),
          const SizedBox(height: AppSpacing.s12),

          // Extract button
          if (_extracted == null)
            FilledButton.icon(
              onPressed: _isExtracting ? null : _extract,
              icon: _isExtracting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_fix_high),
              label: Text(_isExtracting ? '提取中...' : 'AI 提取模板'),
            ),

          // Extracted result preview
          if (_extracted != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('提取结果', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.s8),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: '模板名称',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    Text('描述: ${_extracted!.description}'),
                    if (_extracted!.structureHint != null)
                      Text('结构: ${_extracted!.structureHint}'),
                    if (_extracted!.toneHint != null)
                      Text('语气: ${_extracted!.toneHint}'),
                    const SizedBox(height: AppSpacing.s8),
                    Text('系统提示词:',
                        style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: AppSpacing.s4),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.s8),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withAlpha(60),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _extracted!.systemPrompt,
                        style: const TextStyle(
                            fontFamily: 'RobotoMono', fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _extracted = null;
                      _sampleController.clear();
                    });
                  },
                  child: const Text('重新提取'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: const Text('保存模板'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
