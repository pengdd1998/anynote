import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/compose_providers.dart';
import '../../data/ai_repository.dart';

/// Chat interface for iteratively refining the draft post via LLM.
///
/// Placed below the draft editor (split view). Each user instruction is sent
/// to the LLM along with the current draft + template context; the LLM
/// streams the updated draft, which the editor above reflects in real-time.
class RefinementChat extends ConsumerStatefulWidget {
  final String sessionId;

  const RefinementChat({super.key, required this.sessionId});

  @override
  ConsumerState<RefinementChat> createState() => _RefinementChatState();
}

class _RefinementChatState extends ConsumerState<RefinementChat> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    ref.read(composeSessionProvider.notifier).refineDraft(text).then((_) {
      if (mounted) {
        // Scroll to bottom after refinement completes.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(composeSessionProvider);
    final theme = Theme.of(context);
    final history = session.refinementHistory;
    final isRefining = session.isLoading;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.dividerColor.withAlpha(60),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s16,
              vertical: AppSpacing.s8,
            ),
            child: Row(
              children: [
                Icon(Icons.chat_bubble_outline,
                    size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: AppSpacing.s8),
                Text(
                  'AI 润色',
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (isRefining)
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: theme.colorScheme.primary,
                    ),
                  ),
              ],
            ),
          ),
          // Messages
          Expanded(
            child: history.isEmpty
                ? Center(
                    child: Text(
                      '输入修改指令来润色文章',
                      style: AppTextStyles.caption.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s16),
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final msg = history[index];
                      final isUser = msg.role == 'user';
                      return _ChatBubble(
                        text: isUser
                            ? msg.content
                            : (msg.content.length > 100
                                ? '${msg.content.substring(0, 100)}...'
                                : msg.content),
                        isUser: isUser,
                      );
                    },
                  ),
          ),
          // Input
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.s16, AppSpacing.s4, AppSpacing.s8, AppSpacing.s12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: !isRefining,
                    decoration: InputDecoration(
                      hintText: '如：让开头更吸引人',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s12,
                        vertical: AppSpacing.s8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest
                          .withAlpha(80),
                    ),
                    style: AppTextStyles.body.copyWith(fontSize: 14),
                    onSubmitted: (_) => _send(),
                    minLines: 1,
                    maxLines: 3,
                  ),
                ),
                const SizedBox(width: AppSpacing.s4),
                IconButton.filled(
                  onPressed: isRefining ? null : _send,
                  icon: const Icon(Icons.send, size: 18),
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final String text;
  final bool isUser;

  const _ChatBubble({required this.text, required this.isUser});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s8),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Icon(Icons.smart_toy, size: 16,
                color: theme.colorScheme.primary.withAlpha(180)),
            const SizedBox(width: AppSpacing.s4),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s12,
                vertical: AppSpacing.s8,
              ),
              decoration: BoxDecoration(
                color: isUser
                    ? theme.colorScheme.primary.withAlpha(30)
                    : theme.colorScheme.surfaceContainerHighest.withAlpha(100),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(AppRadius.md),
                  topRight: const Radius.circular(AppRadius.md),
                  bottomLeft: Radius.circular(isUser ? AppRadius.md : 4),
                  bottomRight: Radius.circular(isUser ? 4 : AppRadius.md),
                ),
              ),
              child: Text(
                text,
                style: AppTextStyles.body.copyWith(fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
