import 'dart:async';
import 'dart:convert';
import 'dart:io' if (dart.library.js) 'package:anynote/core/stubs/io_stub.dart';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
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
import '../../../features/collab/presentation/share_dialog.dart';
import '../../../core/crypto/crypto_service.dart';
import '../../../core/tts/speech_service.dart';
import '../../../core/database/app_database.dart';
import '../../../core/error/error.dart';
import '../../../core/performance/performance_monitor.dart';
import '../../../core/storage/image_storage.dart';
import '../../../core/widgets/keyboard_shortcuts.dart';
import '../../../core/widgets/markdown_preview.dart';
import '../../collab/providers/collab_provider.dart';
import 'widgets/backlinks_sheet.dart';
import 'widgets/character_count_bar.dart';
import 'widgets/command_palette.dart';
import 'widgets/related_notes_sheet.dart';
import 'widgets/collab_cursors_widget.dart';
import 'widgets/rich_editor_with_shortcuts.dart';
import 'widgets/tag_picker_sheet.dart';
import 'widgets/tts_player_bar.dart';
import 'widgets/slash_command_menu.dart';
import 'widgets/zen_mode_chrome.dart';
import 'widgets/summary_sheet.dart';
import 'widgets/ai_tag_suggestion.dart';
import 'widgets/translation_sheet.dart';
import 'widgets/writing_assist_sheet.dart';
import 'widgets/wiki_link_picker_sheet.dart';
import 'widgets/properties_sheet.dart';
import 'embeds/transclusion_embed.dart';
import 'embeds/wiki_link_embed.dart';
import 'widgets/focus_highlight.dart';
import 'widgets/folded_outline_view.dart';
import 'widgets/section_fold_bar.dart';
import 'widgets/section_fold_controller.dart';
import 'widgets/writing_stats.dart';
import 'widgets/writing_stats_bar.dart';
import 'widgets/reminder_picker_sheet.dart';
import 'widgets/print_preview_sheet.dart';
import 'widgets/editor_drop_target.dart';
import 'widgets/editor_app_bar_actions.dart';
import 'widgets/formatting_toolbar.dart';
import 'widgets/find_replace_bar.dart';
import '../../../core/notifications/reminder_service.dart';
import '../../../core/database/daos/note_properties_dao.dart';
import '../../../core/constants/app_durations.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/offline_banner.dart';

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
  bool _isDirty = false;
  bool _isPreview = false;
  bool _useRichEditor = true;
  String? _errorMessage;

  // Lock state: when true, the note is read-only.
  bool _isLocked = false;

  // Wiki link detection state
  Timer? _wikiLinkDebounce;

  // Transclusion detection state
  Timer? _transclusionDebounce;

  // CRDT collab mode state
  bool get _isCollab => widget.isCollab;

  // Zen / focus mode state
  bool _isZenMode = false;
  AnimationController? _zenChromeAnimController;

  // Typewriter scrolling toggle
  bool _isTypewriterScroll = false;

  // Focus mode (dim non-current lines)
  bool _isFocusMode = false;

  // Fold / outline view mode
  bool _isFoldView = false;
  final SectionFoldController _foldController = SectionFoldController();

  // Writing stats bar visibility
  bool _isWritingStatsVisible = true;

  // Word / character count
  int _wordCount = 0;
  int _charCount = 0;

  // Computed writing stats (updated with debounce)
  WritingStats _writingStats = WritingStats.empty;

  /// Pre-compiled regex for splitting text into words (avoids recompilation per keystroke).
  static final RegExp _wordSplitRegex = RegExp(r'\s+');

  /// Debounce timer for word/character count updates.
  Timer? _countDebounceTimer;

  // Reminder state for the current note.
  ReminderEntry? _currentReminder;
  Stream<ReminderEntry?>? _reminderStream;

  // Find & replace state.
  bool _showFindReplace = false;
  final TextEditingController _findController = TextEditingController();
  final TextEditingController _replaceController = TextEditingController();
  final FindReplaceController _findReplaceCtrl = FindReplaceController();

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
      duration: AppDurations.animation,
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
      // Track recently opened notes for the command palette.
      if (!_isNew && _noteId != null) {
        addRecentlyOpened(ref, _noteId!);
      }
      // Start watching the reminder for this note.
      _initReminderWatcher();
      // Check if note is locked and watch for changes.
      _initLockWatcher();
      // Wire Ctrl+P to open the print preview sheet.
      if (!_isNew && _noteId != null) {
        AppKeyboardShortcuts.setPrintCallback(() => _showPrintPreview(context));
      }
      // Wire Ctrl+F to open the find/replace bar in the editor.
      AppKeyboardShortcuts.setFindCallback(_openFindReplace);
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
        } catch (e) {
          debugPrint('[NoteEditor] Corrupted CRDT state, starting fresh: $e');
          // Corrupted state; start fresh.
        }
      }

      // Join collab room via the provider, which creates the CRDT editor
      // controller and starts routing operations.
      ref.read(collabProvider.notifier).joinRoom(
            _noteId!,
            existingCrdt: existingCrdt,
          );
    } catch (e) {
      debugPrint('[NoteEditor] Collab init failure: $e');
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
    _debounce = Timer(AppDurations.autoSaveDelay, _saveNote);
    // Mark content as having unsaved changes.
    if (!_isDirty) {
      setState(() => _isDirty = true);
    }
    // Debounce count updates to avoid recalculating on every keystroke.
    _countDebounceTimer?.cancel();
    _countDebounceTimer = Timer(AppDurations.debounce, _updateCounts);
    // Debounce presence typing indicator (send at most once per second).
    _presenceDebounce?.cancel();
    _presenceDebounce =
        Timer(AppDurations.autoSaveDelay, _notifyPresenceTyping);
    // Check for wiki link [[ pattern in rich editor mode.
    if (_useRichEditor && !_isCollab) {
      _checkWikiLinkPattern();
      _checkTransclusionPattern();
    }
    // Schedule typewriter scroll if enabled.
    if (_isTypewriterScroll) {
      _scheduleTypewriterScroll();
    }
  }

  /// Checks if user just typed [[ and shows the note picker sheet.
  void _checkWikiLinkPattern() {
    if (_noteId == null) return;

    final sel = _quillController.selection;
    if (!sel.isCollapsed) return;

    final cursorPos = sel.baseOffset;
    final plainText = _quillController.document.toPlainText();

    if (cursorPos < 2) return;

    final lastTwoChars = plainText.substring(cursorPos - 2, cursorPos);
    if (lastTwoChars == '[[') {
      _wikiLinkDebounce?.cancel();
      _wikiLinkDebounce = Timer(AppDurations.debounce, () {
        if (mounted) {
          _showWikiLinkPicker();
        }
      });
    }
  }

  /// Shows the wiki link picker sheet for selecting a note to link.
  void _showWikiLinkPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => WikiLinkPickerSheet(
        query: '',
        sourceNoteId: _noteId!,
        onSelect: (noteId, title) {
          _insertWikiLink(noteId, title);
        },
      ),
    );
  }

  /// Inserts a wiki link embed at the current cursor position.
  void _insertWikiLink(String noteId, String title) {
    final sel = _quillController.selection;
    final cursorPos = sel.baseOffset;

    if (cursorPos >= 2) {
      final plainText = _quillController.document.toPlainText();
      final beforeCursor = plainText.substring(cursorPos - 2, cursorPos);
      if (beforeCursor == '[[') {
        _quillController.document.delete(cursorPos - 2, 2);
        _quillController.updateSelection(
          TextSelection.collapsed(offset: cursorPos - 2),
          quill.ChangeSource.local,
        );
      }
    }

    insertWikiLinkEmbed(
      controller: _quillController,
      noteId: noteId,
      title: title,
    );

    _saveNote();
  }

  /// Checks if user just typed ![[ and shows the note picker sheet for transclusion.
  void _checkTransclusionPattern() {
    if (_noteId == null) return;

    final sel = _quillController.selection;
    if (!sel.isCollapsed) return;

    final cursorPos = sel.baseOffset;
    final plainText = _quillController.document.toPlainText();

    if (cursorPos < 3) return;

    final lastThreeChars = plainText.substring(cursorPos - 3, cursorPos);
    if (lastThreeChars == '![[') {
      _transclusionDebounce?.cancel();
      _transclusionDebounce = Timer(AppDurations.debounce, () {
        if (mounted) {
          _showTransclusionPicker();
        }
      });
    }
  }

  /// Shows the note picker sheet for selecting a note to transclude.
  void _showTransclusionPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => WikiLinkPickerSheet(
        query: '',
        sourceNoteId: _noteId!,
        onSelect: (noteId, title) {
          _insertTransclusion(noteId, title);
        },
      ),
    );
  }

  /// Inserts a transclusion embed at the current cursor position.
  void _insertTransclusion(String noteId, String title) {
    final sel = _quillController.selection;
    final cursorPos = sel.baseOffset;

    if (cursorPos >= 3) {
      final plainText = _quillController.document.toPlainText();
      final beforeCursor = plainText.substring(cursorPos - 3, cursorPos);
      if (beforeCursor == '![[') {
        _quillController.document.delete(cursorPos - 3, 3);
        _quillController.updateSelection(
          TextSelection.collapsed(offset: cursorPos - 3),
          quill.ChangeSource.local,
        );
      }
    }

    insertTransclusionEmbed(
      controller: _quillController,
      noteId: noteId,
      title: title,
      depth: 0,
    );

    _saveNote();
  }

  /// Send a typing indicator to the presence room.
  void _notifyPresenceTyping() {
    if (_noteId != null) {
      ref.read(presenceProvider.notifier).sendTyping(_noteId!);
    }
  }

  /// Start watching the reminder for the current note so the bell icon
  /// updates reactively when a reminder is set or removed.
  void _initReminderWatcher() {
    if (_noteId == null || _isNew) return;
    final service = ref.read(reminderServiceProvider);
    _reminderStream = service.watchReminderForNote(_noteId!);
    _reminderStream?.listen((reminder) {
      if (mounted) {
        setState(() => _currentReminder = reminder);
      }
    });
  }

  /// Show the reminder picker bottom sheet for the current note.
  void _showReminderPicker(BuildContext context) {
    _saveNote();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ReminderPickerSheet(
        noteId: _noteId!,
        noteTitle: _titleController.text.trim(),
      ),
    ).then((result) {
      // If a reminder was set or removed, reload the current reminder state.
      if (result == true) {
        _initReminderWatcher();
      }
    });
  }

  /// Check the lock state for the current note and watch for changes.
  void _initLockWatcher() {
    if (_noteId == null || _isNew) return;
    final db = ref.read(databaseProvider);
    db.notePropertiesDao.watchNoteLocked(_noteId!).listen((locked) {
      if (mounted) {
        setState(() => _isLocked = locked);
      }
    });
  }

  /// Toggle the lock state for the current note.
  Future<void> _toggleLock() async {
    if (_noteId == null || _isNew) return;
    final db = ref.read(databaseProvider);
    await db.notePropertiesDao.setNoteLocked(_noteId!, !_isLocked);
    // The watcher will update _isLocked reactively.
  }

  /// Recalculate word and character counts from the current editor content.
  /// Also computes the full [WritingStats] for the stats bar.
  void _updateCounts() {
    final text = _extractPlainText();
    final chars = text.length;
    // Word count: split on whitespace, filter empty strings.
    final words =
        text.trim().isEmpty ? 0 : text.trim().split(_wordSplitRegex).length;

    // Compute full writing stats.
    final stats = WritingStats.fromText(text);

    if (_wordCount != words || _charCount != chars) {
      setState(() {
        _wordCount = words;
        _charCount = chars;
        _writingStats = stats;
      });
    } else if (_writingStats.lineCount != stats.lineCount ||
        _writingStats.paragraphCount != stats.paragraphCount ||
        _writingStats.estimatedReadingTime != stats.estimatedReadingTime) {
      // Even if word/char counts match, line/paragraph/reading time may differ.
      setState(() {
        _writingStats = stats;
      });
    }
  }

  // ── Zen mode ──────────────────────────────────────────

  void _toggleZenMode() {
    setState(() {
      _isZenMode = !_isZenMode;
      if (_isZenMode) {
        // Auto-enable typewriter scroll and focus mode in zen mode.
        _isTypewriterScroll = true;
        _isFocusMode = true;
      }
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
        duration: AppDurations.shortAnimation,
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
      // Mark content as saved after successful persistence.
      if (mounted) {
        setState(() => _isDirty = false);
      }
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
    _foldController.dispose();
    _findController.dispose();
    _replaceController.dispose();

    // Persist CRDT state and leave collab room if in collab mode.
    if (_isCollab && _noteId != null) {
      _persistCollabState();
      ref.read(collabProvider.notifier).leaveRoom();
    }

    // Leave presence room.
    ref.read(presenceProvider.notifier).leaveRoom();
    // Clear keyboard shortcut callbacks registered by this screen.
    AppKeyboardShortcuts.clearPrintCallback();
    AppKeyboardShortcuts.clearFindCallback();
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
    } catch (e) {
      debugPrint('[NoteEditor] Collab state persistence failure: $e');
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
    } catch (e) {
      debugPrint('[NoteEditor] Version snapshot failure: $e');
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
              actions: EditorAppBarActions.buildActions(
                context,
                ref,
                EditorActionsConfig(
                  noteId: _noteId,
                  isNew: _isNew,
                  isLocked: _isLocked,
                  isSaving: _isSaving,
                  isDirty: _isDirty,
                  useRichEditor: _useRichEditor,
                  isPreview: _isPreview,
                  isFoldView: _isFoldView,
                  isTypewriterScroll: _isTypewriterScroll,
                  isFocusMode: _isFocusMode,
                  isZenMode: _isZenMode,
                  hasReminder: _currentReminder != null,
                  onToggleLock: _toggleLock,
                  onShowReminderPicker: () => _showReminderPicker(context),
                  onToggleRichEditor: () {
                    setState(() => _useRichEditor = !_useRichEditor);
                  },
                  onTogglePreview: () {
                    final newValue = !_isPreview;
                    setState(() => _isPreview = newValue);
                    _savePreviewPreference(newValue);
                  },
                  onToggleFoldView: () {
                    setState(() => _isFoldView = !_isFoldView);
                  },
                  onReadAloud: () {
                    final speechState =
                        ref.read(speechStateProvider).valueOrNull ??
                            SpeechState.stopped;
                    final service = ref.read(speechServiceProvider);
                    if (speechState != SpeechState.stopped) {
                      service.stop();
                    } else {
                      final content = _extractPlainText();
                      if (content.isNotEmpty) service.speak(content);
                    }
                  },
                  onShowTagPicker: () => _showTagPicker(context),
                  onShowBacklinks: () => _showBacklinks(context),
                  onShowRelatedNotes: () => _showRelatedNotes(context),
                  onShowProperties: () => _showProperties(context),
                  onShare: () {
                    if (_noteId != null) {
                      showShareBottomSheet(context, _noteId!);
                    }
                  },
                  onPrint: () => _showPrintPreview(context),
                  onPickImage: () => _pickImage(context),
                  onPasteImage: () => _pasteImageFromClipboard(context),
                  onAiAction: (value) => _handleAiAction(context, value),
                  onToggleTypewriterScroll: () {
                    setState(() => _isTypewriterScroll = !_isTypewriterScroll);
                  },
                  onToggleFocusMode: () {
                    setState(() => _isFocusMode = !_isFocusMode);
                  },
                  onToggleZenMode: _toggleZenMode,
                  onSaveAndClose: () async {
                    await _saveNote();
                    if (context.mounted) context.pop();
                  },
                ),
              ),
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
        // Offline banner: shown when device has no connectivity.
        if (!_isZenMode) const OfflineBanner(),
        // Formatting toolbar: shown below AppBar when in rich text mode
        // (not in preview, zen mode, or plain text mode).
        if (!_isZenMode && _useRichEditor && !_isPreview)
          FormattingToolbar(
            quillController: _quillController,
            onPickImage: () => _pickImage(context),
            onAiAction: () => _handleAiAction(context, 'summary'),
          ),
        // Find & replace bar: shown when activated via Ctrl+F / Cmd+F.
        FindReplaceBar(
          isVisible: _showFindReplace,
          searchTextController: _findController,
          replaceTextController: _replaceController,
          matchIndex: _findReplaceCtrl.currentMatchIndex,
          matchCount: _findReplaceCtrl.matchCount,
          onSearchChanged: _onFindSearchChanged,
          onPrevious: _onFindPrevious,
          onNext: _onFindNext,
          onReplace: _onFindReplace,
          onReplaceAll: _onFindReplaceAll,
          onClose: _closeFindReplace,
        ),
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
        // Lock banner: shown when the note is locked (read-only).
        if (_isLocked)
          MaterialBanner(
            content: GestureDetector(
              onTap: _toggleLock,
              child: Row(
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 18,
                    color: colorScheme.onSurface,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.lockedNoteBanner,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: _toggleLock,
                child: Text(l10n.unlockNote),
              ),
            ],
            backgroundColor: colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                // Zen mode: show a minimal back button + toggles.
                if (_isZenMode)
                  ZenModeChrome(
                    animation: _zenChromeAnimController!,
                    onExit: _exitZenMode,
                    onToggle: _toggleZenMode,
                    isFocusMode: _isFocusMode,
                    isTypewriterScroll: _isTypewriterScroll,
                    onToggleFocusMode: () {
                      setState(() => _isFocusMode = !_isFocusMode);
                    },
                    onToggleTypewriterScroll: () {
                      setState(
                        () => _isTypewriterScroll = !_isTypewriterScroll,
                      );
                    },
                  ),

                // Title field.
                Semantics(
                  label: l10n.noteTitle,
                  child: TextField(
                    controller: _titleController,
                    readOnly: _isLocked,
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
                  child: EditorDropTarget(
                    noteId: _noteId!,
                    onImageDropped: _handleDroppedImage,
                    child: FocusHighlight(
                      isActive: _isFocusMode,
                      child: _isFoldView
                          ? _buildFoldView(l10n)
                          : _buildEditorWithCollabCursors(
                              context,
                              l10n,
                              AnimatedSwitcher(
                                duration: AppDurations.shortAnimation,
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                child: _isPreview
                                    ? SingleChildScrollView(
                                        key: const ValueKey('preview'),
                                        padding:
                                            const EdgeInsets.only(bottom: 16),
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
                                              onToggleBulletList:
                                                  _toggleBulletList,
                                              onSlashCommand:
                                                  _handleSlashCommand,
                                              readOnly: _isLocked,
                                            ),
                                          )
                                        : Semantics(
                                            key: const ValueKey('plain_editor'),
                                            label: l10n.noteContent,
                                            child: TextField(
                                              controller:
                                                  _effectiveContentController,
                                              scrollController:
                                                  _bodyScrollController,
                                              readOnly: _isLocked,
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

        // Writing stats bar (detailed stats: word/char/reading time/lines/paragraphs).
        WritingStatsBar(
          stats: _writingStats,
          isVisible: _isWritingStatsVisible,
          onToggleVisibility: () {
            setState(() => _isWritingStatsVisible = !_isWritingStatsVisible);
          },
        ),

        // Save status indicator.
        _SaveStatusChip(
          isSaving: _isSaving,
          isDirty: _isDirty,
        ),

        // Compact word / character count bar with zen mode toggle.
        CharacterCountBar(
          wordCount: _wordCount,
          charCount: _charCount,
          isZenMode: _isZenMode,
          onToggleZenMode: _toggleZenMode,
        ),
        // TTS player bar (only visible when speaking).
        const TtsPlayerBar(),
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

  // ── Fold / outline view ──────────────────────────────

  /// Builds the fold outline view with a toolbar bar above it.
  Widget _buildFoldView(AppLocalizations l10n) {
    return Column(
      children: [
        SectionFoldBar(
          foldController: _foldController,
        ),
        Expanded(
          child: FoldedOutlineView(
            content: _extractPlainText(),
            foldController: _foldController,
            onNavigateToHeading: (offset) {
              // Switch back to the editor and position the cursor.
              setState(() => _isFoldView = false);
              // Set cursor to the heading offset after switching back.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_useRichEditor) {
                  final textLength =
                      _quillController.document.toPlainText().length;
                  final pos = offset.clamp(0, textLength);
                  _quillController.updateSelection(
                    TextSelection.collapsed(offset: pos),
                    quill.ChangeSource.local,
                  );
                  _editorFocusNode.requestFocus();
                } else {
                  final controller = _effectiveContentController;
                  final pos = offset.clamp(0, controller.text.length);
                  controller.selection = TextSelection.collapsed(offset: pos);
                }
              });
            },
          ),
        ),
      ],
    );
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

  /// Show related notes (outbound links) bottom sheet for the current note.
  void _showRelatedNotes(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => RelatedNotesSheet(noteId: _noteId!),
    );
  }

  /// Show properties bottom sheet for the current note.
  void _showProperties(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => PropertiesSheet(noteId: _noteId!),
    );
  }

  /// Show the print preview bottom sheet with the current note content.
  void _showPrintPreview(BuildContext context) async {
    if (_noteId == null) return;

    final db = ref.read(databaseProvider);
    final crypto = ref.read(cryptoServiceProvider);
    final l10n = AppLocalizations.of(context)!;

    final note = await db.notesDao.getNoteById(_noteId!);
    if (!mounted || note == null) return;

    String title = note.plainTitle ?? l10n.untitled;
    String content = note.plainContent ?? '';

    // Decrypt content if available.
    if (crypto.isUnlocked) {
      final decryptedContent = await crypto.decryptForItem(
        _noteId!,
        note.encryptedContent,
      );
      if (decryptedContent != null) content = decryptedContent;
      if (note.encryptedTitle != null) {
        final decryptedTitle = await crypto.decryptForItem(
          _noteId!,
          note.encryptedTitle!,
        );
        if (decryptedTitle != null) title = decryptedTitle;
      }
    }

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => PrintPreviewSheet(
        note: note,
        title: title,
        content: content,
      ),
    );
  }

  // ── Find & Replace ────────────────────────────────────

  /// Opens the find/replace bar and populates the search field with the
  /// currently selected text (if any). Wired to Ctrl+F / Cmd+F.
  void _openFindReplace() {
    // Pre-fill with selected text if available.
    final selected = _getSelectedText();
    if (selected.isNotEmpty) {
      _findController.text = selected;
      _findReplaceCtrl.setSearchQuery(selected);
    }
    setState(() => _showFindReplace = true);
  }

  /// Closes the find/replace bar and clears search state.
  void _closeFindReplace() {
    setState(() {
      _showFindReplace = false;
      _findController.clear();
      _replaceController.clear();
      _findReplaceCtrl.setSearchQuery('');
    });
  }

  /// Called when the search text changes. Updates matches and highlights
  /// the first result.
  void _onFindSearchChanged(String query) {
    _findReplaceCtrl.updateContent(_extractPlainText());
    _findReplaceCtrl.setSearchQuery(query);
    setState(() {});
    _navigateToCurrentMatch();
  }

  /// Navigate to the previous match in the find results.
  void _onFindPrevious() {
    _findReplaceCtrl.previousMatch();
    setState(() {});
    _navigateToCurrentMatch();
  }

  /// Navigate to the next match in the find results.
  void _onFindNext() {
    _findReplaceCtrl.nextMatch();
    setState(() {});
    _navigateToCurrentMatch();
  }

  /// Replace the current match with the replacement text.
  void _onFindReplace() {
    final newContent = _findReplaceCtrl.replaceCurrent(
      _replaceController.text,
    );
    if (newContent != null) {
      _applyFindReplaceResult(newContent);
    }
  }

  /// Replace all matches with the replacement text.
  void _onFindReplaceAll() {
    final newContent = _findReplaceCtrl.replaceAll(
      _replaceController.text,
    );
    if (newContent != null) {
      _applyFindReplaceResult(newContent);
    }
  }

  /// Applies the result of a find/replace operation to the active editor.
  void _applyFindReplaceResult(String newContent) {
    if (_useRichEditor) {
      // For the rich editor, replace the entire document content.
      _quillController.clear();
      _quillController.document.insert(0, newContent);
    } else {
      _effectiveContentController.text = newContent;
    }
    setState(() {});
    _saveNote();
  }

  /// Positions the cursor at the current match location.
  void _navigateToCurrentMatch() {
    final match = _findReplaceCtrl.currentMatch();
    if (match == null) return;

    if (_useRichEditor) {
      _quillController.updateSelection(
        TextSelection(
          baseOffset: match.start,
          extentOffset: match.end,
        ),
        quill.ChangeSource.local,
      );
    } else {
      _effectiveContentController.selection = TextSelection(
        baseOffset: match.start,
        extentOffset: match.end,
      );
    }
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

  // ── Slash command handler ────────────────────────────

  /// Handles slash command selections that require parent-level actions,
  /// such as triggering the image picker.
  void _handleSlashCommand(SlashCommandType type) {
    switch (type) {
      case SlashCommandType.image:
        _pickImage(context);
      default:
        break;
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
    } catch (e) {
      debugPrint('[NoteEditor] Tag application failure: $e');
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

  /// Show a bottom sheet to select image source (gallery or camera).
  Future<void> _pickImage(BuildContext context) async {
    // Image picking via file system is not available on web platform.
    if (kIsWeb) {
      if (!context.mounted) return;
      final l10n = AppLocalizations.of(context)!;
      AppSnackBar.error(context,
          message: l10n.failedToAddImage('Not available on web'),);
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                l10n.selectImageSource,
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
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
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null) return;
    if (!context.mounted) return;
    await _pickImageFromSource(context, source);
  }

  /// Pick an image from the given [source] and insert a markdown reference.
  Future<void> _pickImageFromSource(
    BuildContext context,
    ImageSource source,
  ) async {
    try {
      final picker = ImagePicker();
      final xFile = await picker.pickImage(source: source);
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
      AppSnackBar.error(context, message: l10n.failedToAddImage(e.toString()));
    }
  }

  /// Attempt to paste an image from the clipboard and insert it into the note.
  ///
  /// On desktop platforms, this uses the Clipboard API to check for image data.
  /// On mobile/web platforms, clipboard image access is not easily supported,
  /// so this shows a message to the user.
  Future<void> _pasteImageFromClipboard(BuildContext context) async {
    if (kIsWeb) {
      if (!context.mounted) return;
      final l10n = AppLocalizations.of(context)!;
      AppSnackBar.error(context,
          message: l10n.failedToAddImage('Not available on web'),);
      return;
    }

    try {
      // Try to read clipboard image data via platform-specific approach.
      // The Clipboard API in Flutter does not natively support image data,
      // so we use a best-effort approach with the image_picker fallback.
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData?.text != null &&
          clipboardData!.text!.startsWith('file://')) {
        // If the clipboard contains a file URI, try to use it as an image.
        final filePath = clipboardData.text!.replaceFirst('file://', '');
        final file = File(filePath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final localPath = await ImageStorage.saveImage(bytes, _noteId!);
          final controller = _effectiveContentController;
          final imageRef = '\n![image](file://$localPath)\n';
          controller.text = controller.text + imageRef;
          _saveNote();
          return;
        }
      }

      // Could not read an image from clipboard.
      if (!context.mounted) return;
      final l10n = AppLocalizations.of(context)!;
      AppSnackBar.error(context,
          message: l10n.failedToAddImage('No image found in clipboard'),);
    } catch (e) {
      if (!context.mounted) return;
      final l10n = AppLocalizations.of(context)!;
      AppSnackBar.error(context, message: l10n.failedToAddImage(e.toString()));
    }
  }

  /// Handle an image that was drag-and-dropped onto the editor.
  /// Inserts a markdown image reference and triggers auto-save.
  void _handleDroppedImage(String localPath) {
    final controller = _effectiveContentController;
    final imageRef = '\n![image](file://$localPath)\n';
    controller.text = controller.text + imageRef;
    _saveNote();
  }
}

/// A compact save status chip shown at the bottom of the editor.
///
/// Displays one of three states:
/// - Green checkmark + "Saved" when content is saved.
/// - Amber dot + "Unsaved" when there are unsaved changes.
/// - Spinning indicator + "Saving..." when actively saving.
class _SaveStatusChip extends StatelessWidget {
  final bool isSaving;
  final bool isDirty;

  const _SaveStatusChip({
    required this.isSaving,
    required this.isDirty,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    final String label;
    final Color color;
    final Widget icon;

    if (isSaving) {
      label = l10n.statusSaving;
      color = colorScheme.tertiary;
      icon = SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          color: color,
        ),
      );
    } else if (isDirty) {
      label = l10n.statusUnsaved;
      color = colorScheme.error;
      icon = Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      );
    } else {
      label = l10n.statusSaved;
      color = Colors.green;
      icon = Icon(Icons.check_circle, size: 14, color: color);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          icon,
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
