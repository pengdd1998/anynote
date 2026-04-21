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

class RecoveryScreen extends ConsumerStatefulWidget {
  const RecoveryScreen({super.key});

  @override
  ConsumerState<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends ConsumerState<RecoveryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _mnemonicController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _mnemonicController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final mnemonic = _mnemonicController.text.trim().toLowerCase();
      final email = _emailController.text.trim();

      // Step 1: Recover master key from BIP-39 mnemonic.
      final masterKey =
          await MasterKeyManager.recoverMasterKeyFromMnemonic(mnemonic);

      // Step 2: Derive auth key from the master key.
      final authKey = await MasterKeyManager.deriveAuthKey(masterKey);

      // Step 3: Hash the auth key for server verification.
      final authKeyHash = await MasterKeyManager.hashAuthKey(authKey);

      // Step 4: Login with the auth key hash.
      final api = ref.read(apiClientProvider);
      await api.login(LoginRequest(
        email: email,
        authKeyHash: authKeyHash,
      ),);

      // Step 5: Store the master key and derived keys locally via KeyStorage.
      await MasterKeyManager.storeMasterKey(masterKey);

      // Derive and store the encrypt key.
      final encryptKey = await MasterKeyManager.deriveEncryptKey(masterKey);
      await KeyStorage.saveEncryptKey(encryptKey);

      // Step 6: Unlock CryptoService so the app can decrypt synced data.
      final crypto = ref.read(cryptoServiceProvider);
      await crypto.unlock();

      // Step 7: Mark as authenticated and navigate to notes list.
      ref.read(authStateProvider.notifier).state = true;

      if (mounted) {
        context.go('/notes');
      }
    } on ArgumentError catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      // Invalid mnemonic (wrong number of words, unknown word, checksum
      // mismatch).
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.key_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,),
                  const SizedBox(height: 16),
                  Text(l10n.recoverAccount,
                      style: Theme.of(context).textTheme.headlineMedium,
                      textAlign: TextAlign.center,),
                  const SizedBox(height: 8),
                  Text(
                      l10n.recoverAccountInstructions,
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,),
                  const SizedBox(height: 32),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(_error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error,),),
                    ),
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: l10n.email,
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) =>
                        v?.isEmpty ?? true ? l10n.emailRequired : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _mnemonicController,
                    decoration: InputDecoration(
                      labelText: l10n.recoveryKeyLabel,
                      prefixIcon: const Icon(Icons.vpn_key_outlined),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.content_paste),
                        tooltip: l10n.pasteFromClipboard,
                        onPressed: () async {
                          final data =
                              await Clipboard.getData(Clipboard.kTextPlain);
                          if (data?.text != null) {
                            _mnemonicController.text = data!.text!;
                          }
                        },
                      ),
                    ),
                    maxLines: 3,
                    textInputAction: TextInputAction.done,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return l10n.recoveryKeyRequired;
                      }
                      final words = v.trim().split(RegExp(r'\s+'));
                      if (words.length != 12) {
                        return l10n.recoveryKeyWordCount;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.recoveryKeyFormatHint,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.recoverAccount),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => context.go('/auth/login'),
                    child: Text(l10n.backToSignIn),
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
