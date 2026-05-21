import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../main.dart';
import '../../../core/crypto/crypto_service.dart';
import '../../../core/crypto/key_storage.dart';
import '../../../core/crypto/master_key.dart';
import '../../../core/error/error.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/pressable_scale.dart';

class RecoveryScreen extends ConsumerStatefulWidget {
  const RecoveryScreen({super.key});

  @override
  ConsumerState<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends ConsumerState<RecoveryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _wordControllers = List.generate(12, (_) => TextEditingController());
  final _wordFocusNodes = List.generate(12, (_) => FocusNode());
  bool _isLoading = false;
  String? _error;

  int get _filledCount =>
      _wordControllers.where((c) => c.text.trim().isNotEmpty).length;

  @override
  void dispose() {
    _emailController.dispose();
    for (final c in _wordControllers) {
      c.dispose();
    }
    for (final f in _wordFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String _buildMnemonic() {
    return _wordControllers.map((c) => c.text.trim().toLowerCase()).join(' ');
  }

  Future<void> _submit() async {
    // Inline validation for the mnemonic words.
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = null); // form validator handles email
      _formKey.currentState?.validate();
      return;
    }

    final allFilled = _wordControllers.every((c) => c.text.trim().isNotEmpty);
    if (!allFilled) {
      final l10n = AppLocalizations.of(context)!;
      setState(() => _error = l10n.recoveryKeyRequired);
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final mnemonic = _buildMnemonic();

      // Step 1: Fetch per-user recovery salt from the server.
      final api = ref.read(apiClientProvider);
      Uint8List? serverSalt;
      try {
        serverSalt = await api.getRecoverySalt(email);
      } catch (e) {
        debugPrint('[RecoveryScreen] failed to fetch recovery salt: $e');
      }

      // Step 2: Recover master key from BIP-39 mnemonic.
      final masterKey =
          await MasterKeyManager.recoverMasterKeyFromMnemonic(
        mnemonic,
        serverSalt,
      );

      // Step 3: Derive auth key from the master key.
      final authKey = await MasterKeyManager.deriveAuthKey(masterKey);

      // Step 4: Hash the auth key for server verification.
      final authKeyHash = await MasterKeyManager.hashAuthKey(authKey);

      // Step 5: Login with the auth key hash.
      await api.login(
        LoginRequest(
          email: email,
          authKeyHash: authKeyHash,
        ),
      );

      // Step 6: Store the master key and derived keys locally.
      await MasterKeyManager.storeMasterKey(masterKey);

      final encryptKey = await MasterKeyManager.deriveEncryptKey(masterKey);
      await KeyStorage.saveEncryptKey(encryptKey);

      // Step 7: Unlock CryptoService.
      final crypto = ref.read(cryptoServiceProvider);
      await crypto.unlock();

      // Step 8: Mark as authenticated and navigate.
      ref.read(authStateProvider.notifier).state = true;

      if (mounted) {
        context.go('/notes');
      }
    } on ArgumentError catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() => _error = e.message ?? l10n.invalidRecoveryKey);
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      final appError = ErrorMapper.map(e);
      final message = switch (appError) {
        AuthException() => l10n.invalidRecoveryKeyForAccount,
        NotFoundException() => l10n.accountNotFoundCheckEmail,
        NetworkException() => l10n.unableToReachServer,
        _ => ErrorDisplay.userMessage(appError, l10n),
      };
      setState(() => _error = message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null) return;

    final words = data!.text!.trim().split(RegExp(r'\s+'));
    for (int i = 0; i < 12 && i < words.length; i++) {
      _wordControllers[i].text = words[i];
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final filled = _filledCount;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Form(
                    key: _formKey,
                    child: FocusTraversalGroup(
                      policy: OrderedTraversalPolicy(),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // -- Illustration --
                          Center(
                            child: Semantics(
                              label: l10n.recoverAccount,
                              child: Container(
                                width: 88,
                                height: 88,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.accentPeach
                                          .withValues(alpha: 0.12)
                                      : AppColors.accentPeachBg,
                                  borderRadius: BorderRadius.circular(
                                      AppRadius.lg,),
                                ),
                                child: const Icon(
                                  Icons.key_outlined,
                                  size: 40,
                                  color: AppColors.accentPeachText,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: AppSpacing.xl),

                          // -- Headline --
                          Text(
                            l10n.recoverAccount,
                            style: AppTextStyles.display.copyWith(
                              fontSize: 30,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: AppSpacing.sm),

                          Text(
                            l10n.recoverAccountInstructions,
                            style: AppTextStyles.body.copyWith(
                              color: isDark
                                  ? AppColors.darkTextTertiary
                                  : AppColors.lightTextTertiary,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: AppSpacing.xl),

                          // -- Error --
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(
                                  bottom: AppSpacing.md,),
                              child: Semantics(
                                liveRegion: true,
                                label: l10n.errorLabel(_error!),
                                child: Text(
                                  _error!,
                                  style: AppTextStyles.body.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .error,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),

                          // -- Email --
                          FocusTraversalOrder(
                            order: const NumericFocusOrder(0),
                            child: TextFormField(
                              controller: _emailController,
                              autofillHints: const [
                                AutofillHints.email,
                              ],
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                hintText: l10n.email,
                                prefixIcon:
                                    const Icon(Icons.email_outlined),
                              ),
                              keyboardType:
                                  TextInputType.emailAddress,
                              validator: (v) => v?.isEmpty ?? true
                                  ? l10n.emailRequired
                                  : null,
                            ),
                          ),

                          const SizedBox(height: AppSpacing.xl),

                          // -- Word grid header --
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  l10n.recoveryKeyLabel,
                                  style: AppTextStyles.title.copyWith(
                                    fontSize: 15,
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors
                                            .lightTextSecondary,
                                  ),
                                ),
                              ),
                              _ProgressBadge(
                                filled: filled,
                                total: 12,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              _PasteChip(
                                onTap: _pasteFromClipboard,
                                label: l10n.pasteFromClipboard,
                              ),
                            ],
                          ),

                          const SizedBox(height: AppSpacing.s12),

                          // -- Word grid (2 columns x 6 rows) --
                          ...List.generate(6, (row) {
                            return Padding(
                              padding: EdgeInsets.only(
                                bottom: row < 5
                                    ? AppSpacing.s4
                                    : 0,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _WordChip(
                                      index: row * 2,
                                      controller:
                                          _wordControllers[row * 2],
                                      focusNode:
                                          _wordFocusNodes[row * 2],
                                      nextFocusNode:
                                          _wordFocusNodes[row * 2 + 1],
                                      onFilled: _submit,
                                    ),
                                  ),
                                  const SizedBox(
                                      width: AppSpacing.s4,),
                                  Expanded(
                                    child: _WordChip(
                                      index: row * 2 + 1,
                                      controller: _wordControllers[
                                          row * 2 + 1],
                                      focusNode: _wordFocusNodes[
                                          row * 2 + 1],
                                      nextFocusNode: row < 5
                                          ? _wordFocusNodes[
                                              (row + 1) * 2]
                                          : null,
                                      onFilled: _submit,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),

                          const SizedBox(height: AppSpacing.s12),

                          // -- Format hint --
                          Text(
                            l10n.recoveryKeyFormatHint,
                            style: AppTextStyles.caption.copyWith(
                              color: isDark
                                  ? AppColors.darkTextTertiary
                                  : AppColors.lightTextTertiary,
                            ),
                          ),

                          const SizedBox(height: AppSpacing.xl),

                          // -- Submit button --
                          PressableScale(
                            onPressed: _isLoading ? null : _submit,
                            borderRadius: BorderRadius.circular(
                                AppRadius.pill,),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 16,),
                              decoration: BoxDecoration(
                                color: primaryColor,
                                borderRadius: BorderRadius.circular(
                                    AppRadius.pill,),
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryColor
                                        .withValues(alpha: 0.25),
                                    offset: const Offset(0, 4),
                                    blurRadius: 16,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child:
                                            CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        l10n.recoverAccount,
                                        style: AppTextStyles.body
                                            .copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                      ),
                              ),
                            ),
                          ),

                          const SizedBox(height: AppSpacing.lg),

                          // -- Back to login --
                          TextButton(
                            onPressed: () =>
                                context.push('/auth/login'),
                            style: TextButton.styleFrom(
                              foregroundColor: primaryColor,
                            ),
                            child: Text(
                              l10n.backToSignIn,
                              style: AppTextStyles.body.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Single word input chip
// ---------------------------------------------------------------------------
class _WordChip extends StatelessWidget {
  final int index;
  final TextEditingController controller;
  final FocusNode focusNode;
  final FocusNode? nextFocusNode;
  final VoidCallback onFilled;

  const _WordChip({
    required this.index,
    required this.controller,
    required this.focusNode,
    required this.nextFocusNode,
    required this.onFilled,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasText = controller.text.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: hasText
            ? (isDark
                ? AppColors.accentLavender.withValues(alpha: 0.1)
                : AppColors.accentLavenderBg)
            : (isDark
                ? AppColors.darkInputFill
                : AppColors.lightInputFill),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: hasText
            ? Border.all(
                color: AppColors.accentLavender.withValues(alpha: 0.3),
                width: 1,
              )
            : null,
      ),
      child: Row(
        children: [
          // Word number badge
          Container(
            width: 28,
            alignment: Alignment.center,
            child: Text(
              '${index + 1}',
              style: AppTextStyles.caption.copyWith(
                color: hasText
                    ? AppColors.accentLavenderText
                    : (isDark
                        ? AppColors.darkTextTertiary
                        : AppColors.lightTextTertiary),
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ),
          // Input field
          Expanded(
            child: TextFormField(
              controller: controller,
              focusNode: focusNode,
              style: AppTextStyles.body.copyWith(
                fontSize: 14,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.only(
                  right: AppSpacing.sm,
                  top: 12,
                  bottom: 12,
                ),
                hintText: '· · ·',
                hintStyle: TextStyle(
                  color: (isDark
                          ? AppColors.darkTextTertiary
                          : AppColors.lightTextTertiary)
                      .withValues(alpha: 0.4),
                  letterSpacing: 2,
                ),
              ),
              textInputAction: nextFocusNode != null
                  ? TextInputAction.next
                  : TextInputAction.done,
              onChanged: (_) {
                // Trigger rebuild so the chip animates its fill state.
                (context as Element).markNeedsBuild();
              },
              onFieldSubmitted: (_) {
                if (nextFocusNode != null) {
                  nextFocusNode!.requestFocus();
                } else {
                  onFilled();
                }
              },
              autocorrect: false,
              enableSuggestions: false,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Progress badge (e.g. "7 / 12")
// ---------------------------------------------------------------------------
class _ProgressBadge extends StatelessWidget {
  final int filled;
  final int total;

  const _ProgressBadge({
    required this.filled,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isComplete = filled == total;

    final color = isComplete
        ? AppColors.accentMintText
        : (isDark
            ? AppColors.darkTextTertiary
            : AppColors.lightTextTertiary);

    final bg = isComplete
        ? (isDark
            ? AppColors.accentMint.withValues(alpha: 0.15)
            : AppColors.accentMintBg)
        : Colors.transparent;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        '$filled / $total',
        style: AppTextStyles.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Paste chip button
// ---------------------------------------------------------------------------
class _PasteChip extends StatelessWidget {
  final VoidCallback onTap;
  final String label;

  const _PasteChip({
    required this.onTap,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .primary
              .withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.content_paste_rounded,
              size: 13,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
