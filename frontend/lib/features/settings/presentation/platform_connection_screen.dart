import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/widgets/app_components.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/error_state_widget.dart';
import '../../../l10n/app_localizations.dart';
import '../data/api_models.dart';
import '../data/settings_providers.dart';

class PlatformConnectionScreen extends ConsumerStatefulWidget {
  const PlatformConnectionScreen({super.key});

  @override
  ConsumerState<PlatformConnectionScreen> createState() =>
      _PlatformConnectionScreenState();
}

class _PlatformConnectionScreenState
    extends ConsumerState<PlatformConnectionScreen> {
  // Static icon mapping for known platforms.
  static const _platformIcons = <String, IconData>{
    'xiaohongshu': AppIcons.camera,
    'wechat': AppIcons.chat,
    'zhihu': AppIcons.questionAnswer,
    'medium': AppIcons.article,
  };

  bool _isConnecting = false;
  String? _connectingPlatform;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final platformsAsync = ref.watch(platformsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.platformConnections)),
      body: platformsAsync.when(
        data: (platforms) {
          if (platforms.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    AppIcons.share,
                    size: 48,
                    color: Theme.of(context).disabledColor,
                  ),
                  const SizedBox(height: 12),
                  Text(l10n.noPlatformsAvailable),
                  const SizedBox(height: 8),
                  Text(
                    l10n.platformConnectionsWillAppear,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).disabledColor,
                    ),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(platformsProvider.notifier).refresh(),
            child: ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 32),
              children: platforms.asMap().entries.map((entry) {
                final index = entry.key;
                final p = entry.value;
                return StaggeredGroup(
                  staggerIndex: index,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _PlatformCard(
                      platform: p,
                      platformIcons: _platformIcons,
                      isConnecting: _isConnecting &&
                          _connectingPlatform == p.platform.toLowerCase(),
                      l10n: l10n,
                      onConnect: () => _connect(
                        p.platform.toLowerCase(),
                        p.displayName ?? p.platform,
                      ),
                      onVerify: () => _verify(
                        p.platform.toLowerCase(),
                      ),
                      onDisconnect: () => _confirmDisconnect(
                        p.platform.toLowerCase(),
                        p.displayName ?? p.platform,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) {
          final l10n = AppLocalizations.of(context)!;
          return ErrorStateWidget(
            message: '${l10n.failedToLoadPlatforms}\n$error',
            onRetry: () => ref.read(platformsProvider.notifier).refresh(),
          );
        },
      ),
    );
  }

  /// Connect to a platform via the API.
  Future<void> _connect(String platform, String displayName) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isConnecting = true;
      _connectingPlatform = platform;
    });

    try {
      final result =
          await ref.read(platformsProvider.notifier).connect(platform);

      // Check if the response includes QR code data (e.g. for Xiaohongshu).
      final qrCode = result['qr_code']?.toString();
      if (qrCode != null && qrCode.isNotEmpty) {
        if (mounted) _showQRCodeDialog(displayName, qrCode);
      } else {
        if (mounted) {
          AppSnackBar.info(context, message: l10n.connectedTo(displayName));
        }
      }
    } on DioException catch (e) {
      if (mounted) {
        AppSnackBar.error(
          context,
          message: l10n.failedToConnect(e.message ?? 'Unknown error'),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _connectingPlatform = null;
        });
      }
    }
  }

  /// Verify a platform connection.
  Future<void> _verify(String platform) async {
    final l10n = AppLocalizations.of(context)!;
    AppSnackBar.info(context, message: l10n.verifyingConnection);
    try {
      final result =
          await ref.read(platformsProvider.notifier).verify(platform);
      final valid = result['valid'] == true;
      if (mounted) {
        AppSnackBar.show(
          context,
          message: valid
              ? l10n.connectionVerified
              : l10n.connectionInvalid(
                  result['error']?.toString() ?? 'please reconnect',
                ),
          type: valid ? SnackBarType.info : SnackBarType.error,
        );
        // Refresh the platform list to reflect updated status.
        ref.invalidate(platformsProvider);
      }
    } on DioException catch (e) {
      if (mounted) {
        AppSnackBar.error(
          context,
          message: l10n.verificationFailedError(e.message ?? 'Network error'),
        );
      }
    }
  }

  /// Confirm and disconnect a platform.
  void _confirmDisconnect(String platform, String displayName) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.disconnectPlatform(displayName)),
        content: Text(l10n.disconnectPlatformConfirm(displayName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              final nav = Navigator.of(ctx);
              try {
                await ref.read(platformsProvider.notifier).disconnect(platform);
                nav.pop();
                if (mounted) {
                  AppSnackBar.info(
                    context,
                    message: l10n.disconnectedFrom(displayName),
                  );
                }
              } on DioException catch (e) {
                nav.pop();
                if (mounted) {
                  AppSnackBar.error(
                    context,
                    message:
                        l10n.failedToDisconnect(e.message ?? 'Unknown error'),
                  );
                }
              }
            },
            child: Text(l10n.disconnect),
          ),
        ],
      ),
    );
  }

  /// Show QR code dialog for platforms that require scanning (e.g. Xiaohongshu).
  void _showQRCodeDialog(String platform, String qrCodeData) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.scanQRCode),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.light
                    ? AppColors.lightInputFill
                    : AppColors.darkInputFill,
                borderRadius: BorderRadius.circular(12),
              ),
              // Display a placeholder icon. In production, decode qrCodeData
              // into an actual QR image using a QR rendering package.
              child: const Center(
                child: Icon(AppIcons.qrCode, size: 120),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.scanQRInstructions(platform),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Refresh platform status after the user has had time to scan.
              Future.delayed(const Duration(seconds: 3), () {
                ref.invalidate(platformsProvider);
              });
            },
            child: Text(l10n.done),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Platform card widget
// =============================================================================

class _PlatformCard extends StatelessWidget {
  final PlatformConnection platform;
  final Map<String, IconData> platformIcons;
  final bool isConnecting;
  final AppLocalizations l10n;
  final VoidCallback onConnect;
  final VoidCallback onVerify;
  final VoidCallback onDisconnect;

  const _PlatformCard({
    required this.platform,
    required this.platformIcons,
    required this.isConnecting,
    required this.l10n,
    required this.onConnect,
    required this.onVerify,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final displayName = platform.displayName ?? platform.platform;
    final connected = platform.isConnected;
    final platformKey = platform.platform.toLowerCase();
    final icon = platformIcons[platformKey] ?? AppIcons.language;

    // Determine trailing widget based on connection state.
    Widget trailing;
    if (isConnecting) {
      trailing = const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (connected) {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            AppIcons.checkCircleFilled,
            color: colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: onVerify,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text(l10n.verifyButton),
          ),
          TextButton(
            onPressed: onDisconnect,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              foregroundColor: colorScheme.error,
            ),
            child: Text(l10n.disconnect),
          ),
        ],
      );
    } else {
      trailing = FilledButton.tonal(
        onPressed: onConnect,
        style: FilledButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Text(l10n.connect),
      );
    }

    return SettingsGroup(
      children: [
        SettingsItem(
          icon: icon,
          title: displayName,
          subtitle: platform.status.isNotEmpty ? platform.status : null,
          trailing: trailing,
        ),
      ],
    );
  }
}
