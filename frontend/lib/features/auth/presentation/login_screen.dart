import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../main.dart';
import '../../../core/crypto/master_key.dart';
import '../../../core/error/error.dart';
import '../../../core/network/api_client.dart';
import '../../../core/notifications/push_service.dart';

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
      // Step 1: Retrieve stored salt (set during registration).
      final salt = await MasterKeyManager.getStoredSalt();
      if (salt == null) {
        if (!mounted) return;
        final l10n = AppLocalizations.of(context)!;
        setState(() => _error = l10n.noEncryptionKeys);
        return;
      }

      // Step 2: Derive master key from password via Argon2id.
      final masterKey = await MasterKeyManager.deriveMasterKey(
        _passwordController.text,
        salt,
      );

      // Step 3: Derive auth key from master key via BLAKE2b.
      final authKey = await MasterKeyManager.deriveAuthKey(masterKey);

      // Step 4: Hash auth key for server verification.
      final authKeyHash = await MasterKeyManager.hashAuthKey(authKey);

      // Step 5: Send hashed auth key to server.
      final api = ref.read(apiClientProvider);
      await api.login(LoginRequest(
        email: _emailController.text.trim(),
        authKeyHash: authKeyHash,
      ),);

      // Step 6: On success, store master key and derived keys locally.
      await MasterKeyManager.storeMasterKey(masterKey);
      await MasterKeyManager.storeSalt(salt);

      // Derive and store the encrypt key for data encryption.
      await MasterKeyManager.deriveEncryptKey(masterKey);

      // Mark as authenticated.
      ref.read(authStateProvider.notifier).state = true;

      // Initialize push notifications now that the user is authenticated.
      // This is a fire-and-forget operation; failure does not block login.
      ref.read(pushNotificationServiceProvider).init();

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
        _ => ErrorDisplay.userMessage(appError),
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
                    label: 'AnyNote login screen',
                    child: Icon(Icons.lock_outline, size: 64, color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(height: 16),
                  Text(l10n.welcomeBack, style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(l10n.signInToVault, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
                  const SizedBox(height: 32),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Semantics(
                        liveRegion: true,
                        label: 'Error: $_error',
                        child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      ),
                    ),
                  FocusTraversalOrder(
                    order: const NumericFocusOrder(1),
                    child: TextFormField(
                      controller: _emailController,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(labelText: l10n.email, prefixIcon: const Icon(Icons.email_outlined)),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => v?.isEmpty ?? true ? l10n.emailRequired : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FocusTraversalOrder(
                    order: const NumericFocusOrder(2),
                    child: TextFormField(
                      controller: _passwordController,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(labelText: l10n.password, prefixIcon: const Icon(Icons.lock_outline)),
                      obscureText: true,
                      validator: (v) => v?.isEmpty ?? true ? l10n.passwordRequired : null,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(l10n.signIn),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => context.go('/auth/register'),
                    child: Text(l10n.noAccountRegister),
                  ),
                  TextButton(
                    onPressed: () => context.go('/auth/recover'),
                    child: Text(l10n.recoverFromBackup),
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
