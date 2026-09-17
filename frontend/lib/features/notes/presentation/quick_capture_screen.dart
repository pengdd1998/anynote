import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_durations.dart';
import '../../../core/crypto/crypto_service.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/daos/note_properties_dao.dart';
import '../../../core/storage/image_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/analytics/analytics_service.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart';

/// A bottom-sheet overlay for lightning-fast note capture.
///
/// Renders as a modal sheet with rounded top corners, a single auto-focused
/// text field, and swipe-down-to-dismiss. Auto-saves after 2s of inactivity.
class QuickCaptureScreen extends ConsumerStatefulWidget {
  final String? sharedText;
  final String? template;

  const QuickCaptureScreen({super.key, this.sharedText, this.template});

  @override
  ConsumerState<QuickCaptureScreen> createState() => _QuickCaptureScreenState();
}

class _QuickCaptureScreenState extends ConsumerState<QuickCaptureScreen> {
  late final TextEditingController _contentController;
  late final FocusNode _contentFocusNode;

  String? _savedNoteId;
  String _lastSavedContent = '';
  bool _showAutoSaved = false;
  Timer? _autoSaveTimer;
  String? _selectedPriority;
  bool _isSaving = false;
  final Set<String> _selectedTagIds = {};

  /// Pending image attachments (local file paths) captured in this session.
  final List<String> _attachedImagePaths = [];

  // -- Voice dictation (speech_to_text) --
  final stt.SpeechToText _stt = stt.SpeechToText();
  bool _sttReady = false;
  bool _isListening = false;
  String _dictationBase = ''; // text before the live dictation segment.
  bool _urlExpansionPending = true;

  @override
  void initState() {
    super.initState();

    String initialContent = '';
    if (widget.sharedText != null && widget.sharedText!.isNotEmpty) {
      initialContent = widget.sharedText!;
    } else if (widget.template == 'checklist') {
      initialContent = '- [ ] \n- [ ] \n- [ ] \n';
    }

    _contentController = TextEditingController(text: initialContent);
    _contentFocusNode = FocusNode();
    _lastSavedContent = initialContent;

    // URL capture: submitting/pasting a bare URL expands into a snippet.
    _contentController.addListener(() {
      final text = _contentController.text.trim();
      if (RegExp(r'^https?://\S+$').hasMatch(text) &&
          _urlExpansionPending) {
        _urlExpansionPending = false;
        _expandUrlIfNeeded();
      } else if (!RegExp(r'^https?://\S+$').hasMatch(text)) {
        _urlExpansionPending = true;
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _contentFocusNode.requestFocus();
    });

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

  void _onContentChanged() {
    _autoSaveTimer?.cancel();
    final content = _contentController.text;
    if (content.isEmpty) return;

    _autoSaveTimer = Timer(AppDurations.snackbarDuration, () {
      _saveNote(showIndicator: true);
    });
  }

  String _extractTitle(String content) {
    final lines = content.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) {
        final stripped = trimmed.replaceFirst(RegExp(r'^- \[[ x]\] '), '');
        return stripped.length > 100 ? stripped.substring(0, 100) : stripped;
      }
    }
    return '';
  }

  Future<void> _saveNote({bool showIndicator = false}) async {
    final analytics = ref.read(analyticsProvider);
    var content = _contentController.text;
    // Append pending image attachments as markdown references so the note
    // body keeps them across save/restore (rendered as image embeds).
    for (final path in _attachedImagePaths) {
      content += '\n![image](file://$path)';
    }
    if (content.trim().isEmpty && _savedNoteId == null) return;
    if (content == _lastSavedContent && _savedNoteId != null) return;

    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final db = ref.read(databaseProvider);
      final crypto = ref.read(cryptoServiceProvider);
      final title = _extractTitle(content);

      // Try to unlock the vault so quick notes are encrypted, not plaintext.
      if (!crypto.isUnlocked) {
        await crypto.unlock();
      }
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
        final id = const Uuid().v4();
        await db.notesDao.createNote(
          id: id,
          encryptedContent: encryptedContent,
          encryptedTitle: encryptedTitle,
          plainContent: content,
          plainTitle: title,
        );

        if (_selectedPriority != null) {
          await db.notePropertiesDao.createTextProperty(
            id: const Uuid().v4(),
            noteId: id,
            key: BuiltInProperties.priority,
            value: _selectedPriority!,
          );
        }

        for (final tagId in _selectedTagIds) {
          await db.notesDao.addTagToNote(id, tagId);
        }

        _savedNoteId = id;
        analytics.count('quick_capture_saved');
      } else {
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
        Future.delayed(AppDurations.snackbarDuration, () {
          if (mounted) setState(() => _showAutoSaved = false);
        });
      }
    } catch (e) {
      debugPrint('QuickCapture: auto-save failed: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveAndClose() async {
    _autoSaveTimer?.cancel();
    final content = _contentController.text;
    // Text OR an attached image justifies a save.
    if (content.trim().isNotEmpty || _attachedImagePaths.isNotEmpty) {
      await _saveNote();
    }
    if (mounted) {
      Navigator.of(context).pop(_savedNoteId);
    }
  }

  Future<void> _dismissWithConfirmation() async {
    _autoSaveTimer?.cancel();
    final content = _contentController.text;
    if (content.trim().isNotEmpty) {
      final shouldDiscard = await _confirmDiscard();
      if (!shouldDiscard) return;
    }
    if (mounted) {
      Navigator.of(context).pop(_savedNoteId);
    }
  }

  Future<bool> _confirmDiscard() async {
    final content = _contentController.text;
    if (content.trim().isEmpty) return true;

    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
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

  void _showPrioritySelector() {
    const priorities = ['High', 'Medium', 'Low'];
    final l10n = AppLocalizations.of(context)!;
    final priorityLabels = [
      l10n.priorityHigh,
      l10n.priorityMedium,
      l10n.priorityLow,
    ];
    const icons = [
      Icons.keyboard_double_arrow_up,
      Icons.keyboard_double_arrow_right,
      Icons.keyboard_double_arrow_down,
    ];
    const colors = [AppColors.error, AppColors.warning, AppColors.success];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) {
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
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s16,
                  AppSpacing.s12,
                  AppSpacing.s16,
                  AppSpacing.s4,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.setPriority,
                    style: AppTextStyles.title,
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
                      ? Icon(
                          Icons.check_circle,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedPriority = isSelected ? null : priority;
                    });
                    Navigator.pop(ctx);
                  },
                );
              }),
              const SizedBox(height: AppSpacing.s8),
            ],
          ),
        );
      },
    );
  }

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final tertiaryColor =
        isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;

    // Sticky-note surface: warm yellow tint in light mode, a subtle yellow
    // wash over the dark card in dark mode.
    final cardBg = isDark
        ? Color.alphaBlend(
            AppColors.accentYellowBg.withAlpha(28),
            AppColors.darkCardBg,
          )
        : AppColors.accentYellowBg;

    return GestureDetector(
      onVerticalDragUpdate: (details) {
        if (details.delta.dy > 0) {
          _dismissWithConfirmation();
        }
      },
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: screenHeight * 0.85 + bottomInset,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s20,
              vertical: AppSpacing.s16,
            ),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: AppShadows.lgOf(Theme.of(context).brightness),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // -- Drag handle --
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: AppSpacing.s8),
                    decoration: BoxDecoration(
                      color: tertiaryColor.withAlpha(80),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // -- Header row: handwritten title + close action --
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.quickCapture,
                        style:
                            AppTextStyles.handwritingBody.copyWith(
                          fontSize: 24,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                    ),
                    // Auto-save indicator
                    if (_showAutoSaved)
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.s8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              AppIcons.cloudDone,
                              size: 14,
                              color: AppColors.accentMintText,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              l10n.autoSaved,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.accentMintText,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Close (top-right, tertiary) — discards with confirmation.
                    IconButton(
                      icon: const Icon(AppIcons.close),
                      iconSize: 20,
                      color: tertiaryColor,
                      tooltip: l10n.cancel,
                      onPressed: _dismissWithConfirmation,
                    ),
                  ],
                ),

                // -- Metadata chips --
                if (_selectedTagIds.isNotEmpty || _selectedPriority != null)
                  _buildMetadataChips(isDark),

                // -- Text input --
                Flexible(
                  child: TextField(
                    controller: _contentController,
                    focusNode: _contentFocusNode,
                    scrollPadding: const EdgeInsets.only(bottom: 120),
                    decoration: InputDecoration(
                      hintText: l10n.typeSomething,
                      border: InputBorder.none,
                      hintStyle: AppTextStyles.body.copyWith(
                        fontSize: 17,
                        height: 1.7,
                        color: tertiaryColor.withAlpha(120),
                      ),
                    ),
                    style: AppTextStyles.body.copyWith(
                      fontSize: 17,
                      height: 1.7,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                    maxLines: null,
                    minLines: 5,
                    textInputAction: TextInputAction.newline,
                    textAlignVertical: TextAlignVertical.top,
                  ),
                ),

                // -- Attached image thumbnails --
                if (_attachedImagePaths.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.s8),
                    child: SizedBox(
                      height: 64,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final path in _attachedImagePaths)
                            Padding(
                              padding: const EdgeInsets.only(
                                right: AppSpacing.s8,
                              ),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.xs),
                                    child: Image.file(
                                      File(path),
                                      width: 64,
                                      height: 64,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          Container(
                                        width: 64,
                                        height: 64,
                                        color: AppColors.lightInputFill,
                                        child: const Icon(
                                          Icons.broken_image_outlined,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: GestureDetector(
                                      onTap: () => setState(
                                        () => _attachedImagePaths.remove(path),
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(
                                            alpha: 0.6,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          size: 12,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: AppSpacing.s8),

                // -- Bottom toolbar --
                _buildBottomToolbar(isDark, l10n),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetadataChips(bool isDark) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          if (_selectedPriority != null)
            Padding(
              padding:
                  const EdgeInsets.only(right: 6, top: 4, bottom: 4),
              child: Chip(
                label: Text(
                  _selectedPriority!,
                  style: AppTextStyles.caption,
                ),
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
          if (_selectedTagIds.isNotEmpty)
            Padding(
              padding:
                  const EdgeInsets.only(left: 4, top: 4, bottom: 4),
              child: Chip(
                label: Text(
                  AppLocalizations.of(context)!
                      .tagsCountLabel(_selectedTagIds.length),
                  style: AppTextStyles.caption,
                ),
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

  /// Toggle voice dictation: interim results stream into the text field,
  /// finalized words are committed on completion.
  Future<void> _toggleDictation() async {
    if (_isListening) {
      await _stt.stop();
      setState(() => _isListening = false);
      return;
    }

    if (!_sttReady) {
      try {
        _sttReady = await _stt.initialize(
          onStatus: (status) {
            if ((status == 'done' || status == 'notListening') && mounted) {
              setState(() => _isListening = false);
            }
          },
          onError: (e) {
            debugPrint('QuickCapture: stt error: ${e.errorMsg}');
            if (mounted) setState(() => _isListening = false);
          },
        );
      } catch (e) {
        debugPrint('QuickCapture: stt init failed: $e');
      }
    }
    if (!_sttReady) {
      if (mounted) {
        AppSnackBar.error(context, message: '语音识别不可用');
      }
      return;
    }

    _dictationBase = _contentController.text;
    setState(() => _isListening = true);
    await _stt.listen(
      onResult: (result) {
        if (!mounted) return;
        final separator = _dictationBase.isEmpty ? '' : '\n';
        _contentController.value = TextEditingValue(
          text: '$_dictationBase$separator${result.recognizedWords}',
          selection: TextSelection.collapsed(
            offset: _dictationBase.length + 1 + result.recognizedWords.length,
          ),
        );
      },
      localeId: 'zh_CN',
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
      ),
    );
  }

  /// If the whole capture is a bare URL, expand it into a link snippet with
  /// the page <title> fetched client-side (no server involvement).
  Future<void> _expandUrlIfNeeded() async {
    final text = _contentController.text.trim();
    final url = RegExp(r'^https?://\S+$').firstMatch(text);
    if (url == null) return;

    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
      final req = await client.getUrl(Uri.parse(text));
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      client.close();
      final match =
          RegExp(r'<title[^>]*>([^<]{1,200})</title>', caseSensitive: false)
              .firstMatch(body);
      final title = match?.group(1)?.trim();
      if (title != null && title.isNotEmpty && mounted) {
        _contentController.value = TextEditingValue(
          text: '[$title]($text)',
          selection: TextSelection.collapsed(offset: title.length + 4),
        );
      }
    } catch (e) {
      debugPrint('QuickCapture: URL title fetch failed: $e');
    }
  }

  /// Pick an image (gallery/camera), store it, and stage it as an
  /// attachment. Saved into the note body as a markdown image reference.
  Future<void> _attachImage() async {
    final l10n = AppLocalizations.of(context)!;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.fromGallery),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(l10n.fromCamera),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1920,
        imageQuality: 85,
      );
      if (picked == null) return;
      final noteId = _savedNoteId ?? const Uuid().v4();
      final path = await ImageStorage.saveImage(
        await picked.readAsBytes(),
        noteId,
      );
      if (mounted) {
        setState(() => _attachedImagePaths.add(path));
        _scheduleAutoSave();
      }
    } catch (e) {
      debugPrint('QuickCapture: image attach failed: $e');
    }
  }

  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(AppDurations.snackbarDuration, () {
      if (mounted) _saveNote(showIndicator: true);
    });
  }

  Widget _buildBottomToolbar(bool isDark, AppLocalizations l10n) {
    final tertiaryColor =
        isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;

    return Row(
      children: [
        // Secondary actions — small tertiary icon buttons.
        IconButton(
          icon: Badge(
            isLabelVisible: _selectedTagIds.isNotEmpty,
            label: Text('${_selectedTagIds.length}'),
            child: Icon(AppIcons.tag, color: tertiaryColor),
          ),
          tooltip: l10n.tags,
          onPressed: _showTagPicker,
        ),
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
                ? AppColors.error
                : _selectedPriority == 'Medium'
                    ? AppColors.warning
                    : _selectedPriority == 'Low'
                        ? AppColors.success
                        : tertiaryColor,
          ),
          tooltip: l10n.setPriority,
          onPressed: _showPrioritySelector,
        ),
        IconButton(
          icon: Icon(
            _isListening ? Icons.mic : Icons.mic_none,
            color: _isListening ? AppColors.error : tertiaryColor,
          ),
          tooltip: '语音输入',
          onPressed: _toggleDictation,
        ),
        // Attach image — capture modality from scenario 1.
        IconButton(
          icon: Badge(
            isLabelVisible: _attachedImagePaths.isNotEmpty,
            label: Text('${_attachedImagePaths.length}'),
            child: Icon(Icons.image_outlined, color: tertiaryColor),
          ),
          tooltip: l10n.addImage,
          onPressed: _attachImage,
        ),
        const Spacer(),
        if (_isSaving)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: tertiaryColor,
              ),
            ),
          ),
        // Save — purple circular check button per the design mockup.
        SizedBox(
          width: 48,
          height: 48,
          child: IconButton(
            icon: const Icon(AppIcons.check, size: 24),
            tooltip: l10n.saveAndClose,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
            ),
            onPressed: _saveAndClose,
          ),
        ),
      ],
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
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
