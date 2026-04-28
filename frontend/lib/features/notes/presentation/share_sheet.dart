import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../core/share/share_service.dart';
import '../../../core/widgets/app_snackbar.dart';

/// Bottom sheet for creating a shared note link.
///
/// Options:
/// - Share with or without password protection
/// - Expiry: 1 hour, 24 hours, 7 days, never
/// - "Create Link" button that triggers the share creation
/// - After creation, shows the link with a copy button
///
/// In frontend-only mode the link is self-contained: it carries the
/// encrypted payload in the URL path and the decryption key in the
/// fragment. No network request is needed.
class ShareSheet extends ConsumerStatefulWidget {
  final String title;
  final String content;

  const ShareSheet({
    super.key,
    required this.title,
    required this.content,
  });

  @override
  ConsumerState<ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends ConsumerState<ShareSheet> {
  bool _usePassword = false;
  final _passwordController = TextEditingController();
  int _expiresHours = 24; // Default: 24 hours

  bool _isCreating = false;
  ShareResult? _result;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _createShare() async {
    final l10n = AppLocalizations.of(context)!;
    if (_usePassword && _passwordController.text.isEmpty) {
      setState(() => _error = l10n.passwordRequiredForShare);
      return;
    }

    setState(() {
      _isCreating = true;
      _error = null;
    });

    try {
      final shareService = ref.read(shareServiceProvider);
      final result = await shareService.createShare(
        plainTitle: widget.title,
        plainContent: widget.content,
        password: _usePassword ? _passwordController.text : null,
        expiresHours: _expiresHours == 0 ? null : _expiresHours,
      );

      if (mounted) {
        setState(() {
          _result = result;
          _isCreating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        setState(() {
          _error = l10n.failedToCreateShareLink(e.toString());
          _isCreating = false;
        });
      }
    }
  }

  void _copyLink() {
    if (_result == null) return;
    final l10n = AppLocalizations.of(context)!;
    Clipboard.setData(ClipboardData(text: _result!.shareLink));
    AppSnackBar.info(context, message: l10n.linkCopiedToClipboard);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            l10n.shareNote,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            widget.title,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 20),

          if (_result != null) ...[
            _buildResultSection(theme),
          ] else ...[
            _buildOptionsSection(theme),
          ],
        ],
      ),
    );
  }

  Widget _buildResultSection(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Share link display
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _result!.shareLink,
                  style: theme.textTheme.bodySmall,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.copy),
                onPressed: _copyLink,
                tooltip: l10n.copyLink,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Info text
        Text(
          _result!.hasPassword
              ? l10n.passwordProtectedShareInfo
              : l10n.publicShareInfo,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (_result!.expiresAt != null) ...[
          const SizedBox(height: 4),
          Text(
            l10n.linkExpiresIn(_formatExpiry(_result!.expiresAt!)),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 16),

        FilledButton.icon(
          onPressed: _copyLink,
          icon: const Icon(Icons.copy),
          label: Text(l10n.copyLink),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.done),
        ),
      ],
    );
  }

  Widget _buildOptionsSection(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    final expiryOptions = [
      (label: l10n.oneHour, value: 1),
      (label: l10n.twentyFourHours, value: 24),
      (label: l10n.sevenDays, value: 168),
      (label: l10n.never, value: 0),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Password protection toggle
        _buildSectionLabel(theme, l10n.passwordProtection),
        SwitchListTile(
          value: _usePassword,
          onChanged: (v) => setState(() {
            _usePassword = v;
            _error = null;
          }),
          title: Text(l10n.requirePassword),
          subtitle: Text(l10n.requirePasswordDesc),
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        if (_usePassword) ...[
          const SizedBox(height: 4),
          TextField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: l10n.password,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.lock_outline),
              errorText: _error,
            ),
            obscureText: true,
            autofocus: true,
          ),
          const SizedBox(height: 12),
        ],

        // Expiry selector
        _buildSectionLabel(theme, l10n.expiresAfter),
        const SizedBox(height: 4),
        DropdownButtonFormField<int>(
          initialValue: _expiresHours,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          items: expiryOptions
              .map(
                (opt) => DropdownMenuItem(
                  value: opt.value,
                  child: Text(opt.label),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) setState(() => _expiresHours = v);
          },
        ),
        const SizedBox(height: 20),

        // Error display
        if (_error != null && !_usePassword)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _error!,
              style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
            ),
          ),

        // Create button
        FilledButton.icon(
          onPressed: _isCreating ? null : _createShare,
          icon: _isCreating
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.link),
          label: Text(_isCreating ? l10n.encrypting : l10n.createShareLink),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(ThemeData theme, String label) {
    return Text(
      label,
      style: theme.textTheme.labelLarge?.copyWith(
        color: theme.colorScheme.primary,
      ),
    );
  }

  String _formatExpiry(DateTime expiresAt) {
    final l10n = AppLocalizations.of(context)!;
    final remaining = expiresAt.difference(DateTime.now().toUtc());
    if (remaining.isNegative) return l10n.expiryImmediately;
    if (remaining.inHours < 1) return l10n.expiryLessThanOneHour;
    if (remaining.inHours < 24) return l10n.expiryInHours(remaining.inHours);
    return l10n.expiryInDays(remaining.inDays);
  }
}
