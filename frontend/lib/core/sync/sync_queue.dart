import 'dart:async';

import '../crypto/crypto_service.dart';
import 'sync_engine.dart';

/// Manages the sync queue and automatic sync scheduling.
///
/// The queue is crypto-aware: it checks whether [CryptoService] is unlocked
/// before attempting a push, and surfaces encryption failures as structured
/// errors rather than crashing the periodic timer.
class SyncQueue {
  final SyncEngine _syncEngine;
  final CryptoService _crypto;
  Timer? _periodicTimer;
  bool _isSyncing = false;

  /// The most recent sync error, if any. Cleared at the start of each sync.
  SyncQueueError? lastError;

  SyncQueue(this._syncEngine, this._crypto);

  /// Start periodic sync (every 30 seconds when app is active).
  void startPeriodicSync({Duration interval = const Duration(seconds: 30)}) {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(interval, (_) => syncIfNeeded());
  }

  /// Stop periodic sync.
  void stopPeriodicSync() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  /// Trigger a sync if not already syncing.
  Future<SyncResult?> syncIfNeeded() async {
    if (_isSyncing) return null;
    return syncNow();
  }

  /// Force an immediate sync.
  ///
  /// Returns the [SyncResult] on success. Throws [SyncQueueError] on failure
  /// so that callers (e.g. pull-to-refresh) can surface the issue.
  Future<SyncResult> syncNow() async {
    if (_isSyncing) {
      throw StateError('Sync already in progress');
    }

    _isSyncing = true;
    lastError = null;

    try {
      // Check crypto availability before attempting a full sync.
      // Pull still works without crypto (blobs are stored encrypted-only),
      // but push is skipped by the engine when crypto is not unlocked.
      final result = await _syncEngine.sync();

      // If nothing was pushed because crypto was not available, record a
      // warning so the UI can inform the user.
      if (!_crypto.isUnlocked) {
        lastError = SyncQueueError(
          kind: SyncErrorKind.cryptoNotReady,
          message: 'Encryption keys are not unlocked. '
              'Pulled items are stored encrypted and will be decrypted '
              'after you unlock.',
        );
      }

      return result;
    } on StateError {
      rethrow;
    } catch (e) {
      // Classify the error so the UI can react appropriately.
      lastError = _classifyError(e);
      throw lastError!;
    } finally {
      _isSyncing = false;
    }
  }

  /// Whether a sync is currently in progress.
  bool get isSyncing => _isSyncing;

  /// Whether the crypto service is unlocked and ready for encrypted sync.
  bool get canEncrypt => _crypto.isUnlocked;

  /// Dispose resources.
  void dispose() {
    stopPeriodicSync();
  }

  /// Attempt to classify an exception into a structured error.
  SyncQueueError _classifyError(Object error) {
    final message = error.toString();

    if (message.contains('CryptoService is not unlocked') ||
        message.contains('StateError')) {
      return SyncQueueError(
        kind: SyncErrorKind.cryptoNotReady,
        message: 'Encryption keys are not available. Please unlock first.',
        cause: error,
      );
    }

    if (message.contains('SocketException') ||
        message.contains('Connection refused') ||
        message.contains('Connection timed out')) {
      return SyncQueueError(
        kind: SyncErrorKind.network,
        message: 'Network error. Will retry on the next scheduled sync.',
        cause: error,
      );
    }

    if (message.contains('401') || message.contains('Unauthorized')) {
      return SyncQueueError(
        kind: SyncErrorKind.auth,
        message: 'Authentication expired. Please log in again.',
        cause: error,
      );
    }

    return SyncQueueError(
      kind: SyncErrorKind.unknown,
      message: 'Sync failed: $message',
      cause: error,
    );
  }
}

/// Structured error from the sync queue.
class SyncQueueError implements Exception {
  final SyncErrorKind kind;
  final String message;
  final Object? cause;

  SyncQueueError({
    required this.kind,
    required this.message,
    this.cause,
  });

  @override
  String toString() => 'SyncQueueError($kind): $message';
}

/// Categories of sync errors for UI handling.
enum SyncErrorKind {
  /// Encryption keys are not available.
  cryptoNotReady,

  /// Network connectivity issue.
  network,

  /// Authentication token expired or invalid.
  auth,

  /// Any other error.
  unknown,
}
