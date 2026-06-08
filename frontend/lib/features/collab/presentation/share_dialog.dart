import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_durations.dart';
import '../../../core/collab/presence_indicator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart';

/// Shows a bottom sheet for sharing a note with real-time collaboration.
///
/// For v1.2.0, this generates an invite code that users can share out-of-band
/// (similar to Signal's safety number exchange). The invite code is a UUID v4
/// that uniquely identifies the collaboration room.
///
/// In future versions, this will integrate with backend invite acceptance
/// and E2E key exchange mechanisms.
void showShareBottomSheet(BuildContext context, String noteId) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: AppRadius.topXl,
    ),
    builder: (_) => ShareNoteSheet(noteId: noteId),
  );
}

/// The bottom sheet widget for sharing a note.
class ShareNoteSheet extends ConsumerStatefulWidget {
  final String noteId;

  const ShareNoteSheet({super.key, required this.noteId});

  @override
  ConsumerState<ShareNoteSheet> createState() => _ShareNoteSheetState();
}

class _ShareNoteSheetState extends ConsumerState<ShareNoteSheet> {
  String? _inviteCode;
  final TextEditingController _inviteCodeController = TextEditingController();
  bool _copied = false;
  bool _isCreating = true;
  bool _isJoining = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _createRoom();
  }

  @override
  void dispose() {
    _inviteCodeController.dispose();
    super.dispose();
  }

  Future<void> _createRoom() async {
    setState(() => _isCreating = true);
    try {
      final api = ref.read(apiClientProvider);
      final room = await api.createCollabRoom(roomName: widget.noteId);
      if (!mounted) return;
      setState(() {
        _inviteCode = room['invite_code'] as String;
        _inviteCodeController.text = _inviteCode!;
        _isCreating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCreating = false;
        _error = e.toString();
      });
    }
  }

  void _copyInviteCode() {
    final code = _inviteCode;
    if (code == null) return;
    Clipboard.setData(ClipboardData(text: code));
    setState(() => _copied = true);

    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.inviteCodeCopied),
        duration: AppDurations.snackbarDuration,
      ),
    );

    Future.delayed(AppDurations.snackbarDuration, () {
      if (mounted) {
        setState(() => _copied = false);
      }
    });
  }

  Future<void> _handleJoin() async {
    final enteredCode = _inviteCodeController.text.trim();
    if (enteredCode.isEmpty) return;

    setState(() => _isJoining = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.joinCollabRoom(inviteCode: enteredCode);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.failedToJoinRoom),
          duration: AppDurations.snackbarDuration,
        ),
      );
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Get current presence in this room.
    final presenceMap = ref.watch(presenceProvider);
    final presentUsers = presenceMap.values.toList();
    final inviteCode = _inviteCode ?? '';

    if (_isCreating) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _DragHandle(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Center(
              child: CircularProgressIndicator(
                color: isDark
                    ? AppColors.darkTextTertiary
                    : AppColors.lightTextTertiary,
              ),
            ),
          ),
        ],
      );
    }

    if (_error != null && _inviteCode == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _DragHandle(),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              l10n.failedToCreateRoom,
              style: AppTextStyles.body.copyWith(
                color: AppColors.error,
              ),
            ),
          ),
        ],
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _DragHandle(),
          _ShareContent(
            l10n: l10n,
            isDark: isDark,
            presentUsers: presentUsers,
            presenceText: _getPresenceText(presentUsers.length, l10n),
            inviteCode: inviteCode,
            copied: _copied,
            onCopy: _copyInviteCode,
            inviteCodeController: _inviteCodeController,
            onJoin: _handleJoin,
            isJoining: _isJoining,
          ),
        ],
      ),
    );
  }

  String _getPresenceText(int count, AppLocalizations l10n) {
    if (count == 0) return l10n.nooneInRoom;
    if (count == 1) return l10n.onePersonInRoom;
    return l10n.multiplePeopleInRoom(count);
  }
}

/// Drag handle bar at the top of the bottom sheet.
class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.s12),
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: (isDark
                ? AppColors.darkTextTertiary
                : AppColors.lightTextTertiary)
            .withAlpha(80),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

/// Main content column inside the share sheet.
class _ShareContent extends StatelessWidget {
  final AppLocalizations l10n;
  final bool isDark;
  final List<RoomPresence> presentUsers;
  final String presenceText;
  final String inviteCode;
  final bool copied;
  final VoidCallback onCopy;
  final TextEditingController inviteCodeController;
  final VoidCallback onJoin;
  final bool isJoining;

  const _ShareContent({
    required this.l10n,
    required this.isDark,
    required this.presentUsers,
    required this.presenceText,
    required this.inviteCode,
    required this.copied,
    required this.onCopy,
    required this.inviteCodeController,
    required this.onJoin,
    required this.isJoining,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.accentLavenderBg,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: const Icon(
                  Icons.people_outline,
                  size: 18,
                  color: AppColors.accentLavenderText,
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Text(l10n.shareNote, style: AppTextStyles.headline),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (presentUsers.isNotEmpty) ...[
            _PresenceRow(
              presentUsers: presentUsers,
              presenceText: presenceText,
              isDark: isDark,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          _InviteCodeSection(
            inviteCode: inviteCode,
            copied: copied,
            onCopy: onCopy,
            l10n: l10n,
            isDark: isDark,
          ),
          Divider(
            height: 1,
            color: isDark
                ? AppColors.darkDivider.withAlpha(60)
                : AppColors.lightDivider.withAlpha(80),
          ),
          const SizedBox(height: AppSpacing.md),
          _JoinCodeSection(
            inviteCodeController: inviteCodeController,
            inviteCodeHint: inviteCode,
            onJoin: onJoin,
            l10n: l10n,
            isDark: isDark,
            isJoining: isJoining,
          ),
          const SizedBox(height: AppSpacing.md),
          _SecurityNotice(l10n: l10n, isDark: isDark),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

/// Row showing presence avatars and a text label for active collaborators.
class _PresenceRow extends StatelessWidget {
  final List<RoomPresence> presentUsers;
  final String presenceText;
  final bool isDark;

  const _PresenceRow({
    required this.presentUsers,
    required this.presenceText,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        PresenceAvatarStack(users: presentUsers),
        const SizedBox(width: AppSpacing.s12),
        Text(
          presenceText,
          style: AppTextStyles.body.copyWith(
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
        ),
      ],
    );
  }
}

/// Section displaying the generated invite code with a copy button.
class _InviteCodeSection extends StatelessWidget {
  final String inviteCode;
  final bool copied;
  final VoidCallback onCopy;
  final AppLocalizations l10n;
  final bool isDark;

  const _InviteCodeSection({
    required this.inviteCode,
    required this.copied,
    required this.onCopy,
    required this.l10n,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.anyoneWithCode,
          style: AppTextStyles.body.copyWith(
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkInputFill : AppColors.lightInputFill,
            borderRadius: BorderRadius.circular(AppRadius.xs),
          ),
          padding: const EdgeInsets.all(AppSpacing.s12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  inviteCode,
                  style: AppTextStyles.title.copyWith(
                    fontFamily: 'monospace',
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              SizedBox(
                width: AppSpacing.minTouchTarget,
                height: AppSpacing.minTouchTarget,
                child: IconButton(
                  icon: Icon(
                    copied ? Icons.check : Icons.copy,
                    color: copied ? AppColors.success : AppColors.primary,
                  ),
                  onPressed: onCopy,
                  tooltip: l10n.copyInviteCode,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: copied ? null : onCopy,
            icon: const Icon(Icons.copy),
            label: Text(
              copied ? l10n.inviteCodeCopied : l10n.copyInviteCode,
            ),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

/// Section with a text field for entering an invite code and joining a room.
class _JoinCodeSection extends StatelessWidget {
  final TextEditingController inviteCodeController;
  final String inviteCodeHint;
  final VoidCallback onJoin;
  final AppLocalizations l10n;
  final bool isDark;
  final bool isJoining;

  const _JoinCodeSection({
    required this.inviteCodeController,
    required this.inviteCodeHint,
    required this.onJoin,
    required this.l10n,
    required this.isDark,
    required this.isJoining,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.enterInviteCode,
          style: AppTextStyles.title.copyWith(fontSize: 14),
        ),
        const SizedBox(height: AppSpacing.s8),
        TextField(
          controller: inviteCodeController,
          scrollPadding: const EdgeInsets.only(bottom: 120),
          decoration: InputDecoration(
            hintText: inviteCodeHint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            suffixIcon: IconButton(
              icon: const Icon(Icons.login),
              onPressed: onJoin,
              tooltip: l10n.joinSharedNote(''),
            ),
          ),
          textCapitalization: TextCapitalization.none,
          autocorrect: false,
          onSubmitted: (_) => onJoin(),
        ),
        const SizedBox(height: AppSpacing.s12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: isJoining ? null : onJoin,
            icon: isJoining
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white.withAlpha(180),
                    ),
                  )
                : const Icon(Icons.login),
            label: Text(isJoining ? l10n.joining : l10n.joinSharedNote('')),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// E2E security notice and sharing instructions displayed at the bottom.
class _SecurityNotice extends StatelessWidget {
  final AppLocalizations l10n;
  final bool isDark;

  const _SecurityNotice({
    required this.l10n,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.s12),
          decoration: BoxDecoration(
            color: AppColors.accentLavenderBg,
            borderRadius: BorderRadius.circular(AppRadius.xs),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.lock_outline,
                size: 20,
                color: AppColors.accentLavenderText,
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  l10n.e2eSharingNotice,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.accentLavenderText,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        Text(
          l10n.shareSecurely,
          style: AppTextStyles.caption.copyWith(
            color: isDark
                ? AppColors.darkTextTertiary
                : AppColors.lightTextTertiary,
          ),
        ),
      ],
    );
  }
}
