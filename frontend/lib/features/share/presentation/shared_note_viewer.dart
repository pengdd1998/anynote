import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/exceptions.dart';
import '../../../core/share/share_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart';
import '../../comments/presentation/comment_list.dart';
import '../../comments/presentation/comment_input.dart';

/// Screen for viewing a shared note.
///
/// Supports server shares and self-contained shares with optional
/// password protection. Minimal chrome for clean reading.
class SharedNoteViewer extends ConsumerStatefulWidget {
  final String shareId;
  final String? shareKeyFragment;

  const SharedNoteViewer({
    super.key,
    required this.shareId,
    this.shareKeyFragment,
  });

  @override
  ConsumerState<SharedNoteViewer> createState() => _SharedNoteViewerState();
}

class _SharedNoteViewerState extends ConsumerState<SharedNoteViewer> {
  DecryptedSharedNote? _decryptedNote;
  bool _isDecrypting = true;
  AppException? _error;
  bool? _isServerShare;

  final _passwordController = TextEditingController();

  bool get _isPasswordProtected => widget.shareKeyFragment == null;

  @override
  void initState() {
    super.initState();
    _tryDecrypt();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  bool _detectIsServerShare(String shareId) {
    final hexPattern = RegExp(r'^[0-9a-f]{32}$');
    return hexPattern.hasMatch(shareId);
  }

  Future<void> _tryDecrypt() async {
    // Detect server share status for all paths (including password-protected).
    _isServerShare = _detectIsServerShare(widget.shareId);

    if (_isPasswordProtected) {
      setState(() => _isDecrypting = false);
      return;
    }

    setState(() {
      _isDecrypting = true;
      _error = null;
    });

    try {
      final shareService = ref.read(shareServiceProvider);

      final DecryptedSharedNote decrypted;
      if (_isServerShare!) {
        decrypted = await shareService.decryptServerSharedNote(
          shareId: widget.shareId,
          key: widget.shareKeyFragment,
        );
      } else {
        decrypted = await shareService.decryptSharedNote(
          payload: widget.shareId,
          key: widget.shareKeyFragment,
        );
      }

      if (mounted) {
        setState(() {
          _decryptedNote = decrypted;
          _isDecrypting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = const DecryptFailedException();
          _isDecrypting = false;
        });
      }
    }
  }

  Future<void> _decryptWithPassword() async {
    if (_passwordController.text.isEmpty) return;

    setState(() {
      _isDecrypting = true;
      _error = null;
    });

    try {
      final shareService = ref.read(shareServiceProvider);

      final DecryptedSharedNote decrypted;
      if (_isServerShare!) {
        decrypted = await shareService.decryptServerSharedNote(
          shareId: widget.shareId,
          password: _passwordController.text,
        );
      } else {
        decrypted = await shareService.decryptSharedNote(
          payload: widget.shareId,
          password: _passwordController.text,
        );
      }

      if (mounted) {
        setState(() {
          _decryptedNote = decrypted;
          _isDecrypting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = const IncorrectPasswordException();
          _isDecrypting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.shareNote),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: _buildBody(),
    );
  }

  String _resolveError(AppLocalizations l10n) {
    return switch (_error) {
      DecryptFailedException() => l10n.decryptFailed,
      IncorrectPasswordException() => l10n.incorrectPassword,
      _ => l10n.couldNotDecryptSharedNote,
    };
  }

  Widget _buildBody() {
    if (_isDecrypting) return _buildDecryptingState();

    if (_decryptedNote != null) return _buildDecryptedNote();

    if (_isPasswordProtected) return _buildPasswordInput();

    return _buildErrorState();
  }

  Widget _buildDecryptingState() {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.accentPeachBg,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.accentPeachText,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.decryptingSharedNote,
            style: AppTextStyles.body.copyWith(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkErrorBg : AppColors.lightErrorBg,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(
                Icons.link_off,
                size: 28,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              _resolveError(l10n),
              style: AppTextStyles.title,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              l10n.linkCorruptedExpired,
              style: AppTextStyles.caption.copyWith(
                color: isDark
                    ? AppColors.darkTextTertiary
                    : AppColors.lightTextTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordInput() {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.accentPeachBg,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(
              Icons.lock_outline,
              size: 28,
              color: AppColors.accentPeachText,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.passwordRequiredTitle,
            style: AppTextStyles.headline,
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            l10n.enterPasswordToView,
            style: AppTextStyles.caption.copyWith(
              color: isDark
                  ? AppColors.darkTextTertiary
                  : AppColors.lightTextTertiary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _passwordController,
            scrollPadding: const EdgeInsets.only(bottom: 120),
            decoration: InputDecoration(
              labelText: l10n.password,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              prefixIcon: const Icon(Icons.lock_outline),
              errorText: _error != null ? _resolveError(l10n) : null,
            ),
            obscureText: true,
            autofocus: true,
            onSubmitted: (_) => _decryptWithPassword(),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isDecrypting ? null : _decryptWithPassword,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
              child: _isDecrypting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(l10n.unlock),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDecryptedNote() {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final note = _decryptedNote!;
    final isServerShare = _isServerShare == true;
    final isLoggedIn = ref.read(authStateProvider);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.s8,
              AppSpacing.md,
              AppSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  note.title,
                  style: AppTextStyles.headline.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.s8),

                // Subtle metadata
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(100),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Text(
                      isServerShare
                          ? l10n.sharedViaLink
                          : l10n.sharedNote,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.darkTextTertiary
                            : AppColors.lightTextTertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // Warm divider
                Container(
                  height: 0.5,
                  color: isDark
                      ? AppColors.darkDivider.withAlpha(60)
                      : AppColors.lightDivider.withAlpha(80),
                ),
                const SizedBox(height: AppSpacing.md),

                // Content card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.s16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkCardBg
                        : AppColors.lightCardBg,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? AppColors.shadowDark.withAlpha(20)
                            : AppColors.shadowLight.withAlpha(30),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: MarkdownBody(
                    data: note.content,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: AppTextStyles.body.copyWith(height: 1.7),
                      h1: AppTextStyles.display.copyWith(fontSize: 24),
                      h2: AppTextStyles.headline.copyWith(fontSize: 22),
                      h3: AppTextStyles.title.copyWith(fontSize: 20),
                      code: TextStyle(
                        fontSize: 14,
                        backgroundColor: isDark
                            ? AppColors.darkInputFill
                            : AppColors.lightInputFill,
                      ),
                      blockquote: AppTextStyles.body.copyWith(
                        color: isDark
                            ? AppColors.darkTextTertiary
                            : AppColors.lightTextTertiary,
                        fontStyle: FontStyle.italic,
                      ),
                      listBullet: AppTextStyles.body.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),

                // Comments section (server shares + authenticated only)
                if (isServerShare && isLoggedIn) ...[
                  const SizedBox(height: AppSpacing.xl),
                  const Divider(),
                  const SizedBox(height: AppSpacing.s8),
                  CommentList(shareId: widget.shareId),
                ],
              ],
            ),
          ),
        ),

        // Comment input bar (server shares + authenticated only)
        if (isServerShare && isLoggedIn)
          CommentInput(shareId: widget.shareId),
      ],
    );
  }
}
