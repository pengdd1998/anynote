import 'dart:convert';

import 'package:flutter/material.dart';
import '../../../core/accessibility/a11y_utils.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../main.dart';
import '../../../core/crypto/master_key.dart';
import '../../../core/error/error.dart';
import '../../../core/network/api_client.dart';
import '../../../core/notifications/push_service.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  String? _recoveryKey;

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
      ref.read(pushNotificationServiceProvider).init();

      if (mounted) {
        _showRecoveryKeyDialog();
      }
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      final appError = ErrorMapper.map(e);
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.key),
              const SizedBox(width: 8),
              Text(l10n.saveRecoveryKey),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.recoveryKeyInstructions,
                style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  _recoveryKey ?? '',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              A11yUtils.ensureTouchTarget(
                child: IconButton(
                  icon: const Icon(Icons.copy),
                  tooltip: l10n.copyRecoveryKey,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _recoveryKey ?? ''));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.recoveryKeyCopied)),
                    );
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                context.go('/notes');
              },
              child: Text(l10n.iSavedIt),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: FocusTraversalGroup(
                policy: OrderedTraversalPolicy(),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      label: l10n.registrationScreenLabel,
                      child: Icon(
                        Icons.person_add_outlined,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.createAccount,
                      style: Theme.of(context).textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.startEncryptedJourney,
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Semantics(
                          liveRegion: true,
                          label: l10n.errorLabel(_error!),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ),
                    FocusTraversalOrder(
                      order: const NumericFocusOrder(1),
                      child: TextFormField(
                        controller: _emailController,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: l10n.email,
                          prefixIcon: const Icon(Icons.email_outlined),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) =>
                            v?.isEmpty ?? true ? l10n.emailRequired : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FocusTraversalOrder(
                      order: const NumericFocusOrder(2),
                      child: TextFormField(
                        controller: _usernameController,
                        autofillHints: const [AutofillHints.username],
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: l10n.username,
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                        validator: (v) =>
                            v?.isEmpty ?? true ? l10n.usernameRequired : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FocusTraversalOrder(
                      order: const NumericFocusOrder(3),
                      child: TextFormField(
                        controller: _passwordController,
                        autofillHints: const [AutofillHints.newPassword],
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: l10n.password,
                          prefixIcon: const Icon(Icons.lock_outline),
                        ),
                        obscureText: true,
                        validator: (v) => (v?.length ?? 0) < 8
                            ? l10n.passwordMinLength
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FocusTraversalOrder(
                      order: const NumericFocusOrder(4),
                      child: TextFormField(
                        controller: _confirmPasswordController,
                        autofillHints: const [AutofillHints.newPassword],
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: l10n.confirmPassword,
                          prefixIcon: const Icon(Icons.lock_outline),
                        ),
                        obscureText: true,
                        validator: (v) => v != _passwordController.text
                            ? l10n.passwordsDoNotMatch
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        l10n.encryptionNotice,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                    FilledButton(
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : Text(l10n.createAccount),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => context.go('/auth/login'),
                      child: Text(l10n.alreadyHaveAccount),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
