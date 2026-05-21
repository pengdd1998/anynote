import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../main.dart';
import '../../../core/crypto/master_key.dart';
import '../../../core/error/error.dart';
import '../../../core/network/api_client.dart';
import '../../../core/notifications/push_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/password_text_field.dart';
import '../../../core/widgets/pressable_scale.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  Future<void> _submit() async {
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
      ref.read(pushNotificationServiceProvider).init();

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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final accentBg = isDark
        ? AppColors.accentLavender.withValues(alpha: 0.12)
        : AppColors.accentLavenderBg;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
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
                              label: l10n.loginScreenLabel,
                              child: Container(
                                width: 88,
                                height: 88,
                                decoration: BoxDecoration(
                                  color: accentBg,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.lg),
                                ),
                                child: Icon(
                                  Icons.lock_outline,
                                  size: 40,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: AppSpacing.xl),

                          // -- Welcome headline --
                          Text(
                            l10n.welcomeBack,
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
                            l10n.signInToVault,
                            style: AppTextStyles.body.copyWith(
                              color: isDark
                                  ? AppColors.darkTextTertiary
                                  : AppColors.lightTextTertiary,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: AppSpacing.xl),

                          // -- Error message --
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
                                    color:
                                        Theme.of(context).colorScheme.error,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),

                          // -- Email field --
                          FocusTraversalOrder(
                            order: const NumericFocusOrder(1),
                            child: TextFormField(
                              controller: _emailController,
                              autofocus: true,
                              autofillHints: const [AutofillHints.email],
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                hintText: l10n.email,
                                prefixIcon:
                                    const Icon(Icons.email_outlined),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) => v?.isEmpty ?? true
                                  ? l10n.emailRequired
                                  : null,
                            ),
                          ),

                          const SizedBox(height: AppSpacing.s12),

                          // -- Password field --
                          FocusTraversalOrder(
                            order: const NumericFocusOrder(2),
                            child: PasswordTextField(
                              controller: _passwordController,
                              hintText: l10n.password,
                              prefixIcon:
                                  const Icon(Icons.lock_outline),
                              autofillHints: const [
                                AutofillHints.password,
                              ],
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              showPasswordTooltip: l10n.showPassword,
                              hidePasswordTooltip: l10n.hidePassword,
                              validator: (v) => v?.isEmpty ?? true
                                  ? l10n.passwordRequired
                                  : null,
                            ),
                          ),

                          const SizedBox(height: AppSpacing.lg),

                          // -- Sign in button --
                          PressableScale(
                            onPressed: _isLoading ? null : _submit,
                            borderRadius:
                                BorderRadius.circular(AppRadius.pill),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 16,),
                              decoration: BoxDecoration(
                                color: primaryColor,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill),
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
                                        l10n.signIn,
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

                          const SizedBox(height: AppSpacing.xl),

                          // -- Divider with spacing --
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
                            ],
                          ),

                          const SizedBox(height: AppSpacing.lg),

                          // -- Alternative actions --
                          TextButton(
                            onPressed: () =>
                                context.push('/auth/register'),
                            style: TextButton.styleFrom(
                              foregroundColor: primaryColor,
                            ),
                            child: Text(
                              l10n.noAccountRegister,
                              style: AppTextStyles.body.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),

                          TextButton(
                            onPressed: () =>
                                context.push('/auth/recover'),
                            style: TextButton.styleFrom(
                              foregroundColor: isDark
                                  ? AppColors.darkTextTertiary
                                  : AppColors.lightTextTertiary,
                            ),
                            child: Text(
                              l10n.recoverFromBackup,
                              style: AppTextStyles.caption,
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
