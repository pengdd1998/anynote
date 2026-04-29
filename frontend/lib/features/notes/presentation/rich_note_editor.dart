import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../main.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/daos/snippets_dao.dart';
import 'embeds/table_embed.dart';
import 'embeds/table_picker_dialog.dart';
import 'embeds/transclusion_embed.dart';
import 'embeds/wiki_link_embed.dart';
import 'widgets/slash_command_menu.dart';

/// A rich text editor widget using flutter_quill.
///
/// Wraps a [quill.QuillSimpleToolbar] above a [quill.QuillEditor] with a
/// divider between them. The toolbar is configured for note-taking with
/// heading styles, lists, quotes, code blocks, inline formatting, undo/redo,
/// and link support. Font family, font size, color, alignment, subscript, and
/// superscript buttons are hidden to keep the toolbar compact.
///
/// Toolbar buttons use the warm theme colors from the enclosing [ThemeData].
/// Active/toggled buttons display with the primary accent, inactive buttons
/// use the theme's secondary text color. Subtle dividers separate button
/// groups for a polished, non-cluttered look.
///
/// When the user types `/` at the beginning of a line or after a space, a
/// slash command popup appears near the cursor. The user can filter commands
/// by typing and select one with arrow keys + Enter, tap, or Escape to close.
class RichNoteEditor extends ConsumerStatefulWidget {
  final quill.QuillController controller;
  final FocusNode focusNode;

  /// Optional scroll controller for the editor area.
  /// When provided, the editor uses this controller instead of creating one
  /// internally. This enables typewriter-scrolling behavior driven by the
  /// parent widget.
  final ScrollController? scrollController;

  /// Called when a slash command selection requires the parent to perform
  /// additional work, such as opening the image picker or wiki link picker.
  final void Function(SlashCommandType type)? onSlashCommand;

  /// When true, the editor is read-only and the toolbar is hidden.
  final bool readOnly;

  const RichNoteEditor({
    super.key,
    required this.controller,
    required this.focusNode,
    this.scrollController,
    this.onSlashCommand,
    this.readOnly = false,
  });

  @override
  ConsumerState<RichNoteEditor> createState() => _RichNoteEditorState();
}

class _RichNoteEditorState extends ConsumerState<RichNoteEditor> {
  /// Overlay entry for the slash command popup menu.
  OverlayEntry? _slashOverlayEntry;

  /// Text offset where the `/` trigger character was typed.
  int? _slashOffset;

  /// Layer link used to anchor the slash command overlay to the cursor.
  final LayerLink _layerLink = LayerLink();

  /// GlobalKey for the editor's render object, used to position the overlay.
  final GlobalKey _editorKey = GlobalKey();

  /// Fallback scroll controller created when no external controller is
  /// provided. Lazily initialized and disposed in [dispose].
  ScrollController? _fallbackScrollController;

  /// Returns the externally provided scroll controller, or lazily creates a
  /// fallback one that is properly disposed when the State is removed.
  ScrollController get _effectiveScrollController =>
      widget.scrollController ??
      (_fallbackScrollController ??= ScrollController());

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _removeSlashOverlay();
    _fallbackScrollController?.dispose();
    super.dispose();
  }

  void _insertTable(BuildContext context) async {
    final tableSize = await showTablePickerDialog(context);
    if (tableSize == null) return;

    insertTableEmbed(
      controller: widget.controller,
      rows: tableSize.rows,
      cols: tableSize.cols,
    );
  }

  // -- Slash command detection and overlay management --

  /// Listens to text changes and detects the `/` trigger for slash commands.
  void _onTextChanged() {
    _checkSlashTrigger();
  }

  /// Checks if the user just typed `/` at a valid position (start of line or
  /// after a space). If so, shows the slash command overlay.
  void _checkSlashTrigger() {
    final controller = widget.controller;
    final sel = controller.selection;

    // Only trigger on a collapsed cursor.
    if (!sel.isCollapsed) {
      _removeSlashOverlay();
      return;
    }

    final cursorPos = sel.baseOffset;
    final plainText = controller.document.toPlainText();

    // If the overlay is already showing, update the filter text or close it
    // if the cursor has moved away from the slash position.
    if (_slashOffset != null) {
      if (cursorPos < _slashOffset!) {
        // Cursor moved before the slash -- close the menu.
        _removeSlashOverlay();
        return;
      }

      // Check that the text between slash position and cursor still starts
      // with `/` and only contains filter characters.
      final slashText = plainText.substring(_slashOffset!, cursorPos);
      if (slashText.isEmpty || slashText[0] != '/') {
        _removeSlashOverlay();
        return;
      }

      // If there is a newline in the filter text, close the menu.
      if (slashText.contains('\n')) {
        _removeSlashOverlay();
        return;
      }

      // Update the filter text in the existing overlay.
      _updateSlashFilter(slashText.substring(1)); // strip leading `/`
      return;
    }

    // No overlay showing -- check if the user just typed `/` at a valid spot.
    if (cursorPos < 1) return;

    final charBefore = plainText[cursorPos - 1];
    if (charBefore != '/') return;

    // Valid position: beginning of document, or beginning of line, or after
    // a space.
    final isValidPosition = cursorPos == 1 ||
        plainText[cursorPos - 2] == '\n' ||
        plainText[cursorPos - 2] == ' ';

    if (isValidPosition) {
      _slashOffset = cursorPos - 1;
      _showSlashOverlay();
    }
  }

  /// Shows the slash command overlay near the cursor position.
  void _showSlashOverlay() {
    _removeSlashOverlay();

    final overlayState = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    // Calculate cursor offset relative to the overlay.
    // Use the editor's render box to get a rough cursor position.
    final Size editorSize = renderBox.size;

    // Estimate cursor vertical position from the quill document.
    // We approximate by counting lines up to the cursor.
    final plainText = widget.controller.document.toPlainText();
    final cursorPos = widget.controller.selection.baseOffset;
    final linesBeforeCursor =
        '\n'.allMatches(plainText.substring(0, cursorPos)).length;
    const lineHeight = 30.0; // approximate line height (20.0 * 1.5)
    const toolbarHeight = 48.0;
    final estimatedCursorY =
        linesBeforeCursor * lineHeight + 16.0 + toolbarHeight;

    // Horizontal: center-ish, but could be improved with actual cursor metrics.
    final offset = Offset(
      16.0, // left padding alignment
      estimatedCursorY.clamp(0.0, editorSize.height - 50).toDouble(),
    );

    _slashOverlayEntry = OverlayEntry(
      builder: (context) {
        return _buildSlashOverlayContent(offset);
      },
    );

    overlayState.insert(_slashOverlayEntry!);
  }

  Widget _buildSlashOverlayContent(Offset offset) {
    final controller = widget.controller;
    final cursorPos = controller.selection.baseOffset;
    final filterText = _slashOffset != null && cursorPos > _slashOffset!
        ? controller.document
            .toPlainText()
            .substring(_slashOffset! + 1, cursorPos)
        : '';

    return Stack(
      children: [
        // Tap outside to dismiss.
        Positioned.fill(
          child: GestureDetector(
            onTap: _removeSlashOverlay,
            behavior: HitTestBehavior.translucent,
            child: const SizedBox.expand(),
          ),
        ),
        // The menu positioned near the cursor.
        Positioned(
          left: offset.dx,
          top: offset.dy,
          child: SlashCommandMenu(
            controller: controller,
            slashOffset: _slashOffset!,
            filterText: filterText,
            onDismiss: _removeSlashOverlay,
            onCommandSelected: _handleSlashCommandSelected,
          ),
        ),
      ],
    );
  }

  /// Updates the filter text on the existing overlay by rebuilding it.
  void _updateSlashFilter(String filter) {
    if (_slashOverlayEntry == null) return;
    _slashOverlayEntry!.markNeedsBuild();
  }

  /// Removes the slash command overlay and resets state.
  void _removeSlashOverlay() {
    _slashOverlayEntry?.remove();
    _slashOverlayEntry = null;
    _slashOffset = null;
  }

  /// Called when a slash command is selected. Performs additional actions
  /// that need parent context (image picker, wiki link, etc.).
  void _handleSlashCommandSelected(SlashCommandType type) {
    _removeSlashOverlay();

    switch (type) {
      case SlashCommandType.image:
        // Delegate to parent for image picker flow.
        widget.onSlashCommand?.call(type);
      case SlashCommandType.wikilink:
        // The `[[` was already inserted; the wiki link detection in
        // note_editor_screen.dart will pick it up automatically.
        break;
      case SlashCommandType.transclusion:
        // The `![[` was already inserted; the transclusion detection in
        // note_editor_screen.dart will pick it up automatically.
        break;
      case SlashCommandType.snippet:
        // Show snippet picker sheet for inserting code.
        _showSnippetPicker();
        break;
      default:
        break;
    }
  }

  /// Show a searchable bottom sheet listing all snippets.
  /// Tapping a snippet inserts its code at the current cursor position.
  void _showSnippetPicker() {
    final l10n = AppLocalizations.of(context)!;
    final db = ref.read(databaseProvider);
    final controller = widget.controller;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _SnippetPickerSheet(
        db: db,
        l10n: l10n,
        onSelect: (snippet) {
          // Insert the snippet code wrapped in a code block.
          final code = '\n```${snippet.language}\n${snippet.code}\n```\n';
          final offset = controller.selection.baseOffset;
          controller.document.insert(offset, code);
          controller.updateSelection(
            TextSelection.collapsed(offset: offset + code.length),
            quill.ChangeSource.local,
          );
          // Increment usage count in the background.
          SnippetsDao(db).incrementUsageCount(snippet.id);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Sync readOnly state to the quill controller.
    widget.controller.readOnly = widget.readOnly;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconTheme = _buildIconTheme(colorScheme, isDark);

    return Column(
      key: _editorKey,
      children: [
        if (!widget.readOnly) _buildToolbar(context, iconTheme, isDark),
        if (!widget.readOnly)
          Divider(
            height: 1,
            thickness: 1,
            color: isDark ? const Color(0xFF332E2B) : const Color(0xFFF0E8DF),
          ),
        Expanded(child: _buildEditorArea(context)),
      ],
    );
  }

  /// Builds the warm-themed icon theme for toolbar buttons.
  quill.QuillIconTheme _buildIconTheme(ColorScheme colorScheme, bool isDark) {
    return quill.QuillIconTheme(
      iconButtonSelectedData: quill.IconButtonData(
        color: colorScheme.primary,
        style: ButtonStyle(
          backgroundColor: WidgetStatePropertyAll(
            colorScheme.primaryContainer.withValues(alpha: 0.3),
          ),
        ),
      ),
      iconButtonUnselectedData: quill.IconButtonData(
        color: isDark
            ? const Color(0xFFA3988E) // warm medium grey (WCAG AA on dark)
            : const Color(0xFF6B5E54), // warm brown-grey (light theme)
      ),
    );
  }

  /// Builds the formatting toolbar with warm styling and shortcut tooltips.
  Widget _buildToolbar(
      BuildContext context, quill.QuillIconTheme iconTheme, bool isDark,) {
    return quill.QuillSimpleToolbar(
      controller: widget.controller,
      config: quill.QuillSimpleToolbarConfig(
        multiRowsDisplay: true,
        showDividers: true,
        showFontFamily: false,
        showFontSize: false,
        showBoldButton: true,
        showItalicButton: true,
        showUnderLineButton: true,
        showStrikeThrough: true,
        showInlineCode: true,
        showColorButton: false,
        showBackgroundColorButton: false,
        showClearFormat: true,
        showAlignmentButtons: false,
        showHeaderStyle: true,
        showListNumbers: true,
        showListBullets: true,
        showListCheck: true,
        showCodeBlock: true,
        showQuote: true,
        showIndent: false,
        showLink: true,
        showSearchButton: false,
        showUndo: true,
        showRedo: true,
        showDirection: false,
        showSubscript: false,
        showSuperscript: false,
        showSmallButton: false,
        color: isDark ? const Color(0xFF252220) : const Color(0xFFFFFDFB),
        sectionDividerColor:
            isDark ? const Color(0xFF332E2B) : const Color(0xFFF0E8DF),
        sectionDividerSpace: 8,
        iconTheme: iconTheme,
        buttonOptions: _buildToolbarButtonOptions(iconTheme),
        customButtons: [
          quill.QuillToolbarCustomButtonOptions(
            icon: const Icon(Icons.table_chart),
            tooltip: 'Insert table',
            onPressed: () => _insertTable(context),
          ),
        ],
      ),
    );
  }

  /// Builds the toolbar button options with warm icon theme and shortcut tooltips.
  quill.QuillSimpleToolbarButtonOptions _buildToolbarButtonOptions(
      quill.QuillIconTheme iconTheme,) {
    return quill.QuillSimpleToolbarButtonOptions(
      base: quill.QuillToolbarBaseButtonOptions(iconTheme: iconTheme),
      bold: quill.QuillToolbarToggleStyleButtonOptions(
        iconTheme: iconTheme,
        tooltip: 'Bold (Ctrl+B)',
      ),
      italic: quill.QuillToolbarToggleStyleButtonOptions(
        iconTheme: iconTheme,
        tooltip: 'Italic (Ctrl+I)',
      ),
      underLine: quill.QuillToolbarToggleStyleButtonOptions(
        iconTheme: iconTheme,
        tooltip: 'Underline (Ctrl+U)',
      ),
      strikeThrough: quill.QuillToolbarToggleStyleButtonOptions(
        iconTheme: iconTheme,
        tooltip: 'Strikethrough (Ctrl+Shift+S)',
      ),
      inlineCode: quill.QuillToolbarToggleStyleButtonOptions(
        iconTheme: iconTheme,
        tooltip: 'Inline Code (Ctrl+`)',
      ),
      linkStyle: quill.QuillToolbarLinkStyleButtonOptions(
        iconTheme: iconTheme,
        tooltip: 'Insert Link (Ctrl+Shift+K)',
      ),
      selectHeaderStyleDropdownButton:
          quill.QuillToolbarSelectHeaderStyleDropdownButtonOptions(
        iconTheme: iconTheme,
        tooltip: 'Heading (Ctrl+H)',
      ),
      undoHistory: quill.QuillToolbarHistoryButtonOptions(
        iconTheme: iconTheme,
        tooltip: 'Undo (Ctrl+Z)',
      ),
      redoHistory: quill.QuillToolbarHistoryButtonOptions(
        iconTheme: iconTheme,
        tooltip: 'Redo (Ctrl+Y)',
      ),
    );
  }

  /// Builds the editor area with semantics and overlay anchoring.
  Widget _buildEditorArea(BuildContext context) {
    return Semantics(
      label: AppLocalizations.of(context)?.noteContentEditor,
      hint: AppLocalizations.of(context)?.noteContentEditor,
      textField: true,
      child: CompositedTransformTarget(
        link: _layerLink,
        child: quill.QuillEditor(
          controller: widget.controller,
          focusNode: widget.focusNode,
          scrollController: _effectiveScrollController,
          config: const quill.QuillEditorConfig(
            padding: EdgeInsets.all(16),
            autoFocus: false,
            expands: false,
            embedBuilders: [
              TableEmbedBuilder(),
              WikiLinkEmbedBuilder(),
              TransclusionEmbedBuilder(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet listing snippets with a search bar.
/// Shown when the user selects the "Snippet" slash command.
class _SnippetPickerSheet extends StatefulWidget {
  final AppDatabase db;
  final AppLocalizations l10n;
  final ValueChanged<Snippet> onSelect;

  const _SnippetPickerSheet({
    required this.db,
    required this.l10n,
    required this.onSelect,
  });

  @override
  State<_SnippetPickerSheet> createState() => _SnippetPickerSheetState();
}

class _SnippetPickerSheetState extends State<_SnippetPickerSheet> {
  List<Snippet> _snippets = [];
  List<Snippet> _filtered = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSnippets();
  }

  Future<void> _loadSnippets() async {
    final dao = SnippetsDao(widget.db);
    final snippets = await (dao.select(dao.snippets)
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
    if (mounted) {
      setState(() {
        _snippets = snippets;
        _filtered = snippets;
        _isLoading = false;
      });
    }
  }

  void _applyFilter(String query) {
    setState(() {
      if (query.isEmpty) {
        _filtered = _snippets;
      } else {
        final lower = query.toLowerCase();
        _filtered = _snippets
            .where(
              (s) =>
                  s.title.toLowerCase().contains(lower) ||
                  s.language.toLowerCase().contains(lower) ||
                  s.code.toLowerCase().contains(lower),
            )
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
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
          Text(
            widget.l10n.insertSnippet,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              hintText: widget.l10n.searchSnippets,
              prefixIcon: const Icon(Icons.search, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
            onChanged: _applyFilter,
            autofocus: true,
          ),
          const SizedBox(height: 8),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            )
          else if (_filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                widget.l10n.noSnippets,
                style: TextStyle(color: theme.disabledColor),
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _filtered.length,
                itemBuilder: (context, index) {
                  final snippet = _filtered[index];
                  return ListTile(
                    dense: true,
                    title: Text(snippet.title),
                    subtitle: snippet.language.isNotEmpty
                        ? Text(
                            snippet.language,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.primary,
                            ),
                          )
                        : null,
                    trailing: Text(
                      widget.l10n.usageCount(snippet.usageCount),
                      style:
                          TextStyle(fontSize: 11, color: theme.disabledColor),
                    ),
                    onTap: () {
                      widget.onSelect(snippet);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
