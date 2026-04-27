import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../core/tts/speech_service.dart';
import '../../../../core/collab/presence_indicator.dart';

/// Builds the list of action widgets for the [NoteEditorScreen] AppBar.
///
/// Extracted from the monolithic editor screen to keep the build method
/// manageable. All callbacks are passed in so this helper remains pure.
///
/// Usage: `actions: EditorAppBarActions.buildActions(context, ref, ...)`
class EditorAppBarActions {
  EditorAppBarActions._();

  /// Returns the list of action widgets for the editor AppBar.
  static List<Widget> buildActions({
    required BuildContext context,
    required WidgetRef ref,
    required String? noteId,
    required bool isNew,
    required bool isLocked,
    required bool isSaving,
    required bool useRichEditor,
    required bool isPreview,
    required bool isFoldView,
    required bool isTypewriterScroll,
    required bool isFocusMode,
    required bool isZenMode,
    required bool hasReminder,
    required VoidCallback onToggleLock,
    required VoidCallback onShowReminderPicker,
    required VoidCallback onToggleRichEditor,
    required VoidCallback onTogglePreview,
    required VoidCallback onToggleFoldView,
    required VoidCallback onReadAloud,
    required VoidCallback onShowTagPicker,
    required VoidCallback onShowBacklinks,
    required VoidCallback onShowRelatedNotes,
    required VoidCallback onShowProperties,
    required VoidCallback onShare,
    required VoidCallback onPrint,
    required VoidCallback onPickImage,
    required VoidCallback onPasteImage,
    required ValueChanged<String> onAiAction,
    required VoidCallback onToggleTypewriterScroll,
    required VoidCallback onToggleFocusMode,
    required VoidCallback onToggleZenMode,
    required VoidCallback onSaveAndClose,
  }) {
    final l10n = AppLocalizations.of(context)!;

    return [
      // Presence avatars showing active collaborators.
      if (noteId != null)
        PresenceAvatarStack(
          users: ref.watch(presenceProvider).values.toList(),
        ),
      // Lock/unlock toggle (only for existing notes).
      if (!isNew && noteId != null)
        IconButton(
          icon: Icon(
            isLocked ? Icons.lock : Icons.lock_open,
          ),
          tooltip: isLocked ? l10n.unlockNote : l10n.lockNote,
          onPressed: onToggleLock,
        ),
      // Reminder bell icon with active indicator.
      if (noteId != null)
        IconButton(
          icon: Badge(
            isLabelVisible: hasReminder,
            child: const Icon(Icons.notifications_outlined),
          ),
          tooltip: l10n.reminder,
          onPressed: onShowReminderPicker,
        ),
      if (isSaving)
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
          useRichEditor ? Icons.short_text : Icons.text_fields,
        ),
        tooltip: useRichEditor ? l10n.plainText : l10n.richText,
        onPressed: onToggleRichEditor,
      ),
      IconButton(
        icon: Icon(isPreview ? Icons.edit : Icons.visibility),
        tooltip: isPreview ? l10n.edit : l10n.preview,
        onPressed: onTogglePreview,
      ),
      // Fold view toggle.
      IconButton(
        icon: Icon(
          isFoldView ? Icons.edit_note_outlined : Icons.view_headline_outlined,
        ),
        tooltip: isFoldView ? l10n.edit : l10n.foldView,
        onPressed: onToggleFoldView,
      ),
      // Read aloud button.
      if (!isNew)
        Builder(
          builder: (context) {
            final speechState = ref.watch(speechStateProvider).valueOrNull ??
                SpeechState.stopped;
            return IconButton(
              icon: Icon(
                speechState == SpeechState.stopped
                    ? Icons.volume_up_outlined
                    : Icons.volume_up,
              ),
              tooltip: l10n.readAloud,
              onPressed: onReadAloud,
            );
          },
        ),
      IconButton(
        icon: const Icon(Icons.sell_outlined),
        tooltip: l10n.manageTags,
        onPressed: onShowTagPicker,
      ),
      if (!isNew)
        IconButton(
          icon: const Icon(Icons.link_outlined),
          tooltip: l10n.viewBacklinks,
          onPressed: onShowBacklinks,
        ),
      if (!isNew)
        IconButton(
          icon: const Icon(Icons.call_made_outlined),
          tooltip: l10n.relatedNotes,
          onPressed: onShowRelatedNotes,
        ),
      if (!isNew)
        IconButton(
          icon: const Icon(Icons.tune_outlined),
          tooltip: l10n.viewProperties,
          onPressed: onShowProperties,
        ),
      IconButton(
        icon: const Icon(Icons.share_outlined),
        tooltip: l10n.shareNote,
        onPressed: onShare,
      ),
      // Print button.
      if (!isNew && noteId != null)
        IconButton(
          icon: const Icon(Icons.print_outlined),
          tooltip: l10n.printNote,
          onPressed: onPrint,
        ),
      IconButton(
        icon: const Icon(Icons.image_outlined),
        tooltip: l10n.addImage,
        onPressed: onPickImage,
      ),
      IconButton(
        icon: const Icon(Icons.content_paste_outlined),
        tooltip: l10n.pasteImage,
        onPressed: onPasteImage,
      ),
      PopupMenuButton<String>(
        icon: const Icon(Icons.auto_awesome_outlined),
        tooltip: l10n.aiFeatures,
        onSelected: onAiAction,
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
      // Typewriter scroll toggle.
      IconButton(
        icon: Icon(
          isTypewriterScroll
              ? Icons.vertical_align_center
              : Icons.vertical_align_top_outlined,
        ),
        tooltip: l10n.typewriterScroll,
        onPressed: onToggleTypewriterScroll,
      ),
      // Focus mode toggle.
      IconButton(
        icon: Icon(
          isFocusMode ? Icons.highlight : Icons.highlight_outlined,
        ),
        tooltip: l10n.focusMode,
        onPressed: onToggleFocusMode,
      ),
      // Zen mode toggle.
      IconButton(
        icon: Icon(
          isZenMode ? Icons.fullscreen_exit : Icons.fullscreen,
        ),
        tooltip: isZenMode ? l10n.exitZenMode : l10n.enterZenMode,
        onPressed: onToggleZenMode,
      ),
      IconButton(
        icon: const Icon(Icons.check),
        tooltip: l10n.saveAndClose,
        onPressed: onSaveAndClose,
      ),
    ];
  }
}
