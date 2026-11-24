import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/platform/platform_utils.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/tts/speech_service.dart';
import '../../../../core/widgets/land_in.dart';
import '../../../../l10n/app_localizations.dart';

/// Configuration object holding all callbacks needed by the editor AppBar
/// actions. Extracted from 31 positional parameters into a single data class
/// for better readability and maintainability.
class EditorActionsConfig {
  final String? noteId;
  final bool isNew;
  final bool isLocked;
  final bool isSaving;
  final bool isDirty;
  final bool useRichEditor;
  final bool isPreview;
  final bool isFoldView;
  final bool isTypewriterScroll;
  final bool isFocusMode;
  final bool isZenMode;
  final bool hasReminder;
  final VoidCallback onToggleLock;
  final VoidCallback onShowReminderPicker;
  final VoidCallback onToggleRichEditor;
  final VoidCallback onTogglePreview;
  final VoidCallback onToggleFoldView;
  final VoidCallback onReadAloud;
  final VoidCallback onShowTagPicker;
  final VoidCallback onShowBacklinks;
  final VoidCallback onShowRelatedNotes;
  final VoidCallback onShowProperties;
  final VoidCallback? onShare;
  final VoidCallback onPrint;
  final VoidCallback onPickImage;
  final VoidCallback onPasteImage;
  final ValueChanged<String> onAiAction;
  final VoidCallback onToggleTypewriterScroll;
  final VoidCallback onToggleFocusMode;
  final VoidCallback onToggleZenMode;
  final VoidCallback onSaveAndClose;
  final VoidCallback? onPublishToPlatform;

  /// Builds (or refreshes) the semantic-search embedding for this note.
  /// Null when the action is unavailable (e.g. preview mode).
  final VoidCallback? onSemanticIndex;

  const EditorActionsConfig({
    required this.noteId,
    required this.isNew,
    required this.isLocked,
    required this.isSaving,
    required this.isDirty,
    required this.useRichEditor,
    required this.isPreview,
    required this.isFoldView,
    required this.isTypewriterScroll,
    required this.isFocusMode,
    required this.isZenMode,
    required this.hasReminder,
    required this.onToggleLock,
    required this.onShowReminderPicker,
    required this.onToggleRichEditor,
    required this.onTogglePreview,
    required this.onToggleFoldView,
    required this.onReadAloud,
    required this.onShowTagPicker,
    required this.onShowBacklinks,
    required this.onShowRelatedNotes,
    required this.onShowProperties,
    this.onShare,
    required this.onPrint,
    required this.onPickImage,
    required this.onPasteImage,
    required this.onAiAction,
    required this.onToggleTypewriterScroll,
    required this.onToggleFocusMode,
    required this.onToggleZenMode,
    required this.onSaveAndClose,
    this.onPublishToPlatform,
    this.onSemanticIndex,
  });
}

/// Builds the list of action widgets for the [NoteEditorScreen] AppBar.
///
/// Redesigned to keep only essential items in the AppBar row:
/// - Presence avatars
/// - Saving spinner
/// - Preview toggle
/// - Rich/plain text toggle
/// - Save-and-close
/// - Overflow menu with all secondary actions
///
/// Usage: `actions: EditorAppBarActions.buildActions(context, ref, config)`
class EditorAppBarActions {
  EditorAppBarActions._();

  /// Returns the list of action widgets for the editor AppBar.
  static List<Widget> buildActions(
    BuildContext context,
    WidgetRef ref,
    EditorActionsConfig config,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    // In preview/read mode: minimal actions matching the design mockup.
    if (config.isPreview) {
      return _buildPreviewActions(context, ref, config, l10n, colorScheme);
    }

    return [
      // Save status indicator in AppBar: spinner when saving, checkmark when
      // saved, amber dot when there are unsaved changes.
      _AppBarSaveStatus(isSaving: config.isSaving, isDirty: config.isDirty),
      // Save-and-close done button with primary color.
      IconButton(
        icon: Icon(AppIcons.check, color: colorScheme.primary),
        tooltip: l10n.saveAndClose,
        onPressed: config.onSaveAndClose,
      ),
      // Rich/plain text mode toggle (icon shows the mode to switch to).
      IconButton(
        icon: Icon(
          config.useRichEditor ? AppIcons.textSnippet : AppIcons.textT,
        ),
        tooltip: config.useRichEditor ? l10n.plainText : l10n.richText,
        onPressed: config.onToggleRichEditor,
      ),
      // Preview toggle.
      IconButton(
        icon: Icon(
          config.isPreview ? AppIcons.edit : AppIcons.visibility,
        ),
        tooltip: config.isPreview ? l10n.edit : l10n.preview,
        onPressed: config.onTogglePreview,
      ),
      // Overflow menu with all secondary actions. Horizontal dots match the
      // note detail screen's overflow trigger.
      PopupMenuButton<String>(
        icon: const Icon(AppIcons.moreHorizontal),
        tooltip: l10n.moreActions,
        onSelected: (value) => _handleOverflowSelection(
          context,
          ref,
          config,
          value,
        ),
        itemBuilder: (context) => [
          // --- Note section ---
          if (!config.isNew && config.noteId != null)
            PopupMenuItem(
              value: 'lock',
              child: ListTile(
                leading: Icon(
                  config.isLocked ? AppIcons.lock : AppIcons.lockOpen,
                ),
                title: Text(config.isLocked ? l10n.unlockNote : l10n.lockNote),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          if (config.noteId != null)
            PopupMenuItem(
              value: 'reminder',
              child: ListTile(
                leading: Badge(
                  isLabelVisible: config.hasReminder,
                  child: const Icon(AppIcons.notification),
                ),
                title: Text(l10n.reminder),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          PopupMenuItem(
            value: 'tags',
            child: ListTile(
              leading: const Icon(AppIcons.tag),
              title: Text(l10n.manageTags),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          if (!config.isNew)
            PopupMenuItem(
              value: 'backlinks',
              child: ListTile(
                leading: const Icon(AppIcons.link),
                title: Text(l10n.viewBacklinks),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          if (!config.isNew)
            PopupMenuItem(
              value: 'related',
              child: ListTile(
                leading: const Icon(AppIcons.arrowUpRight),
                title: Text(l10n.relatedNotes),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          if (!config.isNew)
            PopupMenuItem(
              value: 'properties',
              child: ListTile(
                leading: const Icon(AppIcons.tune),
                title: Text(l10n.viewProperties),
                contentPadding: EdgeInsets.zero,
              ),
            ),

          const PopupMenuDivider(),

          // --- Share & Export section ---
          PopupMenuItem(
            value: 'share',
            child: ListTile(
              leading: const Icon(AppIcons.share),
              title: Text(l10n.shareNote),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          if (!config.isNew && config.noteId != null)
            PopupMenuItem(
              value: 'print',
              child: ListTile(
                leading: const Icon(AppIcons.print),
                title: Text(l10n.printNote),
                contentPadding: EdgeInsets.zero,
              ),
            ),

          const PopupMenuDivider(),

          // --- Publish section ---
          if (!config.isNew && config.noteId != null)
            PopupMenuItem(
              value: 'publish',
              child: ListTile(
                leading: const Icon(AppIcons.publish),
                title: Text(l10n.publishToPlatform),
                contentPadding: EdgeInsets.zero,
              ),
            ),

          const PopupMenuDivider(),

          // --- AI Features section ---
          PopupMenuItem(
            value: 'ai_summary',
            child: ListTile(
              leading: const Icon(AppIcons.summarize),
              title: Text(l10n.smartSummary),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          PopupMenuItem(
            value: 'ai_tags',
            child: ListTile(
              leading: const Icon(AppIcons.tag),
              title: Text(l10n.aiTagSuggestion),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          PopupMenuItem(
            value: 'ai_translate',
            child: ListTile(
              leading: const Icon(AppIcons.language),
              title: Text(l10n.aiTranslation),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          PopupMenuItem(
            value: 'ai_polish',
            child: ListTile(
              leading: const Icon(AppIcons.spellcheck),
              title: Text(l10n.writingPolish),
              contentPadding: EdgeInsets.zero,
            ),
          ),

          const PopupMenuDivider(),

          // --- View & Mode section ---
          PopupMenuItem(
            value: 'fold_view',
            child: ListTile(
              leading: Icon(
                config.isFoldView ? AppIcons.editNote : AppIcons.viewHeadline,
              ),
              title: Text(config.isFoldView ? l10n.edit : l10n.foldView),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          if (!config.isNew)
            PopupMenuItem(
              value: 'read_aloud',
              child: ListTile(
                leading: _buildSpeechIcon(ref),
                title: Text(l10n.readAloud),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          PopupMenuItem(
            value: 'typewriter',
            child: ListTile(
              leading: Icon(
                config.isTypewriterScroll
                    ? AppIcons.verticalAlignCenter
                    : AppIcons.verticalAlignTop,
              ),
              title: Text(l10n.typewriterScroll),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          // Focus mode has no standalone menu item: entering zen mode
          // auto-enables it (and typewriter scroll). One entry, one label.
          PopupMenuItem(
            value: 'zen',
            child: ListTile(
              leading: Icon(
                config.isZenMode
                    ? AppIcons.fullscreenExit
                    : AppIcons.fullscreen,
              ),
              title: Text(
                config.isZenMode ? l10n.exitZenMode : l10n.enterZenMode,
              ),
              contentPadding: EdgeInsets.zero,
            ),
          ),

          const PopupMenuDivider(),

          if (config.onSemanticIndex != null) ...[
            PopupMenuItem(
              value: 'semantic_index',
              child: ListTile(
                leading: const Icon(AppIcons.psychology),
                title: Text(l10n.semanticIndex),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
          const PopupMenuDivider(),

          // --- Insert section ---
          PopupMenuItem(
            value: 'image',
            child: ListTile(
              leading: const Icon(AppIcons.imageIcon),
              title: Text(l10n.addImage),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          // Clipboard image paste is a keyboard/mouse workflow — phones
          // insert images via gallery/camera instead.
          if (PlatformUtils.isDesktop)
            PopupMenuItem(
              value: 'paste_image',
              child: ListTile(
                leading: const Icon(AppIcons.contentPaste),
                title: Text(l10n.pasteImage),
                contentPadding: EdgeInsets.zero,
              ),
            ),

          const PopupMenuDivider(),

          // --- Save & Close ---
          PopupMenuItem(
            value: 'save_close',
            child: ListTile(
              leading: const Icon(AppIcons.check),
              title: Text(l10n.saveAndClose),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    ];
  }

  /// Build the speech icon based on current TTS state.
  static Icon _buildSpeechIcon(WidgetRef ref) {
    final speechState =
        ref.read(speechStateProvider).valueOrNull ?? SpeechState.stopped;
    return Icon(
      speechState == SpeechState.stopped
          ? AppIcons.volumeUp
          : AppIcons.volumeUpFilled,
    );
  }

  /// Handle overflow menu item selection by dispatching to the appropriate
  /// callback in the config.
  static void _handleOverflowSelection(
    BuildContext context,
    WidgetRef ref,
    EditorActionsConfig config,
    String value,
  ) {
    switch (value) {
      case 'toggle_preview':
        config.onTogglePreview();
      case 'lock':
        config.onToggleLock();
      case 'reminder':
        config.onShowReminderPicker();
      case 'tags':
        config.onShowTagPicker();
      case 'backlinks':
        config.onShowBacklinks();
      case 'related':
        config.onShowRelatedNotes();
      case 'properties':
        config.onShowProperties();
      case 'share':
        config.onShare?.call();
      case 'print':
        config.onPrint();
      case 'publish':
        config.onPublishToPlatform?.call();
      case 'ai_summary':
        config.onAiAction('summary');
      case 'ai_tags':
        config.onAiAction('tags');
      case 'ai_translate':
        config.onAiAction('translate');
      case 'ai_polish':
        config.onAiAction('polish');
      case 'fold_view':
        config.onToggleFoldView();
      case 'read_aloud':
        config.onReadAloud();
      case 'typewriter':
        config.onToggleTypewriterScroll();
      case 'zen':
        config.onToggleZenMode();
      case 'image':
        config.onPickImage();
      case 'paste_image':
        config.onPasteImage();
      case 'semantic_index':
        config.onSemanticIndex?.call();
      case 'save_close':
        config.onSaveAndClose();
    }
  }

  /// Minimal AppBar actions for preview/read mode.
  /// Matches the design mockup: save status, share, more menu.
  static List<Widget> _buildPreviewActions(
    BuildContext context,
    WidgetRef ref,
    EditorActionsConfig config,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    return [
      _AppBarSaveStatus(isSaving: config.isSaving, isDirty: config.isDirty),
      // Share action directly visible in preview mode.
      if (config.onShare != null)
        IconButton(
          icon: const Icon(AppIcons.share),
          tooltip: l10n.shareNote,
          onPressed: config.onShare,
        ),
      // Overflow menu with all secondary actions.
      PopupMenuButton<String>(
        icon: const Icon(AppIcons.moreHorizontal),
        tooltip: l10n.moreActions,
        onSelected: (value) => _handleOverflowSelection(
          context,
          ref,
          config,
          value,
        ),
        itemBuilder: (context) => [
          // --- Switch to edit ---
          PopupMenuItem(
            value: 'toggle_preview',
            child: ListTile(
              leading: const Icon(AppIcons.edit),
              title: Text(l10n.edit),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const PopupMenuDivider(),
          // --- Note section ---
          PopupMenuItem(
            value: 'tags',
            child: ListTile(
              leading: const Icon(AppIcons.tag),
              title: Text(l10n.manageTags),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          if (!config.isNew)
            PopupMenuItem(
              value: 'backlinks',
              child: ListTile(
                leading: const Icon(AppIcons.link),
                title: Text(l10n.viewBacklinks),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          if (!config.isNew)
            PopupMenuItem(
              value: 'related',
              child: ListTile(
                leading: const Icon(AppIcons.arrowUpRight),
                title: Text(l10n.relatedNotes),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          if (!config.isNew)
            PopupMenuItem(
              value: 'properties',
              child: ListTile(
                leading: const Icon(AppIcons.tune),
                title: Text(l10n.viewProperties),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          const PopupMenuDivider(),
          // --- Export ---
          if (!config.isNew && config.noteId != null)
            PopupMenuItem(
              value: 'print',
              child: ListTile(
                leading: const Icon(AppIcons.print),
                title: Text(l10n.printNote),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          if (!config.isNew && config.noteId != null)
            PopupMenuItem(
              value: 'publish',
              child: ListTile(
                leading: const Icon(AppIcons.publish),
                title: Text(l10n.publishToPlatform),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          const PopupMenuDivider(),
          // --- AI ---
          PopupMenuItem(
            value: 'ai_summary',
            child: ListTile(
              leading: const Icon(AppIcons.summarize),
              title: Text(l10n.smartSummary),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          PopupMenuItem(
            value: 'ai_translate',
            child: ListTile(
              leading: const Icon(AppIcons.language),
              title: Text(l10n.aiTranslation),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          PopupMenuItem(
            value: 'read_aloud',
            child: ListTile(
              leading: _buildSpeechIcon(ref),
              title: Text(l10n.readAloud),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    ];
  }
}

/// Compact save status indicator for the editor AppBar.
///
/// Shows one of three states inline:
/// - Spinning indicator when saving.
/// - Green checkmark when saved (not dirty, not saving). It lands like a
///   stamp, so "saved" is something you see happen.
/// - Red dot when there are unsaved changes (dirty).
class _AppBarSaveStatus extends StatelessWidget {
  final bool isSaving;
  final bool isDirty;

  const _AppBarSaveStatus({
    required this.isSaving,
    required this.isDirty,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    if (isSaving) {
      return Semantics(
        label: l10n.statusSaving,
        liveRegion: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colorScheme.tertiary,
            ),
          ),
        ),
      );
    }

    if (isDirty) {
      return Semantics(
        label: l10n.statusUnsaved,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Tooltip(
            message: l10n.statusUnsaved,
            child:
                Icon(AppIcons.circleFilled, size: 8, color: colorScheme.error),
          ),
        ),
      );
    }

    return Semantics(
      label: l10n.statusSaved,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: LandIn(
          drop: 2,
          child: Tooltip(
            message: l10n.statusSaved,
            child: const Icon(
              AppIcons.checkCircle,
              size: 16,
              color: AppColors.success,
            ),
          ),
        ),
      ),
    );
  }
}
