import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../l10n/app_localizations.dart';

/// Common programming languages for the dropdown.
const kSnippetLanguages = [
  'Dart',
  'Python',
  'JavaScript',
  'TypeScript',
  'Go',
  'Java',
  'Kotlin',
  'Swift',
  'Rust',
  'C++',
  'SQL',
  'HTML',
  'CSS',
  'Bash',
  'YAML',
  'JSON',
  'Other',
];

/// Bottom sheet for creating or editing a code snippet.
class SnippetEditorSheet extends StatefulWidget {
  /// If non-null, edit an existing snippet. Otherwise, create new.
  final Snippet? existing;

  /// Called with the companion object to persist.
  final Future<void> Function(SnippetsCompanion companion) onSave;

  const SnippetEditorSheet({
    super.key,
    this.existing,
    required this.onSave,
  });

  @override
  State<SnippetEditorSheet> createState() => _SnippetEditorSheetState();
}

class _SnippetEditorSheetState extends State<SnippetEditorSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _codeController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _categoryController;
  late final TextEditingController _tagsController;
  String _selectedLanguage = '';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _codeController = TextEditingController(text: existing?.code ?? '');
    _descriptionController =
        TextEditingController(text: existing?.description ?? '');
    _categoryController = TextEditingController(text: existing?.category ?? '');
    _tagsController = TextEditingController(text: existing?.tags ?? '');
    _selectedLanguage = existing?.language ?? '';

    _titleController.addListener(_onTextChanged);
    _codeController.addListener(_onTextChanged);
  }

  void _onTextChanged() => setState(() {});

  @override
  void dispose() {
    _titleController.dispose();
    _codeController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _titleController.text.trim().isNotEmpty &&
      _codeController.text.trim().isNotEmpty;

  Future<void> _save() async {
    if (!_isValid || _isSaving) return;

    setState(() => _isSaving = true);

    final now = DateTime.now();
    final companion = SnippetsCompanion(
      id: Value(widget.existing?.id ?? const Uuid().v4()),
      title: Value(_titleController.text.trim()),
      code: Value(_codeController.text),
      language: Value(_selectedLanguage),
      description: Value(_descriptionController.text.trim()),
      category: Value(_categoryController.text.trim()),
      tags: Value(_tagsController.text.trim()),
      usageCount: Value(widget.existing?.usageCount ?? 0),
      createdAt: Value(widget.existing?.createdAt ?? now),
      updatedAt: Value(now),
    );

    try {
      await widget.onSave(companion);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, message: e.toString());
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isEditing = widget.existing != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SheetHandleBar(),
            Text(
              isEditing ? l10n.editSnippet : l10n.newSnippet,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            _SnippetFormFields(
              titleController: _titleController,
              codeController: _codeController,
              descriptionController: _descriptionController,
              categoryController: _categoryController,
              tagsController: _tagsController,
              selectedLanguage: _selectedLanguage,
              onLanguageChanged: (v) => setState(() => _selectedLanguage = v),
              l10n: l10n,
            ),
            const SizedBox(height: 20),
            _EditorActionButtons(
              isValid: _isValid,
              isSaving: _isSaving,
              onSave: _save,
              onCancel: () => Navigator.pop(context),
              l10n: l10n,
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet drag handle bar.
class _SheetHandleBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color:
              Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// All form fields for the snippet editor: title, language, code, description,
/// category, and tags.
class _SnippetFormFields extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController codeController;
  final TextEditingController descriptionController;
  final TextEditingController categoryController;
  final TextEditingController tagsController;
  final String selectedLanguage;
  final ValueChanged<String> onLanguageChanged;
  final AppLocalizations l10n;

  const _SnippetFormFields({
    required this.titleController,
    required this.codeController,
    required this.descriptionController,
    required this.categoryController,
    required this.tagsController,
    required this.selectedLanguage,
    required this.onLanguageChanged,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: titleController,
          decoration: InputDecoration(
            labelText: l10n.snippetTitle,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: kSnippetLanguages.contains(selectedLanguage)
              ? selectedLanguage
              : (selectedLanguage.isEmpty ? null : 'Other'),
          decoration: InputDecoration(
            labelText: l10n.snippetLanguage,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          items: kSnippetLanguages
              .map((lang) => DropdownMenuItem(value: lang, child: Text(lang)))
              .toList(),
          onChanged: (value) => onLanguageChanged(value ?? ''),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: codeController,
          decoration: InputDecoration(
            labelText: l10n.snippetCode,
            border: const OutlineInputBorder(),
            isDense: true,
            alignLabelWithHint: true,
          ),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          maxLines: 8,
          minLines: 4,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: descriptionController,
          decoration: InputDecoration(
            labelText: l10n.snippetDescription,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          maxLines: 2,
          minLines: 1,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: categoryController,
          decoration: InputDecoration(
            labelText: l10n.snippetCategory,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: tagsController,
          decoration: InputDecoration(
            labelText: l10n.snippetTags,
            border: const OutlineInputBorder(),
            isDense: true,
            hintText: 'tag1, tag2, tag3',
          ),
        ),
      ],
    );
  }
}

/// Cancel and Save action buttons at the bottom of the snippet editor.
class _EditorActionButtons extends StatelessWidget {
  final bool isValid;
  final bool isSaving;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final AppLocalizations l10n;

  const _EditorActionButtons({
    required this.isValid,
    required this.isSaving,
    required this.onSave,
    required this.onCancel,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: onCancel,
          child: Text(l10n.cancel),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: isValid && !isSaving ? onSave : null,
          child: isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.save),
        ),
      ],
    );
  }
}
