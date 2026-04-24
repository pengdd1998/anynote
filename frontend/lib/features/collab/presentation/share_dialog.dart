import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

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
        duration: const Duration(seconds: 2),
      ),
    );

    // Reset the copied state after the snackbar duration.
    Future.delayed(const Duration(seconds: 2), () {
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
        duration: const Duration(seconds: 2),
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

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle.
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title.
                Row(
                  children: [
                    Icon(
                      Icons.people_outline,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      l10n.shareNote,
                      style: theme.textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Presence avatars.
                if (presentUsers.isNotEmpty) ...[
                  Row(
                    children: [
                      PresenceAvatarStack(users: presentUsers),
                      const SizedBox(width: 12),
                      Text(
                        _getPresenceText(presentUsers.length, l10n),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // Invite code section.
                Text(
                  l10n.anyoneWithCode,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),

                // Invite code display with copy button.
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
                          _inviteCode,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontFamily: 'monospace',
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(_copied ? Icons.check : Icons.copy),
                        onPressed: _copyInviteCode,
                        tooltip: l10n.copyInviteCode,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Copy button (full width).
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _copied ? null : _copyInviteCode,
                    icon: const Icon(Icons.copy),
                    label: Text(
                      _copied ? l10n.inviteCodeCopied : l10n.copyInviteCode,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Divider.
                const Divider(),
                const SizedBox(height: 16),

                // "Enter Invite Code" section.
                Text(
                  l10n.enterInviteCode,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),

                // Invite code input field.
                TextField(
                  controller: _inviteCodeController,
                  decoration: InputDecoration(
                    hintText: _inviteCode,
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.login),
                      onPressed: _handleJoin,
                      tooltip: l10n.joinSharedNote(''),
                    ),
                  ),
                  textCapitalization: TextCapitalization.none,
                  autocorrect: false,
                  onSubmitted: (_) => _handleJoin(),
                ),
                const SizedBox(height: 12),

                // Join button.
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _handleJoin,
                    icon: const Icon(Icons.login),
                    label: Text(l10n.joinSharedNote('')),
                  ),
                ),
                const SizedBox(height: 16),

                // E2E security notice.
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

                // Sharing instructions.
                Text(
                  l10n.shareSecurely,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
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
