import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../main.dart';
import '../../../core/constants/app_durations.dart';
import '../../../core/crypto/crypto_service.dart';
import '../../../core/crypto/key_storage.dart';
import '../../../core/crypto/master_key.dart';
import '../../../core/error/error.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/keyboard_scroll_mixin.dart';
import '../../../core/widgets/pressable_scale.dart';

class RecoveryScreen extends ConsumerStatefulWidget {
  const RecoveryScreen({super.key});

  @override
  ConsumerState<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends ConsumerState<RecoveryScreen>
    with WidgetsBindingObserver, KeyboardScrollMixin {
  int _currentStep = 0;
  bool _manualMode = false;
  bool _isLoading = false;
  String? _error;

  final _emailController = TextEditingController();
  final _mnemonicController = TextEditingController();
  final _mnemonicFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _scrollController = ScrollController();
  final _wordControllers = List.generate(12, (_) => TextEditingController());
  final _wordFocusNodes = List.generate(12, (_) => FocusNode());

  int _wordCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mnemonicController.addListener(_onMnemonicChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _emailController.dispose();
    _mnemonicController.dispose();
    _mnemonicFocusNode.dispose();
    _emailFocusNode.dispose();
    _scrollController.dispose();
    for (final c in _wordControllers) {
      c.dispose();
    }
    for (final f in _wordFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    onKeyboardMetricsChanged();
  }

  void _onMnemonicChanged() {
    final text = _mnemonicController.text.trim();
    final count = text.isEmpty
        ? 0
        : text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    if (count != _wordCount) {
      setState(() => _wordCount = count);
    }
  }

  int get _manualFilledCount =>
      _wordControllers.where((c) => c.text.trim().isNotEmpty).length;

  String _buildMnemonic() {
    if (_manualMode) {
      return _wordControllers
          .where((c) => c.text.trim().isNotEmpty)
          .map((c) => c.text.trim().toLowerCase())
          .join(' ');
    }
    return _mnemonicController.text.trim().toLowerCase();
  }

  int get _effectiveWordCount => _manualMode ? _manualFilledCount : _wordCount;

  void _goToStep(int step) {
    setState(() {
      _currentStep = step;
      _error = null;
    });
  }

  /// AppBar back action: step back inside the flow, or leave to sign in.
  void _onAppBarBack() {
    if (_isLoading) return;
    if (_currentStep > 0) {
      _goToStep(_currentStep - 1);
    } else {
      context.push('/auth/login');
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null) return;
    final text = data!.text!.trim();
    if (text.isEmpty) return;

    if (_manualMode) {
      final words = text.split(RegExp(r'\s+'));
      for (int i = 0; i < 12 && i < words.length; i++) {
        _wordControllers[i].text = words[i];
      }
      setState(() {});
    } else {
      _mnemonicController.text = text;
    }
  }

  void _clearMnemonic() {
    if (_manualMode) {
      for (final c in _wordControllers) {
        c.clear();
      }
      setState(() {});
    } else {
      _mnemonicController.clear();
    }
  }

  void _syncToManualMode() {
    final words = _mnemonicController.text.trim().split(RegExp(r'\s+'));
    for (int i = 0; i < 12; i++) {
      _wordControllers[i].text = i < words.length ? words[i] : '';
    }
  }

  void _syncToTextareaMode() {
    final text = _wordControllers
        .where((c) => c.text.trim().isNotEmpty)
        .map((c) => c.text.trim())
        .join(' ');
    _mnemonicController.text = text;
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _goToStep(0);
      setState(() => _error = null);
      return;
    }

    final allFilled = _effectiveWordCount >= 12;
    if (!allFilled) {
      final l10n = AppLocalizations.of(context)!;
      setState(() => _error = l10n.recoveryKeyRequired);
      return;
    }

    setState(() {
      _isLoading = true;
      _currentStep = 2;
      _error = null;
    });

    try {
      final mnemonic = _buildMnemonic();

      final api = ref.read(apiClientProvider);
      RecoveryData? recoveryData;
      try {
        recoveryData = await api.getRecoverySalt(email);
      } catch (e) {
        debugPrint('[RecoveryScreen] failed to fetch recovery data: $e');
      }

      final serverSalt = recoveryData?.recoverySalt;
      final encryptedMasterKey = recoveryData?.encryptedMasterKey;

      if (encryptedMasterKey == null || serverSalt == null) {
        if (!mounted) return;
        final l10n = AppLocalizations.of(context)!;
        setState(() {
          _currentStep = 1;
          _error = l10n.invalidRecoveryKeyForAccount;
          _isLoading = false;
        });
        return;
      }

      // Decrypt the real master key (derived from password) using the
      // recovery mnemonic + recovery salt.
      final masterKey = await MasterKeyManager.unwrapMasterKey(
        encryptedMasterKey,
        mnemonic,
        serverSalt,
      );

      final authKey = await MasterKeyManager.deriveAuthKey(masterKey);
      final authKeyHash = await MasterKeyManager.hashAuthKey(authKey);

      await api.login(
        LoginRequest(
          email: email,
          authKeyHash: authKeyHash,
        ),
      );

      await MasterKeyManager.storeMasterKey(masterKey);
      await MasterKeyManager.storeKdfVersion(
          MasterKeyManager.currentKdfVersion);

      // Also store the Argon2id salt so normal login works after recovery.
      // The master key was originally derived from password + salt.
      // Without the salt, the user can't log in with their password next time.
      // Fetch the login salt from the server.
      try {
        final loginSalt = await api.getSalt(email);
        if (loginSalt != null) {
          await MasterKeyManager.storeSalt(loginSalt);
        }
      } catch (_) {
        // Non-critical: recovery still works, just password login may
        // require another recovery.
      }

      final encryptKey = await MasterKeyManager.deriveEncryptKey(masterKey);
      await KeyStorage.saveEncryptKey(encryptKey);

      final crypto = ref.read(cryptoServiceProvider);
      await crypto.unlock();

      ref.read(authStateProvider.notifier).state = true;

      if (mounted) {
        context.go('/notes');
      }
    } on ArgumentError catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _currentStep = 1;
        _error = e.message ?? l10n.invalidRecoveryKey;
        _isLoading = false;
      });
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
      setState(() {
        _currentStep = 1;
        _error = message;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(AppIcons.arrowBack),
          onPressed: _onAppBarBack,
        ),
        title: Text(
          'Account Recovery',
          style: AppTextStyles.title.copyWith(fontSize: 15),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Step indicator
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: _StepIndicator(
                currentStep: _currentStep,
                totalSteps: 3,
                activeColor: primaryColor,
              ),
            ),

            // Step content
            Expanded(
              child: AnimatedSwitcher(
                duration: AppDurations.shortAnimation,
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: switch (_currentStep) {
                  0 => _buildEmailStep(
                      context,
                      l10n,
                      isDark,
                      primaryColor,
                    ),
                  1 => _buildMnemonicStep(
                      context,
                      l10n,
                      isDark,
                      primaryColor,
                    ),
                  2 => _buildRecoveringStep(
                      context,
                      l10n,
                      isDark,
                      primaryColor,
                    ),
                  _ => const SizedBox.shrink(),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 0: Email ──────────────────────────────────────

  Widget _buildEmailStep(
    BuildContext context,
    AppLocalizations l10n,
    bool isDark,
    Color primaryColor,
  ) {
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textTertiary =
        isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final linkColor = isDark ? AppColors.secondary : AppColors.primaryText;

    return SingleChildScrollView(
      key: const ValueKey('email_step'),
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        200,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Headline
          Text(
            l10n.recoverAccount,
            style: AppTextStyles.handwritingTitle.copyWith(
              fontSize: 34,
              color: textPrimary,
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // Subtitle
          Text(
            l10n.recoverAccountInstructions,
            style: AppTextStyles.caption.copyWith(
              color: textTertiary,
              height: 1.5,
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // Email field
          Text(
            l10n.email,
            style: AppTextStyles.caption.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          TextFormField(
            controller: _emailController,
            focusNode: _emailFocusNode,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.done,
            autofocus: true,
            scrollPadding: const EdgeInsets.only(bottom: 120),
            decoration: InputDecoration(
              hintText: l10n.email,
              prefixIcon: const Icon(Icons.email_outlined),
            ),
            keyboardType: TextInputType.emailAddress,
            onFieldSubmitted: (_) => _onEmailNext(),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Next button
          PressableScale(
            onPressed: _onEmailNext,
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
                child: Text(
                  l10n.nextStep,
                  style: AppTextStyles.body.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Back to sign in
          TextButton(
            onPressed: () => context.push('/auth/login'),
            style: TextButton.styleFrom(foregroundColor: linkColor),
            child: Text(
              l10n.backToSignIn,
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w500,
                color: linkColor,
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // Support footer
          _buildSupportFooter(l10n, linkColor, textTertiary),
        ],
      ),
    );
  }

  void _onEmailNext() {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = null);
      return;
    }
    _goToStep(1);
    // Auto-focus the mnemonic input after step transition
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted && !_manualMode) {
        _mnemonicFocusNode.requestFocus();
      }
    });
  }

  // ── Step 1: Mnemonic ───────────────────────────────────

  Widget _buildMnemonicStep(
    BuildContext context,
    AppLocalizations l10n,
    bool isDark,
    Color primaryColor,
  ) {
    final filled = _effectiveWordCount;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textTertiary =
        isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final linkColor = isDark ? AppColors.secondary : AppColors.primaryText;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final cardBg = isDark ? AppColors.darkCardBg : Colors.white;

    return SingleChildScrollView(
      key: const ValueKey('mnemonic_step'),
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.s4,
        AppSpacing.xl,
        200,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Heading
          Text(
            l10n.recoveryStepMnemonicTitle,
            style: AppTextStyles.title.copyWith(
              fontSize: 18,
              color: textPrimary,
            ),
          ),

          const SizedBox(height: AppSpacing.s4),

          // Helper caption
          Text(
            l10n.recoveryStepMnemonicDesc,
            style: AppTextStyles.caption.copyWith(
              color: textTertiary,
              height: 1.5,
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Error
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
                    color:
                        isDark ? AppColors.darkErrorBg : AppColors.lightErrorBg,
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

          // Textarea mode (primary)
          if (!_manualMode)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: borderColor, width: 1),
              ),
              child: Column(
                children: [
                  TextFormField(
                    controller: _mnemonicController,
                    focusNode: _mnemonicFocusNode,
                    maxLines: 3,
                    minLines: 3,
                    scrollPadding: const EdgeInsets.only(bottom: 120),
                    style: AppTextStyles.body.copyWith(
                      fontSize: 14,
                      color: textPrimary,
                      letterSpacing: 0.5,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintText: l10n.recoveryMnemonicHint,
                      hintStyle: TextStyle(
                        color: textTertiary.withValues(alpha: 0.4),
                        fontSize: 13,
                      ),
                    ),
                    keyboardType: TextInputType.multiline,
                    autocorrect: false,
                    enableSuggestions: false,
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  Row(
                    children: [
                      _ProgressBadge(filled: filled, total: 12),
                      const Spacer(),
                      _ClearChip(
                        onTap: _clearMnemonic,
                        label: l10n.recoveryClearMnemonic,
                      ),
                      const SizedBox(width: AppSpacing.s8),
                      _PasteChip(
                        onTap: _pasteFromClipboard,
                        label: l10n.pasteFromClipboard,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  // Live preview of the parsed words as chips.
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _mnemonicController,
                    builder: (context, value, _) => _WordsPreview(
                      text: value.text,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ),

          // Manual mode grid
          if (_manualMode) ...[
            // Header row
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.recoveryKeyLabel,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textSecondary,
                    ),
                  ),
                ),
                _ProgressBadge(filled: filled, total: 12),
                const SizedBox(width: AppSpacing.sm),
                _PasteChip(
                  onTap: _pasteFromClipboard,
                  label: l10n.pasteFromClipboard,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s12),

            // Word grid (4 columns x 3 rows)
            ...List.generate(3, (row) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: row < 2 ? AppSpacing.s4 : 0,
                ),
                child: Row(
                  children: List.generate(4, (col) {
                    final index = row * 4 + col;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: col > 0 ? AppSpacing.s4 : 0,
                        ),
                        child: _WordChip(
                          index: index,
                          controller: _wordControllers[index],
                          focusNode: _wordFocusNodes[index],
                          nextFocusNode:
                              index < 11 ? _wordFocusNodes[index + 1] : null,
                          onFilled: _submit,
                          scrollPadding: const EdgeInsets.only(bottom: 120),
                        ),
                      ),
                    );
                  }),
                ),
              );
            }),

            // Format hint
            const SizedBox(height: AppSpacing.s8),
            Text(
              l10n.recoveryKeyFormatHint,
              style: AppTextStyles.caption.copyWith(
                color: textTertiary,
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.md),

          // Toggle between modes
          TextButton.icon(
            onPressed: () {
              setState(() {
                if (_manualMode) {
                  _syncToTextareaMode();
                  _manualMode = false;
                } else {
                  _syncToManualMode();
                  _manualMode = true;
                }
              });
            },
            icon: Icon(
              _manualMode
                  ? Icons.text_snippet_outlined
                  : Icons.edit_note_outlined,
              size: 16,
              color: linkColor,
            ),
            label: Text(
              _manualMode
                  ? l10n.recoveryStepMnemonicTitle
                  : l10n.recoveryEnterManually,
              style: AppTextStyles.caption.copyWith(
                color: linkColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Submit button
          PressableScale(
            onPressed: filled >= 12 && !_isLoading ? _submit : null,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                color: filled >= 12 ? primaryColor : AppColors.primaryDisabled,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                boxShadow: filled >= 12
                    ? [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.25),
                          offset: const Offset(0, 4),
                          blurRadius: 16,
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: _isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      )
                    : Text(
                        l10n.recoverAccount,
                        style: AppTextStyles.body.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Back
          TextButton(
            onPressed: () => _goToStep(0),
            style: TextButton.styleFrom(foregroundColor: linkColor),
            child: Text(
              l10n.backToSignIn,
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w500,
                color: linkColor,
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // Support footer
          _buildSupportFooter(l10n, linkColor, textTertiary),
        ],
      ),
    );
  }

  // ── Step 2: Recovering ─────────────────────────────────

  Widget _buildRecoveringStep(
    BuildContext context,
    AppLocalizations l10n,
    bool isDark,
    Color primaryColor,
  ) {
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textTertiary =
        isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;

    return Padding(
      key: const ValueKey('recovering_step'),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 64),
          Center(
            child: SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: primaryColor,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            l10n.recoveryStepRecoveringTitle,
            style: AppTextStyles.handwritingTitle.copyWith(
              fontSize: 30,
              color: textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.recoveryStepRecoveringDesc,
            style: AppTextStyles.caption.copyWith(
              fontSize: 14,
              color: textTertiary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Centered "Need help? Contact support" footer text.
  Widget _buildSupportFooter(
    AppLocalizations l10n,
    Color linkColor,
    Color textTertiary,
  ) {
    return Text.rich(
      TextSpan(
        text: '${l10n.needHelp} ',
        style: AppTextStyles.caption.copyWith(color: textTertiary),
        children: [
          TextSpan(
            text: l10n.contactSupport,
            style: AppTextStyles.caption.copyWith(
              color: linkColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

// ---------------------------------------------------------------------------
// Step indicator (3 dots)
// ---------------------------------------------------------------------------

class _StepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final Color activeColor;

  const _StepIndicator({
    required this.currentStep,
    required this.totalSteps,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactiveColor =
        isDark ? AppColors.darkDisabled : AppColors.lightDisabled;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(totalSteps, (index) {
        final isActive = index == currentStep;
        return AnimatedContainer(
          duration: AppDurations.mediumAnimation,
          curve: Curves.easeInOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? activeColor : inactiveColor,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Read-only 4-column preview of the parsed mnemonic words
// ---------------------------------------------------------------------------

class _WordsPreview extends StatelessWidget {
  final String text;
  final bool isDark;

  const _WordsPreview({required this.text, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final trimmed = text.trim();
    final words =
        trimmed.isEmpty ? const <String>[] : trimmed.split(RegExp(r'\s+'));
    final emptyBg = isDark ? AppColors.darkInputFill : Colors.white;
    final emptyBorder = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final emptyFg =
        isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;

    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.s4,
      crossAxisSpacing: AppSpacing.s4,
      childAspectRatio: 2.2,
      children: List.generate(12, (i) {
        final hasWord = i < words.length && words[i].isNotEmpty;
        return Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: hasWord ? AppColors.primarySoft : emptyBg,
            borderRadius: BorderRadius.circular(AppRadius.xs),
            border: Border.all(
              color: hasWord ? AppColors.primarySoftBorder : emptyBorder,
              width: 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
          child: Text(
            hasWord ? words[i] : '·',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              fontSize: 12,
              color: hasWord ? AppColors.primaryText : emptyFg,
              fontWeight: hasWord ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Single word input chip (for manual mode)
// ---------------------------------------------------------------------------

class _WordChip extends StatelessWidget {
  final int index;
  final TextEditingController controller;
  final FocusNode focusNode;
  final FocusNode? nextFocusNode;
  final VoidCallback onFilled;
  final EdgeInsets scrollPadding;

  const _WordChip({
    required this.index,
    required this.controller,
    required this.focusNode,
    required this.nextFocusNode,
    required this.onFilled,
    this.scrollPadding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasText = controller.text.isNotEmpty;
    final emptyBg = isDark ? AppColors.darkInputFill : Colors.white;
    final emptyBorder = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final emptyFg =
        isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: hasText ? AppColors.primarySoft : emptyBg,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(
          color: hasText ? AppColors.primarySoftBorder : emptyBorder,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 22,
            alignment: Alignment.center,
            child: Text(
              '${index + 1}',
              style: AppTextStyles.caption.copyWith(
                color: hasText ? AppColors.primaryText : emptyFg,
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
            ),
          ),
          Expanded(
            child: TextFormField(
              controller: controller,
              focusNode: focusNode,
              scrollPadding: scrollPadding,
              style: AppTextStyles.body.copyWith(
                fontSize: 13,
                color: hasText ? AppColors.primaryText : emptyFg,
                fontWeight: hasText ? FontWeight.w600 : FontWeight.w400,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.only(
                  right: AppSpacing.s4,
                  top: 11,
                  bottom: 11,
                ),
                hintText: '· · ·',
                hintStyle: TextStyle(
                  color: emptyFg.withValues(alpha: 0.4),
                  letterSpacing: 1,
                ),
              ),
              textInputAction: nextFocusNode != null
                  ? TextInputAction.next
                  : TextInputAction.done,
              onChanged: (_) {
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
        : (isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary);

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
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.content_paste_rounded,
              size: 13,
              color: AppColors.primaryText,
            ),
            const SizedBox(width: AppSpacing.s4),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.primaryText,
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

// ---------------------------------------------------------------------------
// Clear chip button
// ---------------------------------------------------------------------------

class _ClearChip extends StatelessWidget {
  final VoidCallback onTap;
  final String label;

  const _ClearChip({
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
          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.close_rounded,
              size: 13,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: AppSpacing.s4),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: Theme.of(context).colorScheme.error,
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
