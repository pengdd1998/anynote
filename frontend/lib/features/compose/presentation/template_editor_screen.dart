import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../main.dart';
import '../domain/post_template.dart';

/// Create or edit a custom post template.
class TemplateEditorScreen extends ConsumerStatefulWidget {
  final PostTemplate? existing;

  const TemplateEditorScreen({super.key, this.existing});

  @override
  ConsumerState<TemplateEditorScreen> createState() =>
      _TemplateEditorScreenState();
}

class _TemplateEditorScreenState extends ConsumerState<TemplateEditorScreen> {
  late final _nameController = TextEditingController(text: widget.existing?.name);
  late final _descController =
      TextEditingController(text: widget.existing?.description);
  late final _promptController =
      TextEditingController(text: widget.existing?.systemPrompt);
  late final _structureController =
      TextEditingController(text: widget.existing?.structureHint);
  late final _toneController =
      TextEditingController(text: widget.existing?.toneHint);
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _promptController.dispose();
    _structureController.dispose();
    _toneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final prompt = _promptController.text.trim();
    if (name.isEmpty || prompt.isEmpty) {
      AppSnackBar.error(context, message: '名称和系统提示词不能为空');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final db = ref.read(databaseProvider);
      if (widget.existing != null) {
        // Update existing.
        await db.postTemplateDao.updateFields(
          widget.existing!.id,
          name: name,
          description: _descController.text.trim(),
          systemPrompt: prompt,
          structureHint: _structureController.text.trim().isEmpty
              ? null
              : _structureController.text.trim(),
          toneHint: _toneController.text.trim().isEmpty
              ? null
              : _toneController.text.trim(),
        );
      } else {
        // Create new via raw SQL (avoids Companion type complexity).
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
            _descController.text.trim(),
            prompt,
            _structureController.text.trim().isEmpty
                ? null
                : _structureController.text.trim(),
            _toneController.text.trim().isEmpty
                ? null
                : _toneController.text.trim(),
            now,
          ],
        );
      }
      if (mounted) {
        AppSnackBar.info(context, message: '模板已保存');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, message: '保存失败: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? '编辑模板' : '创建模板'),
        actions: [
          IconButton(
            onPressed: _isSaving ? null : _save,
            icon: const Icon(Icons.check),
            tooltip: '保存',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '模板名称',
              border: OutlineInputBorder(),
              hintText: '如：小红书种草文',
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          TextField(
            controller: _descController,
            decoration: const InputDecoration(
              labelText: '描述',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: AppSpacing.s12),
          TextField(
            controller: _promptController,
            decoration: const InputDecoration(
              labelText: '系统提示词（LLM 指令）',
              border: OutlineInputBorder(),
              hintText: 'Write a ... style post. Requirements:\n- ...',
            ),
            maxLines: 8,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.s12),
          TextField(
            controller: _structureController,
            decoration: const InputDecoration(
              labelText: '结构提示（可选）',
              border: OutlineInputBorder(),
              hintText: '标题 → 钩子 → 正文 → CTA → 标签',
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          TextField(
            controller: _toneController,
            decoration: const InputDecoration(
              labelText: '语气提示（可选）',
              border: OutlineInputBorder(),
              hintText: '轻松活泼, 第一人称',
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          if (_isSaving) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
