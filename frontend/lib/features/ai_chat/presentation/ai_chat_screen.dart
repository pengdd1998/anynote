import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/app_durations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/chat_message.dart';
import '../providers/ai_chat_providers.dart';

/// AI Chat Assistant screen for multi-turn conversations about notes.
///
/// Users can optionally select notes as context before starting a chat.
/// Messages stream in real-time via SSE.
class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(startChatSessionProvider)();
      }
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    try {
      ref.read(chatSessionProvider.notifier).cancel();
    } catch (_) {}
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: AppDurations.shortAnimation,
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSend() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    _inputController.clear();
    ref.read(chatSessionProvider.notifier).sendMessage(text);
    _scrollToBottom();
  }

  /// Sends a follow-up suggestion chip tap as a regular user message.
  void _sendFollowUp(String text) {
    ref.read(chatSessionProvider.notifier).sendMessage(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final session = ref.watch(chatSessionProvider);
    final messages = session.messages.whereType<ChatMessage>().toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Follow-up suggestions appear under the last completed AI message.
    final showFollowUps = messages.isNotEmpty &&
        messages.last.role == 'assistant' &&
        !messages.last.isStreaming &&
        !session.isLoading;

    ref.listen(chatSessionProvider, (prev, next) {
      if (prev?.messages.length != next.messages.length) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(
          session.title.isEmpty ? l10n.aiChatAssistant : session.title,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(AppIcons.noteAdd),
            tooltip: l10n.selectContextNotes,
            onPressed: () => _showContextNoteSelector(context),
          ),
          IconButton(
            icon: const Icon(AppIcons.chat),
            tooltip: l10n.newChat,
            onPressed: () {
              ref.read(startChatSessionProvider)();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Context notes indicator
          if (session.contextNoteIds.isNotEmpty)
            _buildContextBanner(session, l10n, isDark),

          // Error banner
          if (session.error != null)
            _buildErrorBanner(session, isDark),

          // Messages list
          Expanded(
            child: messages.isEmpty
                ? _buildEmptyState(l10n, isDark)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.s8,
                      AppSpacing.md,
                      AppSpacing.s8,
                    ),
                    itemCount: messages.length + (showFollowUps ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == messages.length) {
                        return _FollowUpChips(
                          onSelect: _sendFollowUp,
                          isDark: isDark,
                        );
                      }
                      return _AiMessageBubble(
                        message: messages[index],
                        isLast: index == messages.length - 1,
                      );
                    },
                  ),
          ),

          // Input area
          _ChatInput(
            controller: _inputController,
            isLoading: session.isLoading,
            onSend: _handleSend,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildContextBanner(
    dynamic session,
    AppLocalizations l10n,
    bool isDark,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.s4,
        AppSpacing.md,
        0,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s12,
        vertical: AppSpacing.s8,
      ),
      decoration: BoxDecoration(
        color: AppColors.accentLavenderBg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.description_outlined,
            size: 16,
            color: AppColors.accentLavenderText,
          ),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Text(
              l10n.contextNotesCount(session.contextNoteIds.length),
              style: AppTextStyles.caption.copyWith(
                fontSize: 12,
                color: AppColors.accentLavenderText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(dynamic session, bool isDark) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.s4,
        AppSpacing.md,
        0,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s12,
        vertical: AppSpacing.s8,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkErrorBg : AppColors.lightErrorBg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              session.error!,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.error,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => ref.read(chatSessionProvider.notifier).clearError(),
            child: const Icon(
              Icons.close,
              size: 16,
              color: AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n, bool isDark) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(
                AppIcons.sparkles,
                size: 32,
                color: AppColors.primaryText,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.aiChatWelcome,
              style: AppTextStyles.title.copyWith(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              l10n.aiChatWelcomeDesc,
              style: AppTextStyles.caption.copyWith(
                color: isDark
                    ? AppColors.darkTextTertiary
                    : AppColors.lightTextTertiary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            // Full-width purple "New Session" CTA.
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => ref.read(startChatSessionProvider)(),
                icon: const Icon(AppIcons.sparkles, size: 18),
                label: Text(l10n.newChat),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: isDark
                      ? AppColors.darkDisabled
                      : AppColors.primaryDisabled,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showContextNoteSelector(BuildContext context) {
    final notesAsync = ref.read(notesForChatContextProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      builder: (context) => _ContextNoteSelectorSheet(
        notesAsync: notesAsync,
        selectedIds: ref.read(chatSessionProvider).contextNoteIds.toSet(),
        onConfirm: (selectedNotes) {
          ref.read(chatSessionProvider.notifier).setContextNotes(selectedNotes);
          Navigator.pop(context);
        },
      ),
    );
  }
}

/// A single message bubble in the chat with warm styling.
///
/// User messages appear on the right in soft lavender tinted bubbles.
/// AI messages appear on the left in bordered surface cards.
class _AiMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isLast;

  const _AiMessageBubble({required this.message, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        bottom: isLast ? AppSpacing.s12 : AppSpacing.s8,
      ),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          child: isUser
              ? _buildUserBubble(isDark)
              : _buildAiBubble(isDark),
        ),
      ),
    );
  }

  Widget _buildUserBubble(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s12,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.primary.withAlpha(45)
            : AppColors.primarySoft,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppRadius.sm),
          topRight: Radius.circular(AppRadius.sm),
          bottomLeft: Radius.circular(AppRadius.sm),
          bottomRight: Radius.circular(AppSpacing.s4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SelectableText(
            message.content,
            style: AppTextStyles.body.copyWith(
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(
            _formatTime(message.timestamp),
            style: AppTextStyles.caption.copyWith(
              fontSize: 10,
              color: isDark
                  ? AppColors.darkTextTertiary
                  : AppColors.primaryText.withAlpha(180),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiBubble(bool isDark) {
    final bgColor = isDark ? AppColors.darkCardBg : AppColors.lightCardBg;
    final borderColor =
        isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s12,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppRadius.sm),
          topRight: Radius.circular(AppRadius.sm),
          bottomLeft: Radius.circular(AppSpacing.s4),
          bottomRight: Radius.circular(AppRadius.sm),
        ),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI label
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.primary.withAlpha(45)
                      : AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.xxs),
                ),
                child: const Icon(
                  AppIcons.sparkles,
                  size: 10,
                  color: AppColors.primaryText,
                ),
              ),
              const SizedBox(width: AppSpacing.s4),
              Text(
                'AI',
                style: AppTextStyles.caption.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.secondary
                      : AppColors.primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          // Content
          SelectableText(
            message.content.isEmpty && message.isStreaming
                ? '...'
                : message.content,
            style: AppTextStyles.body.copyWith(
              color: textColor,
              height: 1.6,
            ),
          ),
          // Streaming indicator
          if (message.isStreaming)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.s4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary.withAlpha(180),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s4),
                  Text(
                    '...',
                    style: AppTextStyles.caption.copyWith(
                      color: isDark
                          ? AppColors.darkTextTertiary
                          : AppColors.lightTextTertiary,
                    ),
                  ),
                ],
              ),
            ),
          // Timestamp
          if (!message.isStreaming)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.s4),
              child: Text(
                _formatTime(message.timestamp),
                style: AppTextStyles.caption.copyWith(
                  fontSize: 10,
                  color: isDark
                      ? AppColors.darkTextTertiary
                      : AppColors.lightTextTertiary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

/// Input area for the chat with a text field and send button.
class _ChatInput extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onSend;
  final bool isDark;

  const _ChatInput({
    required this.controller,
    required this.isLoading,
    required this.onSend,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.s8,
        top: AppSpacing.s8,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.s8,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBg : AppColors.lightCardBg,
        border: Border(
          top: BorderSide(
            color: isDark
                ? AppColors.darkDivider.withAlpha(60)
                : AppColors.lightDivider.withAlpha(80),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkInputFill
                    : AppColors.lightInputFill,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: l10n.typeYourMessage,
                  hintStyle: AppTextStyles.body.copyWith(
                    color: isDark
                        ? AppColors.darkTextTertiary
                        : AppColors.lightTextTertiary,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s16,
                    vertical: AppSpacing.s12,
                  ),
                ),
                style: AppTextStyles.body,
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          // Circular purple send button.
          Container(
            width: 44,
            height: 44,
            margin: const EdgeInsets.only(bottom: 2),
            child: IconButton.filled(
              onPressed: isLoading ? null : onSend,
              icon: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(PhosphorIconsBold.arrowUp, size: 20),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: isDark
                    ? AppColors.darkDisabled
                    : AppColors.primaryDisabled,
                shape: const CircleBorder(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Follow-up suggestion chips shown under the last completed AI message.
///
/// Tapping a chip sends its label as a regular user message through the
/// existing chat session provider.
class _FollowUpChips extends StatelessWidget {
  final void Function(String text) onSelect;
  final bool isDark;

  const _FollowUpChips({required this.onSelect, required this.isDark});

  static const _suggestions = <String>[
    'Make it shorter',
    'More uplifting',
    'Summarize key points',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s4),
      child: Wrap(
        spacing: AppSpacing.s8,
        runSpacing: AppSpacing.s8,
        children: _suggestions
            .map(
              (label) => GestureDetector(
                onTap: () => onSelect(label),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s12,
                    vertical: AppSpacing.s8,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkCardBg
                        : AppColors.lightCardBg,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
                    ),
                  ),
                  child: Text(
                    label,
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

/// Bottom sheet for selecting notes as chat context.
class _ContextNoteSelectorSheet extends StatefulWidget {
  final AsyncValue<List<dynamic>> notesAsync;
  final Set<String> selectedIds;
  final void Function(Map<String, String> selectedNotes) onConfirm;

  const _ContextNoteSelectorSheet({
    required this.notesAsync,
    required this.selectedIds,
    required this.onConfirm,
  });

  @override
  State<_ContextNoteSelectorSheet> createState() =>
      _ContextNoteSelectorSheetState();
}

class _ContextNoteSelectorSheetState
    extends State<_ContextNoteSelectorSheet> {
  late Set<String> _selectedIds;
  final Map<String, String> _selectedContents = {};

  @override
  void initState() {
    super.initState();
    _selectedIds = Set.from(widget.selectedIds);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: (isDark
                          ? AppColors.darkTextTertiary
                          : AppColors.lightTextTertiary)
                      .withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.s8,
                AppSpacing.md,
                AppSpacing.s4,
              ),
              child: Row(
                children: [
                  Text(
                    l10n.selectContextNotes,
                    style: AppTextStyles.headline,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: l10n.close,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Note list
            Expanded(
              child: widget.notesAsync.when(
                data: (notes) {
                  if (notes.isEmpty) {
                    return Center(
                      child: Text(
                        l10n.noNotesAvailableCreate,
                        style: AppTextStyles.body.copyWith(
                          color: isDark
                              ? AppColors.darkTextTertiary
                              : AppColors.lightTextTertiary,
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: scrollController,
                    itemCount: notes.length,
                    itemBuilder: (context, index) {
                      final note = notes[index];
                      final title = note.plainTitle ?? l10n.untitled;
                      final preview = note.plainContent != null &&
                              note.plainContent!.length > 60
                          ? '${note.plainContent!.substring(0, 60)}...'
                          : note.plainContent ?? '';
                      final isSelected = _selectedIds.contains(note.id);

                      return CheckboxListTile(
                        value: isSelected,
                        title: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.body,
                        ),
                        subtitle: Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            color: isDark
                                ? AppColors.darkTextTertiary
                                : AppColors.lightTextTertiary,
                          ),
                        ),
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _selectedIds.add(note.id);
                              _selectedContents[note.id] =
                                  note.plainContent ?? '';
                            } else {
                              _selectedIds.remove(note.id);
                              _selectedContents.remove(note.id);
                            }
                          });
                        },
                      );
                    },
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (err, _) => Center(
                  child: Text(
                    err.toString(),
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ),
              ),
            ),
            // Confirm button
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      final result = <String, String>{};
                      for (final id in _selectedIds) {
                        final notesList =
                            widget.notesAsync.valueOrNull ?? [];
                        for (final note in notesList) {
                          if (note.id == id) {
                            result[id] = note.plainContent ?? '';
                            break;
                          }
                        }
                      }
                      widget.onConfirm(result);
                    },
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppRadius.sm),
                      ),
                    ),
                    child: Text(l10n.apply),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
