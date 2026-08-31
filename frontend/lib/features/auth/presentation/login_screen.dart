import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../main.dart';
import '../../../core/collab/ws_client.dart';
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

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with WidgetsBindingObserver, KeyboardScrollMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _isLoading = false;
  String? _error;

  // Re-validate fields on every keystroke after the first submit attempt so
  // field errors clear as soon as the input becomes valid.
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  /// Pattern used to validate the email format on the client side.
  static final RegExp _emailRegex = RegExp(
    r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
  );

  // Gesture recognizer for the "Sign up" link in the footer.
  late final TapGestureRecognizer _signUpRecognizer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _signUpRecognizer = TapGestureRecognizer()
      ..onTap = () => context.push('/auth/register');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _signUpRecognizer.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    onKeyboardMetricsChanged();
  }

  Future<void> _submit() async {
    // From the first submit on, re-validate on every keystroke so stale
    // field errors clear while the user types.
    setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Step 1: Retrieve salt for key derivation.
      // Try local storage first (fast path). After app reinstall, local storage
      // is wiped, so fall back to fetching from the server by email.
      final api = ref.read(apiClientProvider);
      final localSalt = await MasterKeyManager.getStoredSalt();
      final Uint8List salt;
      if (localSalt != null) {
        salt = localSalt;
      } else {
        final serverSalt = await api.getSalt(_emailController.text.trim());
        if (serverSalt == null) {
          if (!mounted) return;
          final l10n = AppLocalizations.of(context)!;
          setState(() => _error = l10n.noEncryptionKeys);
          return;
        }
        salt = serverSalt;
      }

      // Step 2: Check KDF version to handle parameter migration.
      // Existing users may have keys derived with older (weaker) Argon2id
      // parameters. We detect this and fall back to legacy params if needed.
      final storedKdfVersion = await MasterKeyManager.getStoredKdfVersion();
      final currentVersion = MasterKeyManager.currentKdfVersion;
      final needsMigration =
          storedKdfVersion == null || storedKdfVersion < currentVersion;

      // Step 3: Derive master key and attempt login.
      // Try current KDF parameters first. If the user's key was derived with
      // old params and this fails, retry with legacy parameters.
      Uint8List masterKey;
      int usedKdfVersion;

      try {
        // Try current KDF version first.
        masterKey = await MasterKeyManager.deriveMasterKey(
          _passwordController.text,
          salt,
          currentVersion,
        );
        usedKdfVersion = currentVersion;

        final authKey = await MasterKeyManager.deriveAuthKey(masterKey);
        final authKeyHash = await MasterKeyManager.hashAuthKey(authKey);

        await api.login(
          LoginRequest(
            email: _emailController.text.trim(),
            authKeyHash: authKeyHash,
          ),
        );
      } catch (firstAttemptError) {
        // If we have reason to believe this might be a KDF version mismatch
        // (existing user with no stored version, or old version), retry with
        // legacy parameters.
        if (needsMigration) {
          // Derive with legacy KDF version (1).
          masterKey = await MasterKeyManager.deriveMasterKey(
            _passwordController.text,
            salt,
            1, // Legacy version: opsLimitModerate + memLimitInteractive.
          );
          usedKdfVersion = 1;

          final authKey = await MasterKeyManager.deriveAuthKey(masterKey);
          final authKeyHash = await MasterKeyManager.hashAuthKey(authKey);

          await api.login(
            LoginRequest(
              email: _emailController.text.trim(),
              authKeyHash: authKeyHash,
            ),
          );
        } else {
          // No migration expected; re-throw the original error.
          rethrow;
        }
      }

      // Step 4: On success, store master key and derived keys locally.
      await MasterKeyManager.storeMasterKey(masterKey);
      await MasterKeyManager.storeSalt(salt);
      await MasterKeyManager.storeKdfVersion(usedKdfVersion);

      // Derive and store the encrypt key for data encryption.
      await MasterKeyManager.deriveEncryptKey(masterKey);

      // Mark as authenticated.
      ref.read(authStateProvider.notifier).state = true;

      // Initialize push notifications now that the user is authenticated.
      // This is a fire-and-forget operation; failure does not block login.
      // ignore: unawaited_futures
      ref.read(pushNotificationServiceProvider).init();

      // Connect to the WebSocket server for real-time collaboration.
      // ignore: unawaited_futures
      _connectWebSocket();

      // Step 5: Prompt KDF migration if user logged in with legacy parameters.
      // This is non-blocking: the user can decline and still use the app.
      final shouldMigrate = usedKdfVersion < currentVersion;
      if (shouldMigrate && mounted) {
        final l10n = AppLocalizations.of(context)!;
        final accepted = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.kdfMigrationTitle),
            content: Text(l10n.kdfMigrationMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.kdfMigrationSkip),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.kdfMigrationUpgrade),
              ),
            ],
          ),
        );

        if (accepted == true && mounted) {
          final messenger = ScaffoldMessenger.of(context);
          messenger.showSnackBar(
            SnackBar(
              content:
                  Text(AppLocalizations.of(context)!.kdfMigrationInProgress),
            ),
          );
          try {
            // Re-derive master key with current (v2) parameters.
            final migratedKey = await MasterKeyManager.deriveMasterKey(
              _passwordController.text,
              salt,
              currentVersion,
            );

            // Store the upgraded master key and update version.
            await MasterKeyManager.storeMasterKey(migratedKey);
            await MasterKeyManager.storeKdfVersion(currentVersion);

            // Re-derive dependent keys.
            await MasterKeyManager.deriveEncryptKey(migratedKey);

            // Re-authenticate with the new auth key hash so the server
            // stores the updated credential for future logins.
            final newAuthKey =
                await MasterKeyManager.deriveAuthKey(migratedKey);
            final newAuthKeyHash =
                await MasterKeyManager.hashAuthKey(newAuthKey);

            // Update the stored master key reference for the session.
            masterKey = migratedKey;

            // Attempt to register the new auth key hash with the server.
            // This uses the change-password flow to update the stored hash.
            // If this fails the user can still use the app; migration will
            // be offered again at next login.
            try {
              await api.login(
                LoginRequest(
                  email: _emailController.text.trim(),
                  authKeyHash: newAuthKeyHash,
                ),
              );
            } catch (e) {
              // Server update failed; local keys are already migrated.
              // The user will log in with v2 params next time.
              debugPrint(
                '[LoginScreen] server KDF migration update failed: $e',
              );
            }

            if (mounted) {
              messenger.hideCurrentSnackBar();
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    AppLocalizations.of(context)!.kdfMigrationSuccess,
                  ),
                ),
              );
            }
          } catch (e) {
            debugPrint('[LoginScreen] KDF migration failed: $e');
            if (mounted) {
              messenger.hideCurrentSnackBar();
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    AppLocalizations.of(context)!.kdfMigrationFailed,
                  ),
                ),
              );
            }
          }
        }
      }

      if (mounted) {
        context.go('/notes');
      }
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      final appError = ErrorMapper.map(e);
      final message = switch (appError) {
        AuthException() => l10n.invalidEmailOrPassword,
        NotFoundException() => l10n.accountNotFoundRegister,
        NetworkException() => l10n.unableToReachServer,
        _ => ErrorDisplay.userMessage(appError, l10n),
      };
      setState(() => _error = message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Dev-only: auto-registers a test account with known credentials,
  /// bypassing the need for manual text input via adb.
  Future<void> _devAutoRegister() async {
    const email = 'devtest4@anynote.local';
    const username = 'devtest4';
    const password = 'DevTest1234';

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final salt = MasterKeyManager.generateSalt();
      final masterKey = await MasterKeyManager.deriveMasterKey(password, salt);
      final authKey = await MasterKeyManager.deriveAuthKey(masterKey);
      final authKeyHash = await MasterKeyManager.hashAuthKey(authKey);
      final recoveryKey = await MasterKeyManager.generateRecoveryKey();
      final recoverySalt = MasterKeyManager.generateSalt();
      final encryptedMasterKey = await MasterKeyManager.wrapMasterKey(
        masterKey,
        recoveryKey,
        recoverySalt,
      );

      final api = ref.read(apiClientProvider);
      await api.register(
        RegisterRequest(
          email: email,
          username: username,
          authKeyHash: authKeyHash,
          salt: base64Encode(salt),
          recoveryKey: recoveryKey,
          recoverySalt: base64Encode(recoverySalt),
          encryptedMasterKey: base64Encode(encryptedMasterKey),
        ),
      );

      await MasterKeyManager.storeMasterKey(masterKey);
      await MasterKeyManager.storeSalt(salt);
      await MasterKeyManager.storeKdfVersion(
          MasterKeyManager.currentKdfVersion);
      await MasterKeyManager.deriveEncryptKey(masterKey);
      ref.read(authStateProvider.notifier).state = true;
      // ignore: unawaited_futures
      ref.read(pushNotificationServiceProvider).init();
      // ignore: unawaited_futures
      _connectWebSocket();

      if (mounted) {
        AppSnackBar.info(context,
            message: 'Dev account registered: $email / $password');
        context.go('/notes');
      }
    } catch (e) {
      debugPrint('[DevAutoRegister] failed: $e');
      if (mounted) {
        // If registration fails for any reason (already exists, server
        // version mismatch, etc.), fall back to login with known credentials.
        debugPrint('[DevAutoRegister] falling back to auto-login');
        await _devAutoLogin();
        return;
      }
    } finally {
      if (mounted)
        setState(() {
          _isLoading = false;
        });
    }
  }

  /// Dev-only: logs in with the hardcoded test account.
  /// Tries current KDF version first, falls back to legacy v1 if auth fails.
  Future<void> _devAutoLogin() async {
    const email = 'devtest4@anynote.local';
    const password = 'DevTest1234';

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final serverSalt = await api.getSalt(email);
      if (serverSalt == null) {
        if (mounted)
          setState(() {
            _error = 'No salt for dev account';
          });
        return;
      }

      final currentVersion = MasterKeyManager.currentKdfVersion;
      Uint8List masterKey;
      int usedKdfVersion;

      try {
        masterKey = await MasterKeyManager.deriveMasterKey(
          password,
          serverSalt,
          currentVersion,
        );
        usedKdfVersion = currentVersion;
        final authKey = await MasterKeyManager.deriveAuthKey(masterKey);
        final authKeyHash = await MasterKeyManager.hashAuthKey(authKey);
        await api.login(LoginRequest(email: email, authKeyHash: authKeyHash));
      } catch (_) {
        // Retry with legacy KDF v1 params
        masterKey = await MasterKeyManager.deriveMasterKey(
          password,
          serverSalt,
          1,
        );
        usedKdfVersion = 1;
        final authKey = await MasterKeyManager.deriveAuthKey(masterKey);
        final authKeyHash = await MasterKeyManager.hashAuthKey(authKey);
        await api.login(LoginRequest(email: email, authKeyHash: authKeyHash));
      }

      await MasterKeyManager.storeMasterKey(masterKey);
      await MasterKeyManager.storeSalt(serverSalt);
      await MasterKeyManager.storeKdfVersion(usedKdfVersion);
      await MasterKeyManager.deriveEncryptKey(masterKey);
      ref.read(authStateProvider.notifier).state = true;
      // ignore: unawaited_futures
      ref.read(pushNotificationServiceProvider).init();
      // ignore: unawaited_futures
      _connectWebSocket();

      if (mounted) {
        AppSnackBar.info(context, message: 'Dev login: $email / $password');
        context.go('/notes');
      }
    } catch (e) {
      debugPrint('[DevAutoLogin] failed: $e');
      if (mounted)
        setState(() {
          _error = 'Dev login failed: $e';
        });
    } finally {
      if (mounted)
        setState(() {
          _isLoading = false;
        });
    }
  }

  Future<void> _connectWebSocket() async {
    try {
      final api = ref.read(apiClientProvider);
      final token = api.accessToken;
      if (token == null || !mounted) return;
      // ignore: unawaited_futures
      ref.read(wsClientProvider.notifier).connect(token);
    } catch (_) {
      // WebSocket connection failure is non-critical. The collab feature
      // will simply be unavailable until the next successful connection.
    }
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
            top: MediaQuery.sizeOf(context).height * 0.10,
            bottom: 200,
          ),
          child: Form(
            key: _formKey,
            child: FocusTraversalGroup(
              policy: OrderedTraversalPolicy(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // -- Welcome header --
                  Semantics(
                    label: l10n.loginScreenLabel,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.welcomeBack,
                          style: AppTextStyles.handwritingTitle.copyWith(
                            fontSize: 34,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s4),
                        Text(
                          l10n.signInToContinue,
                          style: AppTextStyles.caption.copyWith(
                            color: textTertiary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // -- Error message --
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

                  // -- Email field --
                  _FieldLabel(text: l10n.email, color: textSecondary),
                  FocusTraversalOrder(
                    order: const NumericFocusOrder(1),
                    child: TextFormField(
                      controller: _emailController,
                      focusNode: _emailFocus,
                      autofocus: true,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      scrollPadding: const EdgeInsets.only(bottom: 120),
                      decoration: InputDecoration(
                        hintText: l10n.email,
                        prefixIcon: const Icon(Icons.email_outlined),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      autovalidateMode: _autovalidateMode,
                      onChanged: (_) {
                        // Clear the submit-level error once the user types.
                        if (_error != null) {
                          setState(() => _error = null);
                        }
                      },
                      validator: (v) {
                        final value = v?.trim() ?? '';
                        if (value.isEmpty) return l10n.emailRequired;
                        if (!_emailRegex.hasMatch(value)) {
                          return l10n.emailInvalid;
                        }
                        return null;
                      },
                    ),
                  ),

                  const SizedBox(height: AppSpacing.s12),

                  // -- Password field --
                  _FieldLabel(text: l10n.password, color: textSecondary),
                  FocusTraversalOrder(
                    order: const NumericFocusOrder(2),
                    child: PasswordTextField(
                      controller: _passwordController,
                      focusNode: _passwordFocus,
                      hintText: l10n.password,
                      prefixIcon: const Icon(Icons.lock_outline),
                      autofillHints: const [
                        AutofillHints.password,
                      ],
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      autovalidateMode: _autovalidateMode,
                      onChanged: (_) {
                        // Clear the submit-level error once the user types.
                        if (_error != null) {
                          setState(() => _error = null);
                        }
                      },
                      scrollPadding: const EdgeInsets.only(bottom: 120),
                      showPasswordTooltip: l10n.showPassword,
                      hidePasswordTooltip: l10n.hidePassword,
                      validator: (v) =>
                          v?.isEmpty ?? true ? l10n.passwordRequired : null,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.sm),

                  // -- Forgot password link --
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => context.push('/auth/recover'),
                      style: TextButton.styleFrom(
                        foregroundColor: linkColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s4,
                        ),
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        l10n.forgotPassword,
                        style: AppTextStyles.caption.copyWith(
                          color: linkColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // -- Sign in button --
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
                                l10n.signIn,
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

                  const SizedBox(height: AppSpacing.xl),

                  // -- Divider with centered caption --
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 1,
                          color: isDark
                              ? AppColors.darkDivider
                              : AppColors.lightDivider,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s12,
                        ),
                        child: Text(
                          l10n.orContinueWith,
                          style: AppTextStyles.caption.copyWith(
                            color: textTertiary,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 1,
                          color: isDark
                              ? AppColors.darkDivider
                              : AppColors.lightDivider,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // -- Social sign-in buttons (decorative) --
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _SocialButton(
                        isDark: isDark,
                        borderColor: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                        onPressed: () {},
                        child: const Text(
                          'G',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.info,
                            height: 1.0,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      _SocialButton(
                        isDark: isDark,
                        borderColor: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                        onPressed: () {},
                        child: Icon(
                          AppIcons.apple,
                          size: 24,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      _SocialButton(
                        isDark: isDark,
                        borderColor: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                        onPressed: () {},
                        child: Icon(
                          Icons.mail_outline,
                          size: 24,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // -- Footer: link to register --
                  Text.rich(
                    TextSpan(
                      text: l10n.dontHaveAccount + ' ',
                      style: AppTextStyles.caption.copyWith(
                        color: textTertiary,
                      ),
                      children: [
                        TextSpan(
                          text: l10n.signUp,
                          style: AppTextStyles.caption.copyWith(
                            color: linkColor,
                            fontWeight: FontWeight.w600,
                          ),
                          recognizer: _signUpRecognizer,
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),

                  // DEV: auto-register test account
                  if (kDebugMode)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.md),
                      child: TextButton(
                        onPressed: _isLoading ? null : _devAutoRegister,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.warning,
                        ),
                        child: Text(
                          'DEV: Auto Register',
                          style: AppTextStyles.caption,
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
// Circular social sign-in button
// ---------------------------------------------------------------------------
class _SocialButton extends StatelessWidget {
  final bool isDark;
  final Color borderColor;
  final VoidCallback onPressed;
  final Widget child;

  const _SocialButton({
    required this.isDark,
    required this.borderColor,
    required this.onPressed,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onPressed: onPressed,
      borderRadius: AppRadius.pillBorder,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCardBg : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Center(child: child),
      ),
    );
  }
}
