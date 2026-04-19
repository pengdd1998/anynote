import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
import '../../../core/accessibility/a11y_utils.dart';
import '../../../core/collab/presence_indicator.dart';
import '../../../core/collab/ws_client.dart';
import '../../../core/crypto/crypto_service.dart';
import '../../../core/database/app_database.dart';
import '../../../core/error/error.dart';
import '../../../core/monitoring/performance_monitor.dart';
import '../../../core/storage/image_storage.dart';
import '../../../core/widgets/markdown_preview.dart';
import 'rich_note_editor.dart';

class NoteEditorScreen extends ConsumerStatefulWidget {
  /// Optional initial content to pre-fill the editor (e.g. from a template).
  final String? initialContent;

  const NoteEditorScreen({super.key, this.initialContent});

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
    _noteId = const Uuid().v4();
    _contentController.addListener(_onContentChanged);
    _quillController.addListener(_onContentChanged);

    // Zen mode chrome fade animation (300ms).
    _zenChromeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1.0, // chrome visible by default
    );

    // Pre-fill with initial content if provided (e.g. from a template).
    if (widget.initialContent != null &&
        widget.initialContent!.isNotEmpty) {
      _contentController.text = widget.initialContent!;
      // Also set quill controller content so it is available in rich mode.
      _quillController.document.insert(0, widget.initialContent!);
    }

    // Load saved preview mode preference.
    _loadPreviewPreference();

    // Initial count.
    _updateCounts();

    // Join presence room for real-time collaboration indicators.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _joinPresenceRoom();
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
    _countDebounceTimer = Timer(const Duration(milliseconds: 300), _updateCounts);
    // Debounce presence typing indicator (send at most once per second).
    _presenceDebounce?.cancel();
    _presenceDebounce = Timer(const Duration(seconds: 1), _notifyPresenceTyping);
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
    final words = text.trim().isEmpty
        ? 0
        : text.trim().split(_wordSplitRegex).length;

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
      final text = _contentController.text;
      final cursorPos = _contentController.selection.baseOffset;
      if (cursorPos < 0) return;

      const lineHeight = 16.0 * 1.6; // fontSize * height
      final linesBeforeCursor =
          '\n'.allMatches(text.substring(0, cursorPos)).length;
      final cursorY =
          linesBeforeCursor * lineHeight + 16.0; // + padding

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

    PerformanceMonitor.start('note_save');
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
      PerformanceMonitor.end('note_save');
    } catch (e) {
      // Store the error but do not lose the user's input.
      // The debounced save will retry automatically.
      PerformanceMonitor.end('note_save');
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
    // Leave presence room.
    ref.read(presenceProvider.notifier).leaveRoom();
    // Restore system UI when leaving the editor.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  /// Returns the content to encrypt and store:
  /// - Rich editor: Delta JSON string
  /// - Plain text: raw text from the text controller
  String _getContentForSave() {
    if (_useRichEditor) {
      return jsonEncode(_quillController.document.toDelta().toJson());
    }
    return _contentController.text;
  }

  /// Returns plain text for FTS5 search indexing.
  String _extractPlainText() {
    if (_useRichEditor) {
      return _quillController.document.toPlainText();
    }
    return _contentController.text;
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
                  icon:
                      Icon(_isPreview ? Icons.edit : Icons.visibility),
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
                IconButton(
                  icon: const Icon(Icons.image_outlined),
                  tooltip: l10n.addImage,
                  onPressed: () => _pickImage(context),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              top: _isZenMode
                  ? MediaQuery.of(context).padding.top + 8
                  : 0,
              bottom: 0,
            ),
            child: Column(
              children: [
                // Zen mode: show a minimal back button + focus icon.
                if (_isZenMode) _buildZenChrome(context, l10n, colorScheme),

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
                  child: AnimatedSwitcher(
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
                              child: _buildRichEditorWithShortcuts(),
                            )
                          : Semantics(
                              key: const ValueKey('plain_editor'),
                              label: l10n.noteContent,
                              child: TextField(
                                controller: _contentController,
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
                                onChanged: (_) => _scheduleTypewriterScroll(),
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
            typingUsers: ref.watch(presenceProvider).values
                .where((u) => u.isTyping)
                .toList(),
          ),

        // Animated word / character count bar.
        _buildCountBar(context, l10n, colorScheme),
      ],
    );
  }

  // ── Zen mode chrome ───────────────────────────────────

  /// Minimal chrome shown at the top of the screen in zen mode:
  /// a back arrow (to exit) and a focus icon toggle.
  Widget _buildZenChrome(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    return FadeTransition(
      opacity: _zenChromeAnimController!,
      child: Row(
        children: [
          // Back button to exit zen mode.
          IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: colorScheme.onSurface.withValues(alpha: 0.5),
              size: 20,
            ),
            tooltip: l10n.exitZenMode,
            onPressed: _exitZenMode,
          ),
          const Spacer(),
          // Toggle button to exit zen mode.
          IconButton(
            icon: Icon(
              Icons.fullscreen_exit,
              color: colorScheme.onSurface.withValues(alpha: 0.5),
              size: 20,
            ),
            tooltip: l10n.exitZenMode,
            onPressed: _toggleZenMode,
          ),
        ],
      ),
    );
  }

  // ── Animated count bar ────────────────────────────────

  /// Shows word count and character count at the bottom of the editor.
  /// Animates with a subtle scale+opacity transition when counts change.
  Widget _buildCountBar(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    // Use warm secondary color for the caption text.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final captionColor = isDark
        ? const Color(0xFFA3988E) // warm medium grey (WCAG AA on dark surface)
        : const Color(0xFF6B5E54); // warm brown-grey

    return SafeArea(
      top: false,
      bottom: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Zen mode toggle button (visible when not in zen mode).
            if (!_isZenMode)
              A11yUtils.ensureTouchTarget(
                child: Semantics(
                  button: true,
                  label: l10n.enterZenMode,
                  child: IconButton(
                    icon: Icon(
                      Icons.fullscreen,
                      size: 18,
                      color: captionColor,
                    ),
                    tooltip: l10n.enterZenMode,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 24,
                    ),
                    onPressed: _toggleZenMode,
                  ),
                ),
              ),
            const Spacer(),
            // Animated word count.
            _AnimatedCountChip(
              text: l10n.wordCount(_wordCount),
              color: captionColor,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                '|',
                style: TextStyle(
                  color: captionColor.withValues(alpha: 0.4),
                  fontSize: 12,
                ),
              ),
            ),
            // Animated character count.
            _AnimatedCountChip(
              text: l10n.charCount(_charCount),
              color: captionColor,
            ),
          ],
        ),
      ),
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

  /// Build the rich text editor wrapped with additional keyboard shortcuts.
  ///
  /// flutter_quill handles Ctrl+B/I natively. This widget adds:
  /// - Ctrl+1: Heading level 1
  /// - Ctrl+2: Heading level 2
  /// - Ctrl+3: Heading level 3
  /// - Ctrl+Shift+L: Toggle bullet list
  /// - Escape: Exit zen mode
  Widget _buildRichEditorWithShortcuts() {
    final isMacOS = Theme.of(context).platform == TargetPlatform.macOS;
    final primaryModifier =
        isMacOS ? LogicalKeyboardKey.meta : LogicalKeyboardKey.control;

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        // Heading shortcuts
        LogicalKeySet(primaryModifier, LogicalKeyboardKey.digit1):
            const _Heading1Intent(),
        LogicalKeySet(primaryModifier, LogicalKeyboardKey.digit2):
            const _Heading2Intent(),
        LogicalKeySet(primaryModifier, LogicalKeyboardKey.digit3):
            const _Heading3Intent(),
        // Bullet list shortcut
        LogicalKeySet(
          primaryModifier,
          LogicalKeyboardKey.shift,
          LogicalKeyboardKey.keyL,
        ): const _BulletListIntent(),
        // Escape to exit zen mode
        LogicalKeySet(LogicalKeyboardKey.escape):
            const _ExitZenIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _Heading1Intent: CallbackAction<_Heading1Intent>(
            onInvoke: (_) => _toggleHeading(1),
          ),
          _Heading2Intent: CallbackAction<_Heading2Intent>(
            onInvoke: (_) => _toggleHeading(2),
          ),
          _Heading3Intent: CallbackAction<_Heading3Intent>(
            onInvoke: (_) => _toggleHeading(3),
          ),
          _BulletListIntent: CallbackAction<_BulletListIntent>(
            onInvoke: (_) => _toggleBulletList(),
          ),
          _ExitZenIntent: CallbackAction<_ExitZenIntent>(
            onInvoke: (_) => _exitZenMode(),
          ),
        },
        child: RichNoteEditor(
          controller: _quillController,
          focusNode: _editorFocusNode,
        ),
      ),
    );
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
      builder: (_) => _TagPickerSheet(
        noteId: _noteId!,
        db: ref.read(databaseProvider),
        crypto: ref.read(cryptoServiceProvider),
      ),
    );
  }

  /// Pick an image from the gallery and insert a markdown reference.
  Future<void> _pickImage(BuildContext context) async {
    try {
      final picker = ImagePicker();
      final xFile = await picker.pickImage(source: ImageSource.gallery);
      if (xFile == null) return;

      final bytes = await File(xFile.path).readAsBytes();
      final localPath = await ImageStorage.saveImage(bytes, _noteId!);

      // Insert markdown image reference at the end of content.
      final currentText = _contentController.text;
      final imageRef = '\n![image](file://$localPath)\n';
      _contentController.text = currentText + imageRef;

      // Trigger auto-save.
      _saveNote();
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.failedToAddImage(e.toString()))),
        );
      }
    }
  }
}

// ── Animated Count Chip ─────────────────────────────────

/// Displays a word or character count string with a subtle scale+opacity
/// animation when the text changes. This gives a gentle pulse effect that
/// draws the eye without being distracting.
class _AnimatedCountChip extends StatelessWidget {
  final String text;
  final Color color;

  const _AnimatedCountChip({
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    // Use AnimatedSwitcher to cross-fade between old and new count text.
    // The transition applies a slight scale-up on the incoming text.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (Widget child, Animation<double> animation) {
        // Subtle scale from 0.85 to 1.0 combined with opacity fade.
        final scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: scaleAnimation,
            child: child,
          ),
        );
      },
      child: Text(
        text,
        key: ValueKey(text), // key change triggers animation
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// Bottom sheet for picking and creating tags for a note.
class _TagPickerSheet extends ConsumerStatefulWidget {
  final String noteId;
  final AppDatabase db;
  final CryptoService crypto;

  const _TagPickerSheet({
    required this.noteId,
    required this.db,
    required this.crypto,
  });

  @override
  ConsumerState<_TagPickerSheet> createState() => _TagPickerSheetState();
}

class _TagPickerSheetState extends ConsumerState<_TagPickerSheet> {
  final _newTagController = TextEditingController();
  List<Tag> _allTags = [];
  Set<String> _assignedTagIds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  @override
  void dispose() {
    _newTagController.dispose();
    super.dispose();
  }

  Future<void> _loadTags() async {
    final allTags = await widget.db.tagsDao.getAllTags();
    final noteTags = await widget.db.tagsDao.getTagsForNote(widget.noteId);
    if (!mounted) return;
    setState(() {
      _allTags = allTags;
      _assignedTagIds = noteTags.map((t) => t.id).toSet();
      _isLoading = false;
    });
  }

  Future<void> _createAndAssignTag() async {
    final tagName = _newTagController.text.trim();
    if (tagName.isEmpty) return;

    final tagId = const Uuid().v4();
    String encryptedName;
    if (widget.crypto.isUnlocked) {
      encryptedName = await widget.crypto.encryptForItem(tagId, tagName);
    } else {
      encryptedName = tagName;
    }

    await widget.db.tagsDao.createTag(
      id: tagId,
      encryptedName: encryptedName,
      plainName: tagName,
    );
    await widget.db.notesDao.addTagToNote(widget.noteId, tagId);

    _newTagController.clear();
    await _loadTags();
  }

  Future<void> _toggleTag(Tag tag, bool isAssigned) async {
    if (isAssigned) {
      await widget.db.notesDao.removeTagFromNote(widget.noteId, tag.id);
    } else {
      await widget.db.notesDao.addTagToNote(widget.noteId, tag.id);
    }
    await _loadTags();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
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
                Text(l10n.tags, style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: l10n.closeTagPicker,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Inline tag creation
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    label: l10n.newTagName,
                    child: TextField(
                      controller: _newTagController,
                      decoration: InputDecoration(
                        hintText: l10n.newTagName,
                        border: const OutlineInputBorder(),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: (_) => _createAndAssignTag(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  button: true,
                  label: 'Create and assign tag',
                  child: FilledButton(
                    onPressed: _createAndAssignTag,
                    child: Text(l10n.add),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Tag list with checkboxes
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            )
          else if (_allTags.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                l10n.noTagsYet,
                style: TextStyle(color: Colors.grey.shade500),
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _allTags.length,
                itemBuilder: (context, index) {
                  final tag = _allTags[index];
                  final isAssigned = _assignedTagIds.contains(tag.id);
                  final displayName =
                      tag.plainName ?? tag.id.substring(0, 8);

                  return CheckboxListTile(
                    value: isAssigned,
                    title: Text(displayName),
                    onChanged: (checked) => _toggleTag(tag, isAssigned),
                  );
                },
              ),
            ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Keyboard Shortcut Intents ───────────────────────────

class _Heading1Intent extends Intent {
  const _Heading1Intent();
}

class _Heading2Intent extends Intent {
  const _Heading2Intent();
}

class _Heading3Intent extends Intent {
  const _Heading3Intent();
}

class _BulletListIntent extends Intent {
  const _BulletListIntent();
}

/// Intent to exit zen / focus mode via keyboard.
class _ExitZenIntent extends Intent {
  const _ExitZenIntent();
}
