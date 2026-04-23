import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../l10n/app_localizations.dart';
import '../../../main.dart';
import '../../../core/collab/crdt_text.dart';
import '../../../core/collab/presence_indicator.dart';
import '../../../core/collab/ws_client.dart';
import '../../../core/crypto/crypto_service.dart';
import '../../../core/database/app_database.dart';
import '../../../core/error/error.dart';
import '../../../core/performance/performance_monitor.dart';
import '../../../core/storage/image_storage.dart';
import '../../../core/widgets/markdown_preview.dart';
import '../../collab/providers/collab_provider.dart';
import 'widgets/backlinks_sheet.dart';
import 'widgets/character_count_bar.dart';
import 'widgets/collab_cursors_widget.dart';
import 'widgets/rich_editor_with_shortcuts.dart';
import 'widgets/tag_picker_sheet.dart';
import 'widgets/zen_mode_chrome.dart';
import 'widgets/summary_sheet.dart';
import 'widgets/ai_tag_suggestion.dart';
import 'widgets/translation_sheet.dart';
import 'widgets/writing_assist_sheet.dart';

class NoteEditorScreen extends ConsumerStatefulWidget {
  /// Optional initial content to pre-fill the editor (e.g. from a template).
  final String? initialContent;

  /// Optional existing note ID. When provided with [isCollab], the editor
  /// opens in real-time collaboration mode using CRDT-backed editing.
  final String? noteId;

  /// Whether to activate real-time collaboration for this note.
  /// When true, edits are converted to CRDT operations and broadcast
  /// via WebSocket. When false (default), the editor uses the standard
  /// local-only flow.
  final bool isCollab;

  const NoteEditorScreen({
    super.key,
    this.initialContent,
    this.noteId,
    this.isCollab = false,
  });

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen>
    with TickerProviderStateMixin {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _quillController = quill.QuillController.basic();
  final _editorFocusNode = FocusNode();
  final _bodyScrollController = ScrollController();

  Timer? _debounce;
  Timer? _presenceDebounce;
  String? _noteId;
  bool _isNew = true;
  bool _isSaving = false;
  bool _isPreview = false;
  bool _useRichEditor = true;
  String? _errorMessage;

  // CRDT collab mode state
  bool get _isCollab => widget.isCollab;

  // Zen / focus mode state
  bool _isZenMode = false;
  AnimationController? _zenChromeAnimController;

  // Word / character count
  int _wordCount = 0;
  int _charCount = 0;

  /// Pre-compiled regex for splitting text into words (avoids recompilation per keystroke).
  static final RegExp _wordSplitRegex = RegExp(r'\s+');

  /// Debounce timer for word/character count updates.
  Timer? _countDebounceTimer;

  /// Preference key for storing the last edit/preview mode.
  static const _prefKeyPreviewMode = 'editor_preview_mode';

  @override
  void initState() {
    super.initState();

    // Use the provided noteId if opening an existing note, otherwise generate.
    _noteId = widget.noteId ?? const Uuid().v4();
    _isNew = widget.noteId == null;

    _contentController.addListener(_onContentChanged);
    _quillController.addListener(_onContentChanged);

    // Zen mode chrome fade animation (300ms).
    _zenChromeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1.0, // chrome visible by default
    );

    // Pre-fill with initial content if provided (e.g. from a template).
    if (widget.initialContent != null && widget.initialContent!.isNotEmpty) {
      _contentController.text = widget.initialContent!;
      // Also set quill controller content so it is available in rich mode.
      _quillController.document.insert(0, widget.initialContent!);
    }

    // Load saved preview mode preference.
    _loadPreviewPreference();

    // Initial count.
    _updateCounts();

    // Post-frame setup: presence room and optional CRDT collab mode.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _joinPresenceRoom();
      if (_isCollab) {
        _initCollabMode();
      }
    });
  }

  /// Join the WebSocket presence room so that collaborators can see
  /// each other's active status and typing indicators.
  void _joinPresenceRoom() {
    final wsState = ref.read(wsClientProvider);
    if (wsState == WSConnectionState.connected) {
      ref.read(wsClientProvider.notifier).client.joinRoom(_noteId!);
    }
  }

  /// Initialize CRDT collaboration mode for this note.
  ///
  /// Attempts to load persisted CRDT state from the database. If none exists,
  /// creates a fresh CRDT document initialized with the current editor content.
  /// Then joins the collab room via the collab provider.
  Future<void> _initCollabMode() async {
    try {
      final db = ref.read(databaseProvider);
      final persisted = await db.collabDao.loadState(_noteId!);

      CRDTText? existingCrdt;
      if (persisted != null) {
        try {
          final json =
              jsonDecode(persisted.documentState) as Map<String, dynamic>;
          existingCrdt = CRDTText.fromJson(json);
        } catch (_) {
          // Corrupted state; start fresh.
        }
      }

      // Join collab room via the provider, which creates the CRDT editor
      // controller and starts routing operations.
      ref.read(collabProvider.notifier).joinRoom(
            _noteId!,
            existingCrdt: existingCrdt,
          );
    } catch (_) {
      // Collab init failure should not block the editor. The user can still
      // edit locally; changes just will not be synced in real-time.
    }
  }

  /// Loads the last edit/preview mode from SharedPreferences.
  Future<void> _loadPreviewPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPreview = prefs.getBool(_prefKeyPreviewMode) ?? false;
    if (savedPreview != _isPreview && mounted) {
      setState(() => _isPreview = savedPreview);
    }
  }

  /// Persists the current edit/preview mode to SharedPreferences.
  Future<void> _savePreviewPreference(bool isPreview) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyPreviewMode, isPreview);
  }

  void _onContentChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), _saveNote);
    // Debounce count updates to avoid recalculating on every keystroke.
    _countDebounceTimer?.cancel();
    _countDebounceTimer =
        Timer(const Duration(milliseconds: 300), _updateCounts);
    // Debounce presence typing indicator (send at most once per second).
    _presenceDebounce?.cancel();
    _presenceDebounce =
        Timer(const Duration(seconds: 1), _notifyPresenceTyping);
  }

  /// Send a typing indicator to the presence room.
  void _notifyPresenceTyping() {
    if (_noteId != null) {
      ref.read(presenceProvider.notifier).sendTyping(_noteId!);
    }
  }

  /// Recalculate word and character counts from the current editor content.
  void _updateCounts() {
    final text = _extractPlainText();
    final chars = text.length;
    // Word count: split on whitespace, filter empty strings.
    final words =
        text.trim().isEmpty ? 0 : text.trim().split(_wordSplitRegex).length;

    if (_wordCount != words || _charCount != chars) {
      setState(() {
        _wordCount = words;
        _charCount = chars;
      });
    }
  }

  // ── Zen mode ──────────────────────────────────────────

  void _toggleZenMode() {
    setState(() {
      _isZenMode = !_isZenMode;
    });
    if (_isZenMode) {
      // Hide system UI for a distraction-free experience.
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      _zenChromeAnimController!.reverse();
    } else {
      // Restore system UI.
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
      );
      _zenChromeAnimController!.forward();
    }
  }

  void _exitZenMode() {
    if (_isZenMode) {
      _toggleZenMode();
    }
  }

  // ── Typewriter scrolling ──────────────────────────────

  /// Keeps the cursor vertically centered in the body text field by adjusting
  /// the scroll offset when the cursor position changes. Applies a smooth
  /// animation with Curves.easeOutCubic over 200ms.
  void _scrollToCenterCursor() {
    if (!_bodyScrollController.hasClients) return;

    // For the plain text editor, we can estimate cursor line position.
    // For the rich editor, quill manages its own scroll view via the
    // scrollController passed to RichNoteEditor.
    if (!_useRichEditor) {
      // Plain text: approximate vertical position by counting newlines
      // up to the cursor.
      final controller = _effectiveContentController;
      final text = controller.text;
      final cursorPos = controller.selection.baseOffset;
      if (cursorPos < 0) return;

      const lineHeight = 16.0 * 1.6; // fontSize * height
      final linesBeforeCursor =
          '\n'.allMatches(text.substring(0, cursorPos)).length;
      final cursorY = linesBeforeCursor * lineHeight + 16.0; // + padding

      final viewportHeight = _bodyScrollController.position.viewportDimension;
      if (viewportHeight <= 0) return;

      final targetOffset = (cursorY - viewportHeight / 2)
          .clamp(0.0, _bodyScrollController.position.maxScrollExtent);

      _bodyScrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      );
    }
    // For the rich editor, typewriter scrolling is handled inside
    // RichNoteEditor via the shared scrollController. The quill editor
    // exposes cursor position through its render metrics; we use a
    // post-frame callback to avoid accessing render objects during build.
  }

  Future<void> _saveNote() async {
    if (_isSaving) return;

    final pm = PerformanceMonitor.instance;
    pm.start('note_save');
    final title = _titleController.text.trim();
    final content = _getContentForSave();
    final plainText = _extractPlainText();

    if (plainText.isEmpty && title.isEmpty) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final db = ref.read(databaseProvider);
      final crypto = ref.read(cryptoServiceProvider);
      final noteId = _noteId!;

      String encryptedContent;
      String? encryptedTitle;

      if (crypto.isUnlocked) {
        // Real encryption path: encrypt both title and content with per-item keys
        encryptedContent = await crypto.encryptForItem(noteId, content);
        if (title.isNotEmpty) {
          encryptedTitle = await crypto.encryptForItem(noteId, title);
        } else {
          encryptedTitle = null;
        }
      } else {
        // Fallback when encryption is not set up: store plaintext directly.
        // This should only happen during initial onboarding before the user
        // has set a password.
        encryptedContent = content;
        encryptedTitle = title.isNotEmpty ? title : null;
      }

      if (_isNew) {
        await db.notesDao.createNote(
          id: noteId,
          encryptedContent: encryptedContent,
          encryptedTitle: encryptedTitle,
          plainContent: plainText,
          plainTitle: title.isEmpty ? null : title,
        );
        _isNew = false;
      } else {
        // Save a version snapshot before updating the existing note.
        await _saveVersionSnapshot(db, noteId);

        await db.notesDao.updateNote(
          id: noteId,
          encryptedContent: encryptedContent,
          encryptedTitle: encryptedTitle,
          plainContent: plainText,
          plainTitle: title.isEmpty ? null : title,
        );
      }
      pm.end('note_save');
    } catch (e) {
      // Store the error but do not lose the user's input.
      // The debounced save will retry automatically.
      pm.end('note_save');
      if (mounted) {
        final appError = ErrorMapper.map(e);
        setState(() {
          _errorMessage = ErrorDisplay.userMessage(appError);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _presenceDebounce?.cancel();
    _countDebounceTimer?.cancel();
    _titleController.dispose();
    _contentController.dispose();
    _quillController.dispose();
    _editorFocusNode.dispose();
    _bodyScrollController.dispose();
    _zenChromeAnimController?.dispose();

    // Persist CRDT state and leave collab room if in collab mode.
    if (_isCollab && _noteId != null) {
      _persistCollabState();
      ref.read(collabProvider.notifier).leaveRoom();
    }

    // Leave presence room.
    ref.read(presenceProvider.notifier).leaveRoom();
    // Restore system UI when leaving the editor.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  /// Persist the CRDT document state to the database so that offline edits
  /// are preserved and can be resumed when the note is opened again.
  Future<void> _persistCollabState() async {
    try {
      final collabState = ref.read(collabProvider);
      final controller = collabState.editorController;
      if (controller == null) return;

      final crdt = controller.crdt;
      final stateJson = jsonEncode(crdt.toJson());

      final db = ref.read(databaseProvider);
      await db.collabDao.saveState(
        noteId: _noteId!,
        documentState: stateJson,
        lastVersion: crdt.clock,
      );
    } catch (_) {
      // Persistence failure should not crash the app on dispose.
    }
  }

  /// Returns the content to encrypt and store:
  /// - Collab mode: text from the CRDT document
  /// - Rich editor: Delta JSON string
  /// - Plain text: raw text from the text controller
  String _getContentForSave() {
    if (_isCollab) {
      // In collab mode, always use plain text from the CRDT.
      // The CRDT controller manages its own TextEditingController.
      final collabState = ref.read(collabProvider);
      return collabState.editorController?.textController.text ??
          _contentController.text;
    }
    if (_useRichEditor) {
      return jsonEncode(_quillController.document.toDelta().toJson());
    }
    return _contentController.text;
  }

  /// Returns plain text for FTS5 search indexing.
  String _extractPlainText() {
    if (_isCollab) {
      final collabState = ref.read(collabProvider);
      return collabState.editorController?.textController.text ??
          _contentController.text;
    }
    if (_useRichEditor) {
      return _quillController.document.toPlainText();
    }
    return _contentController.text;
  }

  /// Returns the effective text controller for the content field.
  /// In collab mode, uses the CRDT editor controller's text controller.
  /// Otherwise, uses the standard [_contentController].
  TextEditingController get _effectiveContentController {
    if (_isCollab) {
      final collabState = ref.read(collabProvider);
      return collabState.editorController?.textController ?? _contentController;
    }
    return _contentController;
  }

  /// Save a version snapshot of the current note state before overwriting it.
  /// Keeps only the last 20 versions per note.
  Future<void> _saveVersionSnapshot(AppDatabase db, String noteId) async {
    try {
      final currentNote = await db.notesDao.getNoteById(noteId);
      if (currentNote == null) return;

      final count = await db.noteVersionsDao.getVersionCount(noteId);
      final versionId = const Uuid().v4();

      await db.noteVersionsDao.createVersion(
        id: versionId,
        noteId: noteId,
        encryptedTitle: currentNote.encryptedTitle,
        plainTitle: currentNote.plainTitle,
        encryptedContent: currentNote.encryptedContent,
        plainContent: currentNote.plainContent,
        versionNumber: count + 1,
      );

      // Trim old versions, keeping only the last 20.
      await db.noteVersionsDao.deleteVersionsOlderThan(noteId, 20);
    } catch (_) {
      // Version snapshot failure should not block the save.
      // The user's content is more important than version history.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    // Zen mode: use a full-screen scaffold with no chrome.
    // The AnimatedBuilder fades app bar and bottom elements in/out.
    return Scaffold(
      // In zen mode, extend behind the status bar / navigation bar.
      extendBodyBehindAppBar: _isZenMode,
      extendBody: _isZenMode,
      appBar: _isZenMode
          ? null
          : AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: l10n.saveAndClose,
                onPressed: () => context.pop(),
              ),
              actions: [
                // Presence avatars showing active collaborators.
                if (_noteId != null)
                  PresenceAvatarStack(
                    users: ref.watch(presenceProvider).values.toList(),
                  ),
                if (_isSaving)
                  Semantics(
                    label: l10n.savingNote,
                    liveRegion: true,
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                IconButton(
                  icon: Icon(
                    _useRichEditor ? Icons.short_text : Icons.text_fields,
                  ),
                  tooltip: _useRichEditor ? l10n.plainText : l10n.richText,
                  onPressed: () {
                    setState(() => _useRichEditor = !_useRichEditor);
                  },
                ),
                IconButton(
                  icon: Icon(_isPreview ? Icons.edit : Icons.visibility),
                  tooltip: _isPreview ? l10n.edit : l10n.preview,
                  onPressed: () {
                    final newValue = !_isPreview;
                    setState(() => _isPreview = newValue);
                    _savePreviewPreference(newValue);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.sell_outlined),
                  tooltip: l10n.manageTags,
                  onPressed: () => _showTagPicker(context),
                ),
                if (!_isNew)
                  IconButton(
                    icon: const Icon(Icons.link_outlined),
                    tooltip: l10n.viewBacklinks,
                    onPressed: () => _showBacklinks(context),
                  ),
                IconButton(
                  icon: const Icon(Icons.image_outlined),
                  tooltip: l10n.addImage,
                  onPressed: () => _pickImage(context),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.auto_awesome_outlined),
                  tooltip: l10n.aiFeatures,
                  onSelected: (value) => _handleAiAction(context, value),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'summary',
                      child: ListTile(
                        leading: const Icon(Icons.summarize_outlined),
                        title: Text(l10n.smartSummary),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'tags',
                      child: ListTile(
                        leading: const Icon(Icons.sell_outlined),
                        title: Text(l10n.aiTagSuggestion),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'translate',
                      child: ListTile(
                        leading: const Icon(Icons.translate),
                        title: Text(l10n.aiTranslation),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'polish',
                      child: ListTile(
                        leading: const Icon(Icons.spellcheck),
                        title: Text(l10n.writingPolish),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.check),
                  tooltip: l10n.saveAndClose,
                  onPressed: () async {
                    await _saveNote();
                    if (context.mounted) context.pop();
                  },
                ),
              ],
            ),
      body: _buildBody(context, l10n, colorScheme),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    return Column(
      children: [
        // Error banner (always visible, even in zen mode).
        if (_errorMessage != null)
          Semantics(
            liveRegion: true,
            label: 'Error: $_errorMessage',
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: colorScheme.errorContainer,
              child: Text(
                _errorMessage!,
                style: TextStyle(
                  color: colorScheme.onErrorContainer,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              // In zen mode, add top padding for status bar area.
              top: _isZenMode ? MediaQuery.of(context).padding.top + 8 : 0,
              bottom: 0,
            ),
            child: Column(
              children: [
                // Zen mode: show a minimal back button + focus icon.
                if (_isZenMode)
                  ZenModeChrome(
                    animation: _zenChromeAnimController!,
                    onExit: _exitZenMode,
                    onToggle: _toggleZenMode,
                  ),

                // Title field.
                Semantics(
                  label: 'Note title',
                  child: TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      hintText: l10n.title,
                      border: InputBorder.none,
                    ),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(),
                Expanded(
                  child: _buildEditorWithCollabCursors(
                    context,
                    l10n,
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: _isPreview
                          ? SingleChildScrollView(
                              key: const ValueKey('preview'),
                              padding: const EdgeInsets.only(bottom: 16),
                              child: MarkdownPreview(
                                content: _extractPlainText(),
                              ),
                            )
                          : _useRichEditor
                              ? KeyedSubtree(
                                  key: const ValueKey('rich_editor'),
                                  child: RichEditorWithShortcuts(
                                    quillController: _quillController,
                                    focusNode: _editorFocusNode,
                                    onExitZenMode: _exitZenMode,
                                    onToggleHeading: _toggleHeading,
                                    onToggleBulletList: _toggleBulletList,
                                  ),
                                )
                              : Semantics(
                                  key: const ValueKey('plain_editor'),
                                  label: l10n.noteContent,
                                  child: TextField(
                                    controller: _effectiveContentController,
                                    scrollController: _bodyScrollController,
                                    decoration: InputDecoration(
                                      hintText: l10n.startWriting,
                                      border: InputBorder.none,
                                    ),
                                    maxLines: null,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      height: 1.6,
                                    ),
                                    onChanged: (_) =>
                                        _scheduleTypewriterScroll(),
                                  ),
                                ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Typing indicator for collaborators.
        if (_noteId != null)
          TypingIndicatorText(
            typingUsers: ref
                .watch(presenceProvider)
                .values
                .where((u) => u.isTyping)
                .toList(),
          ),

        // Animated word / character count bar.
        CharacterCountBar(
          wordCount: _wordCount,
          charCount: _charCount,
          isZenMode: _isZenMode,
          onToggleZenMode: _toggleZenMode,
        ),
      ],
    );
  }

  // ── Collab cursor wrapper ────────────────────────────

  /// Wraps the editor child with [CollabCursorsWidget] when in collab mode.
  Widget _buildEditorWithCollabCursors(
    BuildContext context,
    AppLocalizations l10n,
    Widget editorChild,
  ) {
    if (_isCollab && _noteId != null) {
      return CollabCursorsWidget(noteId: _noteId!, child: editorChild);
    }
    return editorChild;
  }

  /// Show backlinks bottom sheet for the current note.
  void _showBacklinks(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => BacklinksSheet(noteId: _noteId!),
    );
  }

  // ── Typewriter scroll scheduling ──────────────────────

  /// Schedules a typewriter scroll after the current frame so that layout
  /// has settled and scroll metrics are accurate.
  void _scheduleTypewriterScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scrollToCenterCursor();
      }
    });
  }

  /// Toggle heading level on the current selection.
  /// If the selection already has the given heading level, remove it.
  void _toggleHeading(int level) {
    final attr = switch (level) {
      1 => quill.Attribute.h1,
      2 => quill.Attribute.h2,
      3 => quill.Attribute.h3,
      _ => quill.Attribute.h1,
    };

    // Check if the current selection already has this heading.
    final currentStyle = _quillController.getSelectionStyle();
    final existingHeading = currentStyle.attributes[quill.Attribute.header.key];
    if (existingHeading != null && existingHeading.value == level) {
      // Toggle off: remove heading.
      _quillController.formatSelection(quill.Attribute.header);
    } else {
      _quillController.formatSelection(attr);
    }
  }

  /// Toggle bullet list on the current selection.
  void _toggleBulletList() {
    final currentStyle = _quillController.getSelectionStyle();
    final isBulletList =
        currentStyle.attributes.containsKey(quill.Attribute.list.key) &&
            currentStyle.attributes[quill.Attribute.list.key]!.value ==
                quill.Attribute.ul.value;

    if (isBulletList) {
      _quillController.formatSelection(quill.Attribute.list);
    } else {
      _quillController.formatSelection(quill.Attribute.ul);
    }
  }

  // ── AI Feature Actions ─────────────────────────────

  /// Handle selection from the AI features popup menu.
  void _handleAiAction(BuildContext context, String action) {
    final plainText = _extractPlainText();
    final controller = _effectiveContentController;

    switch (action) {
      case 'summary':
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => SummarySheet(
            content: plainText,
            onReplace: (summary) {
              controller.text = summary;
              _saveNote();
            },
          ),
        );
      case 'tags':
        // Ensure note is saved before managing tags.
        _saveNote();
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => AiTagSuggestionSheet(
            content: plainText,
            onApply: (acceptedTags) {
              // Apply accepted tags by saving them to the note.
              _applySuggestedTags(acceptedTags);
            },
          ),
        );
      case 'translate':
        final selectedText = _getSelectedText();
        final textToTranslate =
            selectedText.isNotEmpty ? selectedText : plainText;
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => TranslationSheet(
            text: textToTranslate,
            onReplace: (translated) {
              _replaceSelectedOrAllText(translated, selectedText.isEmpty);
            },
            onInsertBelow: (translated) {
              _insertTextBelow(translated);
            },
          ),
        );
      case 'polish':
        final selectedText = _getSelectedText();
        final textToPolish = selectedText.isNotEmpty ? selectedText : plainText;
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => WritingAssistSheet(
            originalText: textToPolish,
            onAccept: (corrected) {
              _replaceSelectedOrAllText(corrected, selectedText.isEmpty);
            },
          ),
        );
    }
  }

  /// Get the currently selected text, or empty string if no selection.
  String _getSelectedText() {
    if (_useRichEditor) {
      return _quillController.selection.isCollapsed
          ? ''
          : _quillController.document.toPlainText().substring(
                _quillController.selection.start,
                _quillController.selection.end,
              );
    }
    final controller = _effectiveContentController;
    return controller.selection.isCollapsed
        ? ''
        : controller.text.substring(
            controller.selection.start,
            controller.selection.end,
          );
  }

  /// Replace the selected text, or all text if [replaceAll] is true.
  void _replaceSelectedOrAllText(String newText, bool replaceAll) {
    final controller = _effectiveContentController;
    if (replaceAll) {
      controller.text = newText;
    } else {
      final sel = controller.selection;
      controller.text = controller.text.replaceRange(
        sel.start,
        sel.end,
        newText,
      );
    }
    _saveNote();
  }

  /// Insert text below the current cursor position.
  void _insertTextBelow(String text) {
    final controller = _effectiveContentController;
    final cursorPos = controller.selection.end;
    final insertPos = cursorPos >= 0 ? cursorPos : controller.text.length;
    controller.text =
        '${controller.text.substring(0, insertPos)}\n$text${controller.text.substring(insertPos)}';
    _saveNote();
  }

  /// Apply AI-suggested tags to the current note.
  Future<void> _applySuggestedTags(Set<String> tags) async {
    try {
      final db = ref.read(databaseProvider);
      final crypto = ref.read(cryptoServiceProvider);
      for (final tagName in tags) {
        final tagId = const Uuid().v4();
        final encryptedName = crypto.isUnlocked
            ? await crypto.encryptForItem(tagId, tagName)
            : tagName;
        await db.tagsDao.createTag(
          id: tagId,
          encryptedName: encryptedName,
          plainName: tagName,
        );
        // Link tag to the current note.
        await db.notesDao.addTagToNote(_noteId!, tagId);
      }
    } catch (_) {
      // Tag application failure should not crash the editor.
    }
  }

  /// Opens a bottom sheet to pick and manage tags for the current note.
  void _showTagPicker(BuildContext context) {
    // Ensure the note is saved before managing tags.
    _saveNote();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => TagPickerSheet(
        noteId: _noteId!,
        db: ref.read(databaseProvider),
        crypto: ref.read(cryptoServiceProvider),
      ),
    );
  }

  /// Pick an image from the gallery and insert a markdown reference.
  Future<void> _pickImage(BuildContext context) async {
    // Image picking via file system is not available on web platform.
    if (kIsWeb) {
      if (!context.mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.failedToAddImage('Not available on web'))),
      );
      return;
    }

    try {
      final picker = ImagePicker();
      final xFile = await picker.pickImage(source: ImageSource.gallery);
      if (xFile == null) return;

      final bytes = await File(xFile.path).readAsBytes();
      final localPath = await ImageStorage.saveImage(bytes, _noteId!);

      // Insert markdown image reference at the end of content.
      final controller = _effectiveContentController;
      final currentText = controller.text;
      final imageRef = '\n![image](file://$localPath)\n';
      controller.text = currentText + imageRef;

      // Trigger auto-save.
      _saveNote();
    } catch (e) {
      if (!context.mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.failedToAddImage(e.toString()))),
      );
    }
  }
}
