import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../main.dart';
import '../../../core/crypto/master_key.dart';
import '../../../core/error/error.dart';
import '../../../core/network/api_client.dart';
import '../../../core/notifications/push_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/keyboard_scroll_mixin.dart';
import '../../../core/widgets/password_text_field.dart';
import '../../../core/widgets/pressable_scale.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with WidgetsBindingObserver, KeyboardScrollMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();
  bool _isLoading = false;
  String? _error;
  String? _recoveryKey;

  // Gesture recognizer for the "Log in" link in the footer.
  late final TapGestureRecognizer _loginRecognizer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loginRecognizer = TapGestureRecognizer()
      ..onTap = () => context.push('/auth/login');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailFocus.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    _loginRecognizer.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    onKeyboardMetricsChanged();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final password = _passwordController.text;

      // Step 1: Generate a new 32-byte salt for Argon2id.
      final salt = MasterKeyManager.generateSalt();

      // Step 2: Derive master key from password via Argon2id.
      final masterKey = await MasterKeyManager.deriveMasterKey(password, salt);

      // Step 3: Derive auth key from master key via BLAKE2b.
      final authKey = await MasterKeyManager.deriveAuthKey(masterKey);

      // Step 4: Hash auth key for server-side verification.
      final authKeyHash = await MasterKeyManager.hashAuthKey(authKey);

      // Step 5: Generate BIP-39 recovery key (12-word mnemonic).
      _recoveryKey = await MasterKeyManager.generateRecoveryKey();

      // Step 5b: Generate a random 32-byte recovery salt for non-deterministic
      // key derivation during account recovery.
      final recoverySalt = MasterKeyManager.generateSalt();

      // Step 5c: Encrypt the master key with the recovery-derived key so
      // the master key can be recovered from the mnemonic alone.
      final encryptedMasterKey = await MasterKeyManager.wrapMasterKey(
        masterKey,
        _recoveryKey!,
        recoverySalt,
      );

      // Step 6: Send registration request to server.
      final api = ref.read(apiClientProvider);
      await api.register(
        RegisterRequest(
          email: _emailController.text.trim(),
          username: _usernameController.text.trim(),
          authKeyHash: authKeyHash,
          salt: base64Encode(salt),
          recoveryKey: _recoveryKey!,
          recoverySalt: base64Encode(recoverySalt),
          encryptedMasterKey: base64Encode(encryptedMasterKey),
        ),
      );

      // Step 7: On success, store keys locally.
      await MasterKeyManager.storeMasterKey(masterKey);
      await MasterKeyManager.storeSalt(salt);
      await MasterKeyManager.storeKdfVersion(
        MasterKeyManager.currentKdfVersion,
      );

      // Derive and store the encrypt key for data encryption.
      await MasterKeyManager.deriveEncryptKey(masterKey);

      // Mark as authenticated.
      ref.read(authStateProvider.notifier).state = true;

      // Initialize push notifications for the new account.
      // ignore: unawaited_futures
      ref.read(pushNotificationServiceProvider).init();

      if (mounted) {
        _showRecoveryKeyDialog();
      }
    } catch (e, stackTrace) {
      debugPrint('[Register] error: $e');
      debugPrint('[Register] stackTrace: $stackTrace');
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      final appError = ErrorMapper.map(e);
      debugPrint(
          '[Register] mapped error: ${appError.runtimeType}: ${appError.message}');
      final message = switch (appError) {
        ConflictException() => l10n.emailOrUsernameTaken,
        ValidationException() => l10n.invalidInput,
        NetworkException() => l10n.unableToReachServer,
        CryptoKeyDerivationException() => l10n.keyDerivationFailed,
        _ => ErrorDisplay.userMessage(appError, l10n),
      };
      setState(() => _error = message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showRecoveryKeyDialog() {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // -- Key icon --
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.accentYellow.withValues(alpha: 0.15)
                        : AppColors.accentYellowBg,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Icon(
                    Icons.key_rounded,
                    size: 32,
                    color: AppColors.accentYellowText,
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // -- Title --
                Text(
                  l10n.saveRecoveryKey,
                  style: AppTextStyles.headline.copyWith(
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: AppSpacing.sm),

                // -- Explanation --
                Text(
                  l10n.recoveryKeyInstructions,
                  style: AppTextStyles.body.copyWith(
                    color: isDark
                        ? AppColors.darkTextTertiary
                        : AppColors.lightTextTertiary,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: AppSpacing.lg),

                // -- Recovery key preview box (sticky-note style) --
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.accentYellow.withValues(alpha: 0.08)
                        : AppColors.accentYellowBg,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                      color: AppColors.accentYellow.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        _recoveryKey ?? '',
                        style: AppTextStyles.mono.copyWith(
                          fontSize: 14,
                          height: 1.8,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      // Copy chip aligned to the bottom-right of the box.
                      Align(
                        alignment: Alignment.centerRight,
                        child: _CopyButton(
                          l10n: l10n,
                          recoveryKey: _recoveryKey,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                // -- Continue button --
                SizedBox(
                  width: double.infinity,
                  child: PressableScale(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      context.go('/notes');
                    },
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Container(
                      height: 54,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.25),
                            offset: const Offset(0, 4),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          l10n.iSavedIt,
                          style: AppTextStyles.body.copyWith(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textTertiary =
        isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final linkColor = isDark ? AppColors.secondary : AppColors.primaryText;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: AppSpacing.xl,
            right: AppSpacing.xl,
            top: MediaQuery.sizeOf(context).height * 0.08,
            bottom: 200,
          ),
          child: Form(
            key: _formKey,
            child: FocusTraversalGroup(
              policy: OrderedTraversalPolicy(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // -- Header --
                  Semantics(
                    label: l10n.registrationScreenLabel,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.createYourAccount,
                          style: AppTextStyles.handwritingTitle.copyWith(
                            fontSize: 34,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s4),
                        Text(
                          l10n.registerSubtitle,
                          style: AppTextStyles.caption.copyWith(
                            color: textTertiary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // -- Error --
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Semantics(
                        liveRegion: true,
                        label: l10n.errorLabel(_error!),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.s12,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkErrorBg
                                : AppColors.lightErrorBg,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.darkErrorBorder
                                  : AppColors.lightErrorBorder,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 18,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: AppTextStyles.body.copyWith(
                                    color: Theme.of(context).colorScheme.error,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // -- Email --
                  _FieldLabel(text: l10n.email, color: textSecondary),
                  FocusTraversalOrder(
                    order: const NumericFocusOrder(1),
                    child: TextFormField(
                      controller: _emailController,
                      focusNode: _emailFocus,
                      autofocus: true,
                      autofillHints: const [
                        AutofillHints.email,
                      ],
                      textInputAction: TextInputAction.next,
                      scrollPadding: const EdgeInsets.only(bottom: 120),
                      decoration: InputDecoration(
                        hintText: l10n.email,
                        prefixIcon: const Icon(Icons.email_outlined),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) =>
                          v?.isEmpty ?? true ? l10n.emailRequired : null,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.s12),

                  // -- Username --
                  _FieldLabel(text: l10n.username, color: textSecondary),
                  FocusTraversalOrder(
                    order: const NumericFocusOrder(2),
                    child: TextFormField(
                      controller: _usernameController,
                      focusNode: _usernameFocus,
                      autofillHints: const [
                        AutofillHints.username,
                      ],
                      textInputAction: TextInputAction.next,
                      scrollPadding: const EdgeInsets.only(bottom: 120),
                      decoration: InputDecoration(
                        hintText: l10n.username,
                        prefixIcon: const Icon(
                          Icons.person_outline,
                        ),
                      ),
                      validator: (v) =>
                          v?.isEmpty ?? true ? l10n.usernameRequired : null,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.s12),

                  // -- Password --
                  _FieldLabel(text: l10n.password, color: textSecondary),
                  FocusTraversalOrder(
                    order: const NumericFocusOrder(3),
                    child: PasswordTextField(
                      controller: _passwordController,
                      focusNode: _passwordFocus,
                      hintText: l10n.password,
                      prefixIcon: const Icon(Icons.lock_outline),
                      autofillHints: const [
                        AutofillHints.newPassword,
                      ],
                      textInputAction: TextInputAction.next,
                      scrollPadding: const EdgeInsets.only(bottom: 120),
                      showPasswordTooltip: l10n.showPassword,
                      hidePasswordTooltip: l10n.hidePassword,
                      validator: (v) =>
                          (v?.length ?? 0) < 8 ? l10n.passwordMinLength : null,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.s12),

                  // -- Confirm password --
                  _FieldLabel(
                    text: l10n.confirmPassword,
                    color: textSecondary,
                  ),
                  FocusTraversalOrder(
                    order: const NumericFocusOrder(4),
                    child: PasswordTextField(
                      controller: _confirmPasswordController,
                      focusNode: _confirmPasswordFocus,
                      hintText: l10n.confirmPassword,
                      prefixIcon: const Icon(Icons.lock_outline),
                      autofillHints: const [
                        AutofillHints.newPassword,
                      ],
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      scrollPadding: const EdgeInsets.only(bottom: 120),
                      showPasswordTooltip: l10n.showPassword,
                      hidePasswordTooltip: l10n.hidePassword,
                      validator: (v) => v != _passwordController.text
                          ? l10n.passwordsDoNotMatch
                          : null,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // -- Recovery key section --
                  Text(
                    l10n.yourRecoveryKey,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    l10n.recoveryKeyHelp,
                    style: AppTextStyles.caption.copyWith(
                      color: textTertiary,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // -- Encryption notice --
                  Row(
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 14,
                        color: textTertiary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          l10n.encryptionNotice,
                          style: AppTextStyles.caption.copyWith(
                            color: textTertiary,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // -- Submit button --
                  PressableScale(
                    onPressed: _isLoading ? null : _submit,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Container(
                      height: 54,
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.25),
                            offset: const Offset(0, 4),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: Center(
                        child: _isLoading
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                ),
                              )
                            : Text(
                                l10n.createAccount,
                                style: AppTextStyles.body.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // -- Footer: link to login --
                  Text.rich(
                    TextSpan(
                      text: '${l10n.alreadyHaveAccountQuestion} ',
                      style: AppTextStyles.caption.copyWith(
                        color: textTertiary,
                      ),
                      children: [
                        TextSpan(
                          text: l10n.signIn,
                          style: AppTextStyles.caption.copyWith(
                            color: linkColor,
                            fontWeight: FontWeight.w600,
                          ),
                          recognizer: _loginRecognizer,
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small w600 field label shown above inputs
// ---------------------------------------------------------------------------
class _FieldLabel extends StatelessWidget {
  final String text;
  final Color color;

  const _FieldLabel({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s4),
      child: Text(
        text,
        style: AppTextStyles.caption.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Copy chip for the recovery key preview box
// ---------------------------------------------------------------------------
class _CopyButton extends StatefulWidget {
  final AppLocalizations l10n;
  final String? recoveryKey;

  const _CopyButton({
    required this.l10n,
    required this.recoveryKey,
  });

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PressableScale(
      onPressed: () {
        Clipboard.setData(
          ClipboardData(text: widget.recoveryKey ?? ''),
        );
        AppSnackBar.info(
          context,
          message: widget.l10n.recoveryKeyCopied,
        );
        setState(() => _copied = true);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _copied = false);
        });
      },
      borderRadius: AppRadius.pillBorder,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s12,
          vertical: AppSpacing.s4,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCardBg : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.primarySoftBorder,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _copied ? Icons.check : AppIcons.copy,
              size: 14,
              color: AppColors.primaryText,
            ),
            const SizedBox(width: AppSpacing.s4),
            Text(
              _copied
                  ? widget.l10n.recoveryKeyCopied
                  : widget.l10n.copyRecoveryKey,
              style: AppTextStyles.caption.copyWith(
                fontSize: 12,
                color: AppColors.primaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
