import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../main.dart';
import '../../../core/crypto/crypto_service.dart';
import '../../../core/crypto/key_storage.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/sync/sync_queue_manager.dart';
import 'api_models.dart';

// ── Sync Engine Provider ──────────────────────────────

/// Provides the SyncEngine instance, wired to the database, API client, and
/// crypto service for E2E encryption during sync.
final syncEngineProvider = Provider<SyncEngine>((ref) {
  final db = ref.watch(databaseProvider);
  final api = ref.watch(apiClientProvider);
  final crypto = ref.watch(cryptoServiceProvider);
  return SyncEngine(db, api, crypto);
});

// ── Sync Queue Manager Provider ───────────────────────

/// Provides the SyncQueueManager for offline-first operations.
///
/// The queue manager is wired to the [connectivityServiceProvider] so that it
/// can skip processing when the device is offline and only flush queued
/// operations when connectivity is restored.
final syncQueueManagerProvider = Provider<SyncQueueManager>((ref) {
  final db = ref.watch(databaseProvider);
  final engine = ref.watch(syncEngineProvider);
  // Watch the connectivity service so the queue manager gets rebuilt if
  // the service is recreated (shouldn't happen in practice, but correct).
  ref.watch(connectivityServiceProvider);
  return SyncQueueManager(
    db,
    engine,
    connectivityChecker: () => ref.read(connectivityServiceProvider),
  );
});

// ── AI Quota ──────────────────────────────────────────

/// Async notifier that fetches and exposes AI quota data.
class AiQuotaNotifier extends AsyncNotifier<AiQuota> {
  @override
  Future<AiQuota> build() async {
    final api = ref.read(apiClientProvider);
    final raw = await api.getAiQuota();
    return AiQuota.fromJson(raw);
  }

  /// Refresh the AI quota from the server.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final api = ref.read(apiClientProvider);
      final raw = await api.getAiQuota();
      return AiQuota.fromJson(raw);
    });
  }
}

final aiQuotaProvider = AsyncNotifierProvider<AiQuotaNotifier, AiQuota>(
  AiQuotaNotifier.new,
);

// ── Sync Status ───────────────────────────────────────

/// Async notifier that fetches sync status from the server and local DB.
class SyncStatusNotifier extends AsyncNotifier<SyncStatusInfo> {
  @override
  Future<SyncStatusInfo> build() async {
    final api = ref.read(apiClientProvider);
    final raw = await api.syncStatus();
    return SyncStatusInfo.fromJson(raw);
  }

  /// Trigger a full sync cycle and refresh status afterwards.
  Future<SyncResult> sync() async {
    final engine = ref.read(syncEngineProvider);
    final result = await engine.sync();
    // Refresh sync status after sync completes.
    final raw = await ref.read(apiClientProvider).syncStatus();
    state = AsyncData(SyncStatusInfo.fromJson(raw));
    return result;
  }

  /// Refresh sync status from server without syncing.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final api = ref.read(apiClientProvider);
      final raw = await api.syncStatus();
      return SyncStatusInfo.fromJson(raw);
    });
  }
}

final syncStatusProvider =
    AsyncNotifierProvider<SyncStatusNotifier, SyncStatusInfo>(
  SyncStatusNotifier.new,
);

// ── Account Info ──────────────────────────────────────

/// Loads account info from the server via GET /api/v1/auth/me.
class AccountInfoNotifier extends AsyncNotifier<AccountInfo> {
  @override
  Future<AccountInfo> build() async {
    final api = ref.read(apiClientProvider);
    final raw = await api.getMe();
    return AccountInfo.fromJson(raw);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final api = ref.read(apiClientProvider);
      final raw = await api.getMe();
      return AccountInfo.fromJson(raw);
    });
  }
}

final accountInfoProvider =
    AsyncNotifierProvider<AccountInfoNotifier, AccountInfo>(
  AccountInfoNotifier.new,
);

// ── LLM Configs ───────────────────────────────────────

/// Manages the list of LLM configurations.
class LlmConfigsNotifier extends AsyncNotifier<List<LlmConfig>> {
  @override
  Future<List<LlmConfig>> build() async {
    final api = ref.read(apiClientProvider);
    final rawList = await api.listLlmConfigs();
    return rawList.map((raw) => LlmConfig.fromJson(raw)).toList();
  }

  /// Create a new LLM config and refresh the list.
  Future<void> create(Map<String, dynamic> config) async {
    final api = ref.read(apiClientProvider);
    await api.createLlmConfig(config);
    ref.invalidateSelf();
  }

  /// Update an existing LLM config and refresh the list.
  Future<void> updateConfig(String id, Map<String, dynamic> config) async {
    final api = ref.read(apiClientProvider);
    await api.updateLlmConfig(id, config);
    ref.invalidateSelf();
  }

  /// Delete an LLM config and refresh the list.
  Future<void> delete(String id) async {
    final api = ref.read(apiClientProvider);
    await api.deleteLlmConfig(id);
    ref.invalidateSelf();
  }

  /// Test an LLM config connection.
  Future<Map<String, dynamic>> test(String id) async {
    final api = ref.read(apiClientProvider);
    return api.testLlmConfig(id);
  }

  /// Refresh the list of LLM configs.
  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

final llmConfigsProvider =
    AsyncNotifierProvider<LlmConfigsNotifier, List<LlmConfig>>(
  LlmConfigsNotifier.new,
);

/// Available LLM provider names (e.g. OpenAI, DeepSeek, etc.).
final llmProvidersProvider = FutureProvider<List<String>>((ref) async {
  final api = ref.read(apiClientProvider);
  return api.listLlmProviders();
});

// ── Platform Connections ──────────────────────────────

/// Manages platform connection status.
class PlatformsNotifier extends AsyncNotifier<List<PlatformConnection>> {
  @override
  Future<List<PlatformConnection>> build() async {
    final api = ref.read(apiClientProvider);
    final rawList = await api.listPlatforms();
    return rawList.map((raw) => PlatformConnection.fromJson(raw)).toList();
  }

  /// Connect to a platform and refresh the list.
  Future<Map<String, dynamic>> connect(String platform) async {
    final api = ref.read(apiClientProvider);
    final result = await api.connectPlatform(platform);
    ref.invalidateSelf();
    return result;
  }

  /// Disconnect from a platform and refresh the list.
  Future<void> disconnect(String platform) async {
    final api = ref.read(apiClientProvider);
    await api.disconnectPlatform(platform);
    ref.invalidateSelf();
  }

  /// Verify a platform connection.
  Future<Map<String, dynamic>> verify(String platform) async {
    final api = ref.read(apiClientProvider);
    return api.verifyPlatform(platform);
  }

  /// Refresh the platform list.
  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

final platformsProvider =
    AsyncNotifierProvider<PlatformsNotifier, List<PlatformConnection>>(
  PlatformsNotifier.new,
);

// ── Encryption Status ─────────────────────────────────

/// Checks whether encryption is initialized and the crypto service is unlocked.
class EncryptionStatusNotifier extends StateNotifier<EncryptionStatus> {
  final CryptoService _cryptoService;

  EncryptionStatusNotifier(this._cryptoService)
      : super(
          const EncryptionStatus(
            isInitialized: false,
            isUnlocked: false,
          ),
        ) {
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final initialized = await _cryptoService.isInitialized();
    state = EncryptionStatus(
      isInitialized: initialized,
      isUnlocked: _cryptoService.isUnlocked,
    );
  }

  /// Reload encryption status (e.g. after password change or lock).
  Future<void> refresh() async {
    await _loadStatus();
  }
}

final encryptionStatusProvider =
    StateNotifierProvider<EncryptionStatusNotifier, EncryptionStatus>(
  (ref) {
    final crypto = ref.watch(cryptoServiceProvider);
    return EncryptionStatusNotifier(crypto);
  },
);

/// Loaded on demand: the encrypted recovery key from secure storage.
final recoveryKeyProvider = FutureProvider<String?>((ref) async {
  return KeyStorage.loadRecoveryKey();
});

// ── Local Item Counts ─────────────────────────────────

/// Counts of encrypted items in the local database.
class LocalItemCountsNotifier extends AsyncNotifier<Map<String, int>> {
  @override
  Future<Map<String, int>> build() async {
    final db = ref.read(databaseProvider);

    final notesCount = await (db.select(db.notes)
          ..where((n) => n.deletedAt.isNull()))
        .get()
        .then((list) => list.length);

    final tagsCount = await db.tagsDao.getAllTags().then((l) => l.length);

    final collectionsCount =
        await db.collectionsDao.getAllCollections().then((l) => l.length);

    final aiContentCount =
        await db.generatedContentsDao.getAll().then((l) => l.length);

    return {
      'notes': notesCount,
      'tags': tagsCount,
      'collections': collectionsCount,
      'ai_content': aiContentCount,
    };
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

final localItemCountsProvider =
    AsyncNotifierProvider<LocalItemCountsNotifier, Map<String, int>>(
  LocalItemCountsNotifier.new,
);

// ── Data Classes ──────────────────────────────────────

class EncryptionStatus {
  final bool isInitialized;
  final bool isUnlocked;

  const EncryptionStatus({
    required this.isInitialized,
    required this.isUnlocked,
  });
}
