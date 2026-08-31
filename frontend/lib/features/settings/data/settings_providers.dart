import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../main.dart';
import '../../../core/crypto/crypto_service.dart';
import '../../../core/crypto/key_storage.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/sync/sync_queue_manager.dart';
import 'api_models.dart';
import 'llm_direct_client.dart';
import 'local_llm_store.dart';

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

/// Client-direct connection tester for local LLM configs (plain Dio, no auth
/// interceptor, no server involvement).
final llmDirectClientProvider = Provider<LlmDirectClient>((ref) {
  return LlmDirectClient();
});

/// Manages the list of LLM configurations stored LOCALLY on the device.
///
/// Privacy: user LLM configs (API keys) are persisted only in the device's
/// secure storage ([LocalLlmStore]) and are never uploaded to the AnyNote
/// server. AI calls with a local config go directly to the provider; the
/// server proxy remains only as the shared-mode fallback when the user has
/// no local default config.
class LlmConfigsNotifier extends AsyncNotifier<List<LlmConfig>> {
  @override
  Future<List<LlmConfig>> build() => ref.read(localLlmStoreProvider).load();

  LocalLlmStore get _store => ref.read(localLlmStoreProvider);

  /// Create a new LLM config from a snake_case map and refresh the list.
  ///
  /// The store assigns the id and timestamps; when no stored config is the
  /// default yet, the new config becomes the default (first config is
  /// default).
  Future<void> create(Map<String, dynamic> config) async {
    final existing = await _store.load();
    final now = DateTime.now().toUtc();
    await _store.create(
      LlmConfig(
        id: '',
        name: config['name'] as String? ?? '',
        provider: config['provider'] as String? ?? 'custom',
        baseUrl: config['base_url'] as String?,
        apiKey: config['api_key'] as String?,
        model: config['model'] as String? ?? '',
        isDefault: config['is_default'] as bool? ?? existing.isEmpty,
        maxTokens: config['max_tokens'] as int? ?? 4096,
        temperature: (config['temperature'] as num?)?.toDouble() ?? 0.7,
        createdAt: now,
        updatedAt: now,
      ),
    );
    ref.invalidateSelf();
  }

  /// Update an existing LLM config with a partial snake_case map.
  ///
  /// Mirrors the server's merged-patch semantics: empty strings inherit the
  /// stored value, and the stored API key is kept when the map carries no new
  /// one. Setting `is_default: true` clears the default flag on all others.
  Future<void> updateConfig(String id, Map<String, dynamic> config) async {
    final configs = await _store.load();
    final index = configs.indexWhere((c) => c.id == id);
    if (index < 0) {
      throw StateError('LLM config not found: $id');
    }
    final current = configs[index];
    String merged(String? incoming, String fallback) =>
        (incoming == null || incoming.isEmpty) ? fallback : incoming;

    await _store.update(
      current.copyWith(
        name: merged(config['name'] as String?, current.name),
        provider: merged(config['provider'] as String?, current.provider),
        baseUrl: merged(config['base_url'] as String?, current.baseUrl ?? ''),
        model: merged(config['model'] as String?, current.model),
        apiKey: merged(config['api_key'] as String?, current.apiKey ?? ''),
        maxTokens: config['max_tokens'] as int? ?? current.maxTokens,
        temperature:
            (config['temperature'] as num?)?.toDouble() ?? current.temperature,
        isDefault: config['is_default'] as bool? ?? current.isDefault,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
    ref.invalidateSelf();
  }

  /// Delete an LLM config and refresh the list.
  Future<void> delete(String id) async {
    await _store.delete(id);
    ref.invalidateSelf();
  }

  /// Mark [id] as the default config. Direct AI calls route through the
  /// default local config; without one the shared LLM and its rate limits
  /// apply.
  Future<void> setDefault(String id) async {
    await _store.setDefault(id);
    ref.invalidateSelf();
  }

  /// Test an LLM config connection CLIENT-DIRECT: sends a tiny chat
  /// completion against the config's own base URL. Throws on failure; no
  /// server round trip is involved (the API key only reaches the provider).
  Future<void> test(String id) async {
    final configs = await _store.load();
    LlmConfig? cfg;
    for (final c in configs) {
      if (c.id == id) cfg = c;
    }
    if (cfg == null) {
      throw StateError('LLM config not found: $id');
    }
    await ref.read(llmDirectClientProvider).testConnection(
          baseUrl: cfg.baseUrl ?? '',
          apiKey: cfg.apiKey ?? '',
          model: cfg.model,
        );
  }

  /// Refresh the list of LLM configs from local storage.
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
