import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_durations.dart';
import '../../../core/crypto/crypto_service.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/daos/note_properties_dao.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart';

/// A minimal full-screen overlay for lightning-fast note creation.
///
/// Features:
/// - Single large text field with immediate focus
/// - Auto-saves after 2 seconds of inactivity (debounce)
/// - Title auto-generated from first line of content
/// - Bottom toolbar with tag picker, priority selector, and save & close
/// - Swipe down to dismiss with discard confirmation
/// - Supports receiving shared text via intent
class QuickCaptureScreen extends ConsumerStatefulWidget {
  /// Optional shared text to pre-fill the content field.
  final String? sharedText;

  /// Optional template type: null for blank, 'checklist' for checklist template.
  final String? template;

  const QuickCaptureScreen({super.key, this.sharedText, this.template});

  @override
  ConsumerState<QuickCaptureScreen> createState() => _QuickCaptureScreenState();
}

class _QuickCaptureScreenState extends ConsumerState<QuickCaptureScreen> {
  late final TextEditingController _contentController;
  late final FocusNode _contentFocusNode;

  /// The ID of the note that has been created (on first auto-save or manual save).
  String? _savedNoteId;

  /// Current content text for tracking changes.
  String _lastSavedContent = '';

  /// Whether auto-save indicator should be visible.
  bool _showAutoSaved = false;

  /// Debounce timer for auto-save.
  Timer? _autoSaveTimer;

  /// Currently selected priority. Null means no priority set.
  String? _selectedPriority;

  /// Whether a save operation is in progress.
  bool _isSaving = false;

  /// Tag IDs selected by the user.
  final Set<String> _selectedTagIds = {};

  /// Drag dismiss threshold tracker.
  double _dragOffset = 0;

  @override
  void initState() {
    super.initState();

    // Build initial content from template or shared text.
    String initialContent = '';
    if (widget.sharedText != null && widget.sharedText!.isNotEmpty) {
      initialContent = widget.sharedText!;
    } else if (widget.template == 'checklist') {
      initialContent = '- [ ] \n- [ ] \n- [ ] \n';
    }

    _contentController = TextEditingController(text: initialContent);
    _contentFocusNode = FocusNode();
    _lastSavedContent = initialContent;

    // Request focus after the first frame is rendered.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _contentFocusNode.requestFocus();
      }
    });

    // Listen for content changes to trigger auto-save debounce.
    _contentController.addListener(_onContentChanged);
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _contentController.removeListener(_onContentChanged);
    _contentController.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  /// Called whenever the text field content changes.
  void _onContentChanged() {
    // Cancel any pending auto-save.
    _autoSaveTimer?.cancel();

    final content = _contentController.text;
    if (content.isEmpty) return;

    // Schedule auto-save after 2 seconds of inactivity.
    _autoSaveTimer = Timer(AppDurations.snackbarDuration, () {
      _saveNote(showIndicator: true);
    });
  }

  /// Extract title from the first line of content.
  String _extractTitle(String content) {
    final lines = content.split('\n');
    // Find the first non-empty line as the title.
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) {
        // Strip markdown checklist prefix.
        final stripped = trimmed.replaceFirst(RegExp(r'^- \[[ x]\] '), '');
        return stripped.length > 100 ? stripped.substring(0, 100) : stripped;
      }
    }
    return '';
  }

  /// Save or update the note in the database.
  Future<void> _saveNote({bool showIndicator = false}) async {
    final content = _contentController.text;
    if (content.trim().isEmpty && _savedNoteId == null) return;
    if (content == _lastSavedContent && _savedNoteId != null) return;

    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final db = ref.read(databaseProvider);
      final crypto = ref.read(cryptoServiceProvider);
      final title = _extractTitle(content);

      String encryptedContent = content;
      String? encryptedTitle;
      if (crypto.isUnlocked) {
        final noteId = _savedNoteId ?? const Uuid().v4();
        encryptedContent = await crypto.encryptForItem(noteId, content);
        if (title.isNotEmpty) {
          encryptedTitle = await crypto.encryptForItem(noteId, title);
        }
      }

      if (_savedNoteId == null) {
        // Create a new note.
        final id = const Uuid().v4();
        await db.notesDao.createNote(
          id: id,
          encryptedContent: encryptedContent,
          encryptedTitle: encryptedTitle,
          plainContent: content,
          plainTitle: title,
        );

        // Set priority if selected.
        if (_selectedPriority != null) {
          await db.notePropertiesDao.createTextProperty(
            id: const Uuid().v4(),
            noteId: id,
            key: BuiltInProperties.priority,
            value: _selectedPriority!,
          );
        }

        // Set tags if any selected.
        for (final tagId in _selectedTagIds) {
          await db.notesDao.addTagToNote(id, tagId);
        }

        _savedNoteId = id;
      } else {
        // Update the existing note.
        await db.notesDao.updateNote(
          id: _savedNoteId!,
          encryptedContent: encryptedContent,
          encryptedTitle: encryptedTitle,
          plainContent: content,
          plainTitle: title,
        );
      }

      _lastSavedContent = content;

      if (showIndicator && mounted) {
        setState(() => _showAutoSaved = true);
        // Hide the auto-saved indicator after 2 seconds.
        Future.delayed(AppDurations.snackbarDuration, () {
          if (mounted) setState(() => _showAutoSaved = false);
        });
      }
    } catch (e) {
      // Silently fail -- the user can still manually save.
      debugPrint('QuickCapture: auto-save failed: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Save and close the screen.
  Future<void> _saveAndClose() async {
    _autoSaveTimer?.cancel();
    final content = _contentController.text;
    if (content.trim().isNotEmpty) {
      await _saveNote();
    }
    if (mounted) {
      Navigator.of(context).pop(_savedNoteId);
    }
  }

  /// Show discard confirmation dialog.
  Future<bool> _confirmDiscard() async {
    final content = _contentController.text;
    if (content.trim().isEmpty) return true;

    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.discardDraft),
        content: Text(l10n.discardDraftMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.discard),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Show the priority selector bottom sheet.
  void _showPrioritySelector() {
    const priorities = ['High', 'Medium', 'Low'];
    final priorityLabels = [
      AppLocalizations.of(context)!.priorityHigh,
      AppLocalizations.of(context)!.priorityMedium,
      AppLocalizations.of(context)!.priorityLow,
    ];
    const icons = [
      Icons.keyboard_double_arrow_up,
      Icons.keyboard_double_arrow_right,
      Icons.keyboard_double_arrow_down,
    ];
    const colors = [
      Colors.red,
      Colors.orange,
      Colors.green,
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final l10n = AppLocalizations.of(context)!;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.setPriority,
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ),
              ...List.generate(priorities.length, (index) {
                final priority = priorities[index];
                final isSelected = _selectedPriority == priority;
                return ListTile(
                  leading: Icon(icons[index], color: colors[index]),
                  title: Text(priorityLabels[index]),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: Colors.blue)
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedPriority = isSelected ? null : priority;
                    });
                    Navigator.pop(ctx);
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  /// Show the tag picker bottom sheet.
  Future<void> _showTagPicker() async {
    final db = ref.read(databaseProvider);
    final allTags = await db.tagsDao.getAllTags();
    if (!mounted) return;

    final l10n = AppLocalizations.of(context)!;

    final selectedTags = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) => _TagPickerDialog(
        existingTags: allTags,
        initialSelection: _selectedTagIds,
        l10n: l10n,
      ),
    );

    if (selectedTags != null && mounted) {
      setState(() {
        _selectedTagIds.clear();
        _selectedTagIds.addAll(selectedTags);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;

    return GestureDetector(
      // Swipe down to dismiss.
      onVerticalDragUpdate: (details) {
        setState(() => _dragOffset += details.delta.dy);
      },
      onVerticalDragEnd: (details) async {
        // If dragged down more than 20% of screen height, dismiss.
        if (_dragOffset > screenHeight * 0.2) {
          final shouldDiscard = await _confirmDiscard();
          if (shouldDiscard && mounted && context.mounted) {
            Navigator.of(context).pop(_savedNoteId);
          } else {
            setState(() => _dragOffset = 0);
          }
        } else {
          setState(() => _dragOffset = 0);
        }
      },
      child: AnimatedContainer(
        duration: AppDurations.veryShortAnimation,
        transform: Matrix4.translationValues(
          0,
          _dragOffset.clamp(0.0, double.infinity),
          0,
        ),
        curve: Curves.easeOut,
        // Semi-transparent background for overlay feel.
        color: theme.colorScheme.surface.withValues(alpha: 0.97),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.keyboard_arrow_down),
              tooltip: l10n.close,
              onPressed: () async {
                _autoSaveTimer?.cancel();
                if (_contentController.text.trim().isNotEmpty) {
                  final shouldDiscard = await _confirmDiscard();
                  if (!shouldDiscard) return;
                }
                if (mounted && context.mounted) {
                  Navigator.of(context).pop(_savedNoteId);
                }
              },
            ),
            title: Text(
              l10n.quickCapture,
              style: theme.textTheme.titleMedium,
            ),
            centerTitle: true,
            actions: [
              // Auto-save indicator
              if (_showAutoSaved)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cloud_done,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        l10n.autoSaved,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              // Save and close
              IconButton(
                icon: const Icon(Icons.check),
                tooltip: l10n.save,
                onPressed: _saveAndClose,
              ),
            ],
          ),
          body: Column(
            children: [
              // Tag chips display
              if (_selectedTagIds.isNotEmpty || _selectedPriority != null)
                _buildMetadataChips(theme),
              // Main text input area
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Semantics(
                    label: l10n.noteContentEditor,
                    textField: true,
                    child: TextField(
                      controller: _contentController,
                      focusNode: _contentFocusNode,
                      decoration: InputDecoration(
                        hintText: l10n.typeSomething,
                        border: InputBorder.none,
                      ),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontSize: 18,
                        height: 1.6,
                      ),
                      maxLines: null,
                      expands: true,
                      textInputAction: TextInputAction.newline,
                      textAlignVertical: TextAlignVertical.top,
                    ),
                  ),
                ),
              ),
              // Bottom toolbar
              _buildBottomToolbar(theme, l10n),
            ],
          ),
        ),
      ),
    );
  }

  /// Build the metadata chips row showing selected tags and priority.
  Widget _buildMetadataChips(ThemeData theme) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          if (_selectedPriority != null)
            Padding(
              padding: const EdgeInsets.only(right: 6, top: 6, bottom: 6),
              child: Chip(
                label: Text(_selectedPriority!),
                avatar: Icon(
                  _selectedPriority == 'High'
                      ? Icons.keyboard_double_arrow_up
                      : _selectedPriority == 'Medium'
                          ? Icons.keyboard_double_arrow_right
                          : Icons.keyboard_double_arrow_down,
                  size: 14,
                ),
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () {
                  setState(() => _selectedPriority = null);
                },
                visualDensity: VisualDensity.compact,
              ),
            ),
          // Tag chips would be populated from the tag names.
          // For now, show count badge.
          if (_selectedTagIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 6, bottom: 6),
              child: Chip(
                label: Text(AppLocalizations.of(context)!
                    .tagsCountLabel(_selectedTagIds.length)),
                avatar: const Icon(Icons.label, size: 14),
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () {
                  setState(() => _selectedTagIds.clear());
                },
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }

  /// Build the bottom action toolbar.
  Widget _buildBottomToolbar(ThemeData theme, AppLocalizations l10n) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: theme.colorScheme.outlineVariant,
              width: 1,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // Tag picker button
            IconButton(
              icon: Badge(
                isLabelVisible: _selectedTagIds.isNotEmpty,
                label: Text('${_selectedTagIds.length}'),
                child: const Icon(Icons.label_outline),
              ),
              tooltip: l10n.tags,
              onPressed: _showTagPicker,
            ),
            // Priority selector button
            IconButton(
              icon: Icon(
                _selectedPriority == 'High'
                    ? Icons.keyboard_double_arrow_up
                    : _selectedPriority == 'Medium'
                        ? Icons.keyboard_double_arrow_right
                        : _selectedPriority == 'Low'
                            ? Icons.keyboard_double_arrow_down
                            : Icons.flag_outlined,
                color: _selectedPriority == 'High'
                    ? Colors.red
                    : _selectedPriority == 'Medium'
                        ? Colors.orange
                        : _selectedPriority == 'Low'
                            ? Colors.green
                            : null,
              ),
              tooltip: l10n.setPriority,
              onPressed: _showPrioritySelector,
            ),
            const Spacer(),
            // Save indicator
            if (_isSaving)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            // Save & Close FAB
            FilledButton.tonalIcon(
              onPressed: _saveAndClose,
              icon: const Icon(Icons.check),
              label: Text(l10n.saveAndClose),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog for selecting tags in the quick capture screen.
class _TagPickerDialog extends StatefulWidget {
  final List<Tag> existingTags;
  final Set<String> initialSelection;
  final AppLocalizations l10n;

  const _TagPickerDialog({
    required this.existingTags,
    required this.initialSelection,
    required this.l10n,
  });

  @override
  State<_TagPickerDialog> createState() => _TagPickerDialogState();
}

class _TagPickerDialogState extends State<_TagPickerDialog> {
  late final Set<String> _selectedTagIds;

  @override
  void initState() {
    super.initState();
    _selectedTagIds = Set.from(widget.initialSelection);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.l10n.tags),
      content: SizedBox(
        width: double.maxFinite,
        child: widget.existingTags.isEmpty
            ? Text(widget.l10n.noTagsYet)
            : ListView.builder(
                shrinkWrap: true,
                itemCount: widget.existingTags.length,
                itemBuilder: (context, index) {
                  final tag = widget.existingTags[index];
                  final tagId = tag.id;
                  final isSelected = _selectedTagIds.contains(tagId);
                  final tagName = tag.plainName ?? widget.l10n.encrypted;

                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          _selectedTagIds.add(tagId);
                        } else {
                          _selectedTagIds.remove(tagId);
                        }
                      });
                    },
                    title: Text(tagName),
                    controlAffinity: ListTileControlAffinity.leading,
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.l10n.cancel),
        ),
        TextButton(
          onPressed: _selectedTagIds.isEmpty
              ? null
              : () => Navigator.of(context).pop(_selectedTagIds),
          child: Text(widget.l10n.add),
        ),
      ],
    );
  }
}
