import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_durations.dart';
import '../../../core/collab/presence_indicator.dart';
import '../../../l10n/app_localizations.dart';

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
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
  late final String _inviteCode;
  final TextEditingController _inviteCodeController = TextEditingController();
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    // Generate a UUID v4 invite code for this note's collaboration room.
    _inviteCode = const Uuid().v4();
    _inviteCodeController.text = _inviteCode;
  }

  @override
  void dispose() {
    _inviteCodeController.dispose();
    super.dispose();
  }

  void _copyInviteCode() {
    Clipboard.setData(ClipboardData(text: _inviteCode));
    setState(() => _copied = true);

    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.inviteCodeCopied),
        duration: AppDurations.snackbarDuration,
      ),
    );

    // Reset the copied state after the snackbar duration.
    Future.delayed(AppDurations.snackbarDuration, () {
      if (mounted) {
        setState(() => _copied = false);
      }
    });
  }

  void _handleJoin() {
    final enteredCode = _inviteCodeController.text.trim();
    if (enteredCode.isEmpty) return;

    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.joinSharedNote(enteredCode)),
        duration: AppDurations.snackbarDuration,
      ),
    );

    // In v1.2.0, backend integration is out of scope.
    // Future: Send join request to backend with the invite code.
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Get current presence in this room.
    final presenceMap = ref.watch(presenceProvider);
    final presentUsers = presenceMap.values.toList();

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DragHandle(colorScheme: colorScheme),
          _ShareContent(
            l10n: l10n,
            theme: theme,
            colorScheme: colorScheme,
            presentUsers: presentUsers,
            presenceText: _getPresenceText(presentUsers.length, l10n),
            inviteCode: _inviteCode,
            copied: _copied,
            onCopy: _copyInviteCode,
            inviteCodeController: _inviteCodeController,
            onJoin: _handleJoin,
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
  final ColorScheme colorScheme;

  const _DragHandle({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      width: 32,
      height: 4,
      decoration: BoxDecoration(
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

/// Main content column inside the share sheet.
class _ShareContent extends StatelessWidget {
  final AppLocalizations l10n;
  final ThemeData theme;
  final ColorScheme colorScheme;
  final List<RoomPresence> presentUsers;
  final String presenceText;
  final String inviteCode;
  final bool copied;
  final VoidCallback onCopy;
  final TextEditingController inviteCodeController;
  final VoidCallback onJoin;

  const _ShareContent({
    required this.l10n,
    required this.theme,
    required this.colorScheme,
    required this.presentUsers,
    required this.presenceText,
    required this.inviteCode,
    required this.copied,
    required this.onCopy,
    required this.inviteCodeController,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.people_outline, color: colorScheme.primary),
              const SizedBox(width: 12),
              Text(l10n.shareNote, style: theme.textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: 16),
          if (presentUsers.isNotEmpty) ...[
            _PresenceRow(
              presentUsers: presentUsers,
              presenceText: presenceText,
              theme: theme,
              colorScheme: colorScheme,
            ),
            const SizedBox(height: 16),
          ],
          _InviteCodeSection(
            inviteCode: inviteCode,
            copied: copied,
            onCopy: onCopy,
            l10n: l10n,
            theme: theme,
            colorScheme: colorScheme,
          ),
          const Divider(),
          const SizedBox(height: 16),
          _JoinCodeSection(
            inviteCodeController: inviteCodeController,
            inviteCodeHint: inviteCode,
            onJoin: onJoin,
            l10n: l10n,
          ),
          const SizedBox(height: 16),
          _SecurityNotice(l10n: l10n, theme: theme, colorScheme: colorScheme),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Row showing presence avatars and a text label for active collaborators.
class _PresenceRow extends StatelessWidget {
  final List<RoomPresence> presentUsers;
  final String presenceText;
  final ThemeData theme;
  final ColorScheme colorScheme;

  const _PresenceRow({
    required this.presentUsers,
    required this.presenceText,
    required this.theme,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        PresenceAvatarStack(users: presentUsers),
        const SizedBox(width: 12),
        Text(
          presenceText,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
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
  final ThemeData theme;
  final ColorScheme colorScheme;

  const _InviteCodeSection({
    required this.inviteCode,
    required this.copied,
    required this.onCopy,
    required this.l10n,
    required this.theme,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.anyoneWithCode,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  inviteCode,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontFamily: 'monospace',
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(copied ? Icons.check : Icons.copy),
                onPressed: onCopy,
                tooltip: l10n.copyInviteCode,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: copied ? null : onCopy,
            icon: const Icon(Icons.copy),
            label: Text(
              copied ? l10n.inviteCodeCopied : l10n.copyInviteCode,
            ),
          ),
        ),
        const SizedBox(height: 24),
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

  const _JoinCodeSection({
    required this.inviteCodeController,
    required this.inviteCodeHint,
    required this.onJoin,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.enterInviteCode,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: inviteCodeController,
          decoration: InputDecoration(
            hintText: inviteCodeHint,
            border: const OutlineInputBorder(),
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
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onJoin,
            icon: const Icon(Icons.login),
            label: Text(l10n.joinSharedNote('')),
          ),
        ),
      ],
    );
  }
}

/// E2E security notice and sharing instructions displayed at the bottom.
class _SecurityNotice extends StatelessWidget {
  final AppLocalizations l10n;
  final ThemeData theme;
  final ColorScheme colorScheme;

  const _SecurityNotice({
    required this.l10n,
    required this.theme,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.lock_outline,
                size: 20,
                color: colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.e2eSharingNotice,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.shareSecurely,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
