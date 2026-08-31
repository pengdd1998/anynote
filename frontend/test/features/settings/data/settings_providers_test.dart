import 'dart:ffi';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:anynote/core/crypto/crypto_service.dart';
import 'package:anynote/core/database/app_database.dart';
import 'package:anynote/core/network/api_client.dart';
import 'package:anynote/features/settings/data/api_models.dart';
import 'package:anynote/features/settings/data/local_llm_store.dart';
import 'package:anynote/features/settings/data/settings_providers.dart';
import 'package:anynote/features/settings/data/llm_direct_client.dart';
import 'package:anynote/main.dart' show apiClientProvider, databaseProvider;

// ---------------------------------------------------------------------------
// Mock ApiClient that records calls and returns preset responses.
// ---------------------------------------------------------------------------
class MockApiClient extends ApiClient {
  // Response stubs -- set before running tests.
  Map<String, dynamic> aiQuotaResponse = {
    'plan': 'free',
    'daily_used': 10,
    'daily_limit': 100,
    'reset_at':
        DateTime.now().toUtc().add(const Duration(hours: 24)).toIso8601String(),
  };
  Map<String, dynamic> syncStatusResponse = {
    'latest_version': 42,
    'total_items': 150,
    'last_synced_at': DateTime.now().toUtc().toIso8601String(),
  };
  Map<String, dynamic> meResponse = {
    'id': 'user-1',
    'email': 'test@example.com',
    'username': 'testuser',
    'plan': 'free',
    'created_at': DateTime.now().toUtc().toIso8601String(),
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };
  List<String> llmProvidersResponse = ['OpenAI', 'DeepSeek'];
  List<Map<String, dynamic>> platformsResponse = [];
  Map<String, dynamic> connectPlatformResponse = {'status': 'connected'};
  Map<String, dynamic> verifyPlatformResponse = {'verified': true};

  // Call records.
  final List<String> connectPlatformCalls = [];
  final List<String> disconnectPlatformCalls = [];
  final List<String> verifyPlatformCalls = [];

  // Error injection -- set to throw on next call.
  Object? aiQuotaError;
  Object? syncStatusError;
  Object? meError;
  Object? listPlatformsError;
  Object? connectPlatformError;

  MockApiClient() : super(baseUrl: 'http://localhost:8080');

  @override
  Future<Map<String, dynamic>> getAiQuota() async {
    if (aiQuotaError != null) throw aiQuotaError!;
    return aiQuotaResponse;
  }

  @override
  Future<Map<String, dynamic>> syncStatus() async {
    if (syncStatusError != null) throw syncStatusError!;
    return syncStatusResponse;
  }

  @override
  Future<Map<String, dynamic>> getMe() async {
    if (meError != null) throw meError!;
    return meResponse;
  }

  @override
  Future<List<String>> listLlmProviders() async {
    return llmProvidersResponse;
  }

  @override
  Future<List<Map<String, dynamic>>> listPlatforms() async {
    if (listPlatformsError != null) throw listPlatformsError!;
    return platformsResponse;
  }

  @override
  Future<Map<String, dynamic>> connectPlatform(String platform) async {
    if (connectPlatformError != null) throw connectPlatformError!;
    connectPlatformCalls.add(platform);
    return connectPlatformResponse;
  }

  @override
  Future<void> disconnectPlatform(String platform) async {
    disconnectPlatformCalls.add(platform);
  }

  @override
  Future<Map<String, dynamic>> verifyPlatform(String platform) async {
    verifyPlatformCalls.add(platform);
    return verifyPlatformResponse;
  }
}

// ---------------------------------------------------------------------------
// Fake CryptoService for EncryptionStatusNotifier tests.
// ---------------------------------------------------------------------------
class FakeCryptoServiceForStatus extends CryptoService {
  final bool _isInitialized;
  final bool _isUnlocked;

  FakeCryptoServiceForStatus({
    bool initialized = true,
    bool unlocked = true,
  })  : _isInitialized = initialized,
        _isUnlocked = unlocked;

  @override
  Future<bool> isInitialized() async => _isInitialized;

  @override
  bool get isUnlocked => _isUnlocked;
}

// ---------------------------------------------------------------------------
// Helpers for the device-local LLM config store.
// ---------------------------------------------------------------------------

/// In-memory persistence standing in for encrypted storage.
class _MemLlmPersistence implements LlmConfigPersistence {
  _MemLlmPersistence();

  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) {
    this.value = value;
    return Future.value();
  }
}

/// Direct client stub that records connection-test calls.
class _StubDirectClient extends LlmDirectClient {
  _StubDirectClient() : super();

  final List<String> models = [];

  @override
  Future<void> testConnection({
    required String baseUrl,
    required String apiKey,
    required String model,
  }) async {
    models.add(model);
  }
}

// ---------------------------------------------------------------------------
// Test database helper.
// ---------------------------------------------------------------------------
AppDatabase _createTestDatabase() {
  open.overrideFor(
    OperatingSystem.linux,
    () => DynamicLibrary.open('libsqlite3.so'),
  );
  sqlite3.tempDirectory = Directory.systemTemp.path;
  final file = File(
    '${Directory.systemTemp.path}/settings_test_${DateTime.now().millisecondsSinceEpoch}.sqlite',
  );
  return AppDatabase.forTesting(NativeDatabase(file));
}

// ===========================================================================
// Tests
// ===========================================================================

void main() {
  // =========================================================================
  // EncryptionStatus data class
  // =========================================================================

  group('EncryptionStatus', () {
    test('stores isInitialized and isUnlocked', () {
      const status = EncryptionStatus(isInitialized: true, isUnlocked: false);
      expect(status.isInitialized, isTrue);
      expect(status.isUnlocked, isFalse);
    });

    test('default false values', () {
      const status = EncryptionStatus(isInitialized: false, isUnlocked: false);
      expect(status.isInitialized, isFalse);
      expect(status.isUnlocked, isFalse);
    });

    test('both true when fully set up', () {
      const status = EncryptionStatus(isInitialized: true, isUnlocked: true);
      expect(status.isInitialized, isTrue);
      expect(status.isUnlocked, isTrue);
    });
  });

  // =========================================================================
  // EncryptionStatusNotifier
  // =========================================================================

  group('EncryptionStatusNotifier', () {
    test('loads initial status from CryptoService', () async {
      final crypto = FakeCryptoServiceForStatus(
        initialized: true,
        unlocked: true,
      );
      final notifier = EncryptionStatusNotifier(crypto);

      // Wait for the async _loadStatus to complete.
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.isInitialized, isTrue);
      expect(notifier.state.isUnlocked, isTrue);
    });

    test('reflects not initialized when crypto is not initialized', () async {
      final crypto = FakeCryptoServiceForStatus(
        initialized: false,
        unlocked: false,
      );
      final notifier = EncryptionStatusNotifier(crypto);

      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.isInitialized, isFalse);
      expect(notifier.state.isUnlocked, isFalse);
    });

    test('reflects initialized but locked state', () async {
      final crypto = FakeCryptoServiceForStatus(
        initialized: true,
        unlocked: false,
      );
      final notifier = EncryptionStatusNotifier(crypto);

      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.isInitialized, isTrue);
      expect(notifier.state.isUnlocked, isFalse);
    });

    test('refresh reloads status from CryptoService', () async {
      final crypto = FakeCryptoServiceForStatus(
        initialized: true,
        unlocked: true,
      );
      final notifier = EncryptionStatusNotifier(crypto);

      await Future<void>.delayed(Duration.zero);
      expect(notifier.state.isUnlocked, isTrue);

      // Simulate a change -- in real usage, the crypto service would be
      // locked externally. Here we test that refresh re-reads state.
      await notifier.refresh();

      expect(notifier.state.isInitialized, isTrue);
      expect(notifier.state.isUnlocked, isTrue);
    });
  });

  // =========================================================================
  // AiQuotaNotifier
  // =========================================================================

  group('AiQuotaNotifier', () {
    late MockApiClient mockApi;
    late ProviderContainer container;

    setUp(() {
      mockApi = MockApiClient();
      container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(mockApi),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('build fetches AI quota from API', () async {
      mockApi.aiQuotaResponse = {
        'plan': 'free',
        'daily_used': 25,
        'daily_limit': 200,
        'reset_at': DateTime.now().toUtc().toIso8601String(),
      };

      final result = await container.read(aiQuotaProvider.future);

      expect(result.dailyUsed, 25);
      expect(result.dailyLimit, 200);
    });

    test('refresh reloads quota from API', () async {
      // First load.
      final first = await container.read(aiQuotaProvider.future);
      expect(first.dailyUsed, 10);

      // Change the stub response.
      mockApi.aiQuotaResponse = {
        'plan': 'free',
        'daily_used': 50,
        'daily_limit': 200,
        'reset_at': DateTime.now().toUtc().toIso8601String(),
      };

      // Refresh.
      await container.read(aiQuotaProvider.notifier).refresh();
      final second = await container.read(aiQuotaProvider.future);

      expect(second.dailyUsed, 50);
    });

    test('build sets error state when API fails', () async {
      mockApi.aiQuotaError = Exception('Network error');

      // The async value should eventually become an error.
      await expectLater(
        container.read(aiQuotaProvider.future),
        throwsA(isA<Exception>()),
      );
    });

    test('refresh sets error state on failure', () async {
      // First load succeeds.
      await container.read(aiQuotaProvider.future);

      // Now API fails.
      mockApi.aiQuotaError = Exception('Server error');

      await container.read(aiQuotaProvider.notifier).refresh();

      await expectLater(
        container.read(aiQuotaProvider.future),
        throwsA(isA<Exception>()),
      );
    });
  });

  // =========================================================================
  // SyncStatusNotifier
  // =========================================================================

  group('SyncStatusNotifier', () {
    late MockApiClient mockApi;
    late ProviderContainer container;

    setUp(() {
      mockApi = MockApiClient();
      container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(mockApi),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('build fetches sync status from API', () async {
      mockApi.syncStatusResponse = {
        'latest_version': 99,
        'total_items': 150,
        'last_synced_at': DateTime.now().toUtc().toIso8601String(),
      };

      final result = await container.read(syncStatusProvider.future);

      expect(result.latestVersion, 99);
      expect(result.totalItems, 150);
    });

    test('refresh reloads sync status', () async {
      // First load.
      final first = await container.read(syncStatusProvider.future);
      expect(first.latestVersion, 42);

      // Change stub.
      mockApi.syncStatusResponse = {
        'latest_version': 55,
        'total_items': 160,
        'last_synced_at': DateTime.now().toUtc().toIso8601String(),
      };

      // Refresh.
      await container.read(syncStatusProvider.notifier).refresh();
      final second = await container.read(syncStatusProvider.future);

      expect(second.latestVersion, 55);
    });

    test('build sets error state when API fails', () async {
      mockApi.syncStatusError = Exception('Connection refused');

      await expectLater(
        container.read(syncStatusProvider.future),
        throwsA(isA<Exception>()),
      );
    });

    test('refresh sets error state on failure', () async {
      await container.read(syncStatusProvider.future);

      mockApi.syncStatusError = Exception('Timeout');

      await container.read(syncStatusProvider.notifier).refresh();

      await expectLater(
        container.read(syncStatusProvider.future),
        throwsA(isA<Exception>()),
      );
    });
  });

  // =========================================================================
  // AccountInfoNotifier
  // =========================================================================

  group('AccountInfoNotifier', () {
    late MockApiClient mockApi;
    late ProviderContainer container;

    setUp(() {
      mockApi = MockApiClient();
      container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(mockApi),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('build fetches account info from API', () async {
      mockApi.meResponse = {
        'id': 'user-abc',
        'email': 'alice@example.com',
        'username': 'alice',
        'plan': 'free',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      final result = await container.read(accountInfoProvider.future);

      expect(result.id, 'user-abc');
      expect(result.email, 'alice@example.com');
      expect(result.username, 'alice');
    });

    test('refresh reloads account info', () async {
      final first = await container.read(accountInfoProvider.future);
      expect(first.email, 'test@example.com');

      mockApi.meResponse = {
        'id': 'user-1',
        'email': 'updated@example.com',
        'username': 'testuser',
        'plan': 'free',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      await container.read(accountInfoProvider.notifier).refresh();
      final second = await container.read(accountInfoProvider.future);

      expect(second.email, 'updated@example.com');
    });

    test('build sets error state when API fails', () async {
      mockApi.meError = Exception('Unauthorized');

      await expectLater(
        container.read(accountInfoProvider.future),
        throwsA(isA<Exception>()),
      );
    });

    test('refresh sets error state on failure', () async {
      await container.read(accountInfoProvider.future);

      mockApi.meError = Exception('Server error');

      await container.read(accountInfoProvider.notifier).refresh();

      await expectLater(
        container.read(accountInfoProvider.future),
        throwsA(isA<Exception>()),
      );
    });
  });

  // =========================================================================
  // LlmConfigsNotifier (device-local store)
  // =========================================================================

  group('LlmConfigsNotifier', () {
    late _MemLlmPersistence persistence;
    late _StubDirectClient directClient;
    late ProviderContainer container;

    setUp(() {
      persistence = _MemLlmPersistence();
      directClient = _StubDirectClient();
      container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(MockApiClient()),
          localLlmStoreProvider.overrideWithValue(
            LocalLlmStore(persistence: persistence),
          ),
          llmDirectClientProvider.overrideWithValue(directClient),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    LlmConfig draftConfig({String name = 'A', bool isDefault = false}) =>
        LlmConfig(
          id: '',
          name: name,
          provider: 'openai',
          baseUrl: 'https://api.example.com/v1',
          apiKey: 'sk-test',
          model: 'gpt-4o',
          isDefault: isDefault,
          maxTokens: 4096,
          temperature: 0.7,
          createdAt: DateTime.utc(2024, 1, 1),
          updatedAt: DateTime.utc(2024, 1, 1),
        );

    test('build loads LLM configs from the local store', () async {
      final store = container.read(localLlmStoreProvider);
      await store.create(draftConfig(name: 'GPT-4'));

      final result = await container.read(llmConfigsProvider.future);

      expect(result, hasLength(1));
      expect(result.single.name, 'GPT-4');
      expect(result.single.isDefault, isTrue);
    });

    test('build returns an empty list when nothing is stored', () async {
      final result = await container.read(llmConfigsProvider.future);
      expect(result, isEmpty);
    });

    test('create assigns id/timestamps and the first config is default',
        () async {
      await container.read(llmConfigsProvider.future);

      await container.read(llmConfigsProvider.notifier).create({
        'name': 'Claude',
        'provider': 'anthropic',
        'base_url': 'https://api.anthropic.com/v1',
        'api_key': 'sk-ant',
        'model': 'claude-3',
      });

      final after = await container.read(llmConfigsProvider.future);
      expect(after, hasLength(1));
      expect(after.single.id, isNotEmpty);
      expect(after.single.isDefault, isTrue);
      expect(after.single.apiKey, 'sk-ant');
    });

    test('create keeps an existing default when adding another config',
        () async {
      await container.read(llmConfigsProvider.notifier).create({
        'name': 'First',
        'provider': 'openai',
        'model': 'gpt-4o',
      });
      await container.read(llmConfigsProvider.notifier).create({
        'name': 'Second',
        'provider': 'openai',
        'model': 'gpt-4o-mini',
      });

      final after = await container.read(llmConfigsProvider.future);
      expect(after.firstWhere((c) => c.name == 'First').isDefault, isTrue);
      expect(after.firstWhere((c) => c.name == 'Second').isDefault, isFalse);
    });

    test('updateConfig merges: empty strings and absent api key inherit', () async {
      final store = container.read(localLlmStoreProvider);
      final cfg = await store.create(
        draftConfig(name: 'Original').copyWith(baseUrl: 'https://old.example.com'),
      );
      await container.read(llmConfigsProvider.future);

      await container.read(llmConfigsProvider.notifier).updateConfig(cfg.id, {
        'name': 'Renamed',
        'base_url': '',
        'model': '',
        // no api_key: the stored key must survive
      });

      final after = await container.read(llmConfigsProvider.future);
      expect(after.single.name, 'Renamed');
      expect(after.single.baseUrl, 'https://old.example.com');
      expect(after.single.model, 'gpt-4o');
      expect(after.single.apiKey, 'sk-test');
    });

    test('updateConfig replaces the API key when a new one is provided',
        () async {
      final store = container.read(localLlmStoreProvider);
      final cfg = await store.create(draftConfig());
      await container.read(llmConfigsProvider.future);

      await container.read(llmConfigsProvider.notifier).updateConfig(cfg.id, {
        'api_key': 'sk-new',
      });

      final after = await container.read(llmConfigsProvider.future);
      expect(after.single.apiKey, 'sk-new');
      // Untouched fields stay intact.
      expect(after.single.name, 'A');
    });

    test('setDefault marks one config as the only default', () async {
      await container.read(llmConfigsProvider.notifier).create({
        'name': 'First',
        'provider': 'openai',
        'model': 'gpt-4o',
      });
      await container.read(llmConfigsProvider.notifier).create({
        'name': 'Second',
        'provider': 'openai',
        'model': 'gpt-4o-mini',
      });
      final configs = await container.read(llmConfigsProvider.future);
      final secondId = configs.firstWhere((c) => c.name == 'Second').id;

      await container.read(llmConfigsProvider.notifier).setDefault(secondId);

      final after = await container.read(llmConfigsProvider.future);
      expect(after.firstWhere((c) => c.name == 'First').isDefault, isFalse);
      expect(after.firstWhere((c) => c.name == 'Second').isDefault, isTrue);
    });

    test('delete removes the config from the local store', () async {
      final store = container.read(localLlmStoreProvider);
      final cfg = await store.create(draftConfig());
      await container.read(llmConfigsProvider.future);

      await container.read(llmConfigsProvider.notifier).delete(cfg.id);

      final after = await container.read(llmConfigsProvider.future);
      expect(after, isEmpty);
    });

    test('test performs a client-direct connection test', () async {
      final store = container.read(localLlmStoreProvider);
      final cfg = await store.create(draftConfig());
      await container.read(llmConfigsProvider.future);

      await container.read(llmConfigsProvider.notifier).test(cfg.id);

      expect(directClient.models, ['gpt-4o']);
    });

    test('refresh re-reads the local store', () async {
      final first = await container.read(llmConfigsProvider.future);
      expect(first, isEmpty);

      final store = container.read(localLlmStoreProvider);
      await store.create(draftConfig(name: 'Late'));

      await container.read(llmConfigsProvider.notifier).refresh();
      final second = await container.read(llmConfigsProvider.future);

      expect(second, hasLength(1));
      expect(second.single.name, 'Late');
    });

    test('build tolerates a corrupt stored payload', () async {
      persistence.value = '{corrupt';

      final result = await container.read(llmConfigsProvider.future);

      expect(result, isEmpty);
    });
  });

  // =========================================================================
  // llmProvidersProvider
  // =========================================================================

  group('llmProvidersProvider', () {
    late MockApiClient mockApi;
    late ProviderContainer container;

    setUp(() {
      mockApi = MockApiClient();
      container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(mockApi),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('fetches provider names from API', () async {
      mockApi.llmProvidersResponse = ['OpenAI', 'DeepSeek', 'Anthropic'];

      final result = await container.read(llmProvidersProvider.future);

      expect(result, ['OpenAI', 'DeepSeek', 'Anthropic']);
    });

    test('returns empty list when no providers', () async {
      mockApi.llmProvidersResponse = [];

      final result = await container.read(llmProvidersProvider.future);

      expect(result, isEmpty);
    });
  });

  // =========================================================================
  // PlatformsNotifier
  // =========================================================================

  group('PlatformsNotifier', () {
    late MockApiClient mockApi;
    late ProviderContainer container;

    setUp(() {
      mockApi = MockApiClient();
      container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(mockApi),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('build fetches platforms from API', () async {
      mockApi.platformsResponse = [
        {
          'id': 'p-1',
          'platform': 'xhs',
          'status': 'connected',
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        {
          'id': 'p-2',
          'platform': 'weibo',
          'status': 'disconnected',
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
      ];

      final result = await container.read(platformsProvider.future);

      expect(result.length, 2);
      expect(result[0].platform, 'xhs');
      expect(result[1].isConnected, isFalse);
    });

    test('build returns empty list when no platforms', () async {
      mockApi.platformsResponse = [];

      final result = await container.read(platformsProvider.future);

      expect(result, isEmpty);
    });

    test('connect calls API and invalidates self', () async {
      mockApi.platformsResponse = [];

      await container.read(platformsProvider.future);

      final result = await container.read(platformsProvider.notifier).connect(
            'xhs',
          );

      expect(mockApi.connectPlatformCalls, ['xhs']);
      expect(result['status'], 'connected');
    });

    test('disconnect calls API and invalidates self', () async {
      await container.read(platformsProvider.future);

      await container.read(platformsProvider.notifier).disconnect('xhs');

      expect(mockApi.disconnectPlatformCalls, ['xhs']);
    });

    test('verify calls API and returns result', () async {
      final result = await container.read(platformsProvider.notifier).verify(
            'xhs',
          );

      expect(mockApi.verifyPlatformCalls, ['xhs']);
      expect(result['verified'], isTrue);
    });

    test('refresh invalidates self to trigger reload', () async {
      final ts = DateTime.now().toUtc().toIso8601String();
      mockApi.platformsResponse = [
        {
          'id': 'p-1',
          'platform': 'xhs',
          'status': 'disconnected',
          'created_at': ts,
          'updated_at': ts,
        },
      ];

      final first = await container.read(platformsProvider.future);
      expect(first.length, 1);

      mockApi.platformsResponse = [
        {
          'id': 'p-1',
          'platform': 'xhs',
          'status': 'connected',
          'created_at': ts,
          'updated_at': ts,
        },
        {
          'id': 'p-2',
          'platform': 'weibo',
          'status': 'connected',
          'created_at': ts,
          'updated_at': ts,
        },
      ];

      await container.read(platformsProvider.notifier).refresh();
      final second = await container.read(platformsProvider.future);

      expect(second.length, 2);
    });

    test('build sets error state when API fails', () async {
      mockApi.listPlatformsError = Exception('Server error');

      await expectLater(
        container.read(platformsProvider.future),
        throwsA(isA<Exception>()),
      );
    });

    test('connect propagates API error', () async {
      await container.read(platformsProvider.future);

      mockApi.connectPlatformError = Exception('Connection failed');

      expect(
        () => container.read(platformsProvider.notifier).connect('xhs'),
        throwsA(isA<Exception>()),
      );
    });
  });

  // =========================================================================
  // LocalItemCountsNotifier
  // =========================================================================

  group('LocalItemCountsNotifier', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() async {
      db = _createTestDatabase();
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
      );

      // Seed: 3 notes (1 soft-deleted), 2 tags, 1 collection, 2 AI contents.
      await db.notesDao.createNote(
        id: 'note-1',
        encryptedContent: 'enc1',
        plainContent: 'Note one',
        plainTitle: 'Title One',
      );
      await db.notesDao.createNote(
        id: 'note-2',
        encryptedContent: 'enc2',
        plainContent: 'Note two',
        plainTitle: 'Title Two',
      );
      await db.notesDao.createNote(
        id: 'note-3',
        encryptedContent: 'enc3',
        plainContent: 'Note three',
        plainTitle: 'Title Three',
      );
      // Soft-delete note-3.
      await db.notesDao.softDeleteNote('note-3');

      await db.tagsDao.createTag(
        id: 'tag-1',
        encryptedName: 'enc-tag1',
        plainName: 'Work',
      );
      await db.tagsDao.createTag(
        id: 'tag-2',
        encryptedName: 'enc-tag2',
        plainName: 'Personal',
      );

      await db.collectionsDao.createCollection(
        id: 'col-1',
        encryptedTitle: 'enc-col1',
        plainTitle: 'Archive',
      );

      await db.generatedContentsDao.create(
        id: 'gc-1',
        encryptedBody: 'enc-gc1',
        plainBody: 'Generated content one',
      );
      await db.generatedContentsDao.create(
        id: 'gc-2',
        encryptedBody: 'enc-gc2',
        plainBody: 'Generated content two',
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('counts non-deleted notes, tags, collections, and AI content',
        () async {
      final counts = await container.read(localItemCountsProvider.future);

      // note-3 is soft-deleted, so only 2 active notes.
      expect(counts['notes'], 2);
      expect(counts['tags'], 2);
      expect(counts['collections'], 1);
      expect(counts['ai_content'], 2);
    });

    test('returns zero for all categories when DB is empty', () async {
      // Use a fresh empty database.
      final emptyDb = _createTestDatabase();
      addTearDown(() async => await emptyDb.close());

      final emptyContainer = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(emptyDb),
        ],
      );
      addTearDown(() => emptyContainer.dispose());

      final counts = await emptyContainer.read(localItemCountsProvider.future);

      expect(counts['notes'], 0);
      expect(counts['tags'], 0);
      expect(counts['collections'], 0);
      expect(counts['ai_content'], 0);
    });

    test('refresh invalidates self to trigger reload', () async {
      // First read.
      final first = await container.read(localItemCountsProvider.future);
      expect(first['notes'], 2);

      // Add a new note.
      await db.notesDao.createNote(
        id: 'note-new',
        encryptedContent: 'enc-new',
        plainContent: 'New note',
        plainTitle: 'New Title',
      );

      // Refresh.
      await container.read(localItemCountsProvider.notifier).refresh();

      // Wait for the invalidated provider to rebuild.
      final second = await container.read(localItemCountsProvider.future);
      expect(second['notes'], 3);
    });
  });

  // =========================================================================
  // encryptionStatusProvider (Riverpod integration)
  // =========================================================================

  group('encryptionStatusProvider', () {
    late ProviderContainer container;

    tearDown(() {
      container.dispose();
    });

    test('provides EncryptionStatusNotifier with injected CryptoService', () {
      final crypto = FakeCryptoServiceForStatus(
        initialized: true,
        unlocked: true,
      );

      container = ProviderContainer(
        overrides: [
          cryptoServiceProvider.overrideWithValue(crypto),
        ],
      );

      final status = container.read(encryptionStatusProvider);
      // The initial state is set synchronously before _loadStatus completes.
      expect(status.isInitialized, isFalse);
      expect(status.isUnlocked, isFalse);
    });

    test('updates state after async _loadStatus completes', () async {
      final crypto = FakeCryptoServiceForStatus(
        initialized: true,
        unlocked: true,
      );

      container = ProviderContainer(
        overrides: [
          cryptoServiceProvider.overrideWithValue(crypto),
        ],
      );

      // Read the provider to trigger StateNotifier construction and start
      // the async _loadStatus() call.
      container.read(encryptionStatusProvider);

      // Wait for async _loadStatus to complete. The StateNotifier constructor
      // calls _loadStatus() which awaits isInitialized(), so we need to pump
      // the event loop until the async operation completes.
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      final status = container.read(encryptionStatusProvider);
      expect(status.isInitialized, isTrue);
      expect(status.isUnlocked, isTrue);
    });
  });

  // =========================================================================
  // recoveryKeyProvider
  // =========================================================================

  group('recoveryKeyProvider', () {
    test('can be created without throwing', () {
      // This provider reads from flutter_secure_storage which we cannot
      // easily mock in a unit test without widget setup. Just verify the
      // provider reference is valid.
      final container = ProviderContainer();
      addTearDown(() => container.dispose());

      // Reading the provider should not throw synchronously.
      expect(
        () => container.read(recoveryKeyProvider),
        returnsNormally,
      );
    });
  });
}
