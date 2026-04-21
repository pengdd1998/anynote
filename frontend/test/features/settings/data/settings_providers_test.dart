import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:anynote/core/crypto/crypto_service.dart';
import 'package:anynote/core/database/app_database.dart';
import 'package:anynote/core/network/api_client.dart';
import 'package:anynote/features/settings/data/settings_providers.dart';
import 'package:anynote/main.dart'
    show apiClientProvider, cryptoServiceProvider, databaseProvider;

// ---------------------------------------------------------------------------
// Mock ApiClient that records calls and returns preset responses.
// ---------------------------------------------------------------------------
class MockApiClient extends ApiClient {
  // Response stubs -- set before running tests.
  Map<String, dynamic> aiQuotaResponse = {'used': 10, 'limit': 100};
  Map<String, dynamic> syncStatusResponse = {'latest_version': 42};
  Map<String, dynamic> meResponse = {
    'id': 'user-1',
    'email': 'test@example.com',
  };
  List<Map<String, dynamic>> llmConfigsResponse = [];
  List<String> llmProvidersResponse = ['OpenAI', 'DeepSeek'];
  List<Map<String, dynamic>> platformsResponse = [];
  Map<String, dynamic> connectPlatformResponse = {'status': 'connected'};
  Map<String, dynamic> verifyPlatformResponse = {'verified': true};

  // Call records.
  final List<String> createLlmConfigCalls = [];
  final List<(String, Map<String, dynamic>)> updateLlmConfigCalls = [];
  final List<String> deleteLlmConfigCalls = [];
  final List<String> testLlmConfigCalls = [];
  final List<String> connectPlatformCalls = [];
  final List<String> disconnectPlatformCalls = [];
  final List<String> verifyPlatformCalls = [];

  // Error injection -- set to throw on next call.
  Object? aiQuotaError;
  Object? syncStatusError;
  Object? meError;
  Object? llmConfigsError;
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
  Future<List<Map<String, dynamic>>> listLlmConfigs() async {
    if (llmConfigsError != null) throw llmConfigsError!;
    return llmConfigsResponse;
  }

  @override
  Future<Map<String, dynamic>> createLlmConfig(Map<String, dynamic> config) async {
    createLlmConfigCalls.add(config['name'] ?? config.toString());
    return {'id': 'cfg-new', ...config};
  }

  @override
  Future<Map<String, dynamic>> updateLlmConfig(
    String id,
    Map<String, dynamic> config,
  ) async {
    updateLlmConfigCalls.add((id, config));
    return {'id': id, ...config};
  }

  @override
  Future<void> deleteLlmConfig(String id) async {
    deleteLlmConfigCalls.add(id);
  }

  @override
  Future<Map<String, dynamic>> testLlmConfig(String id) async {
    testLlmConfigCalls.add(id);
    return {'success': true};
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
      mockApi.aiQuotaResponse = {'used': 25, 'limit': 200};

      final result = await container.read(aiQuotaProvider).future;

      expect(result['used'], 25);
      expect(result['limit'], 200);
    });

    test('refresh reloads quota from API', () async {
      // First load.
      final first = await container.read(aiQuotaProvider).future;
      expect(first['used'], 10);

      // Change the stub response.
      mockApi.aiQuotaResponse = {'used': 50, 'limit': 200};

      // Refresh.
      await container.read(aiQuotaProvider.notifier).refresh();
      final second = await container.read(aiQuotaProvider).future;

      expect(second['used'], 50);
    });

    test('build sets error state when API fails', () async {
      mockApi.aiQuotaError = Exception('Network error');

      // The async value should eventually become an error.
      await expectLater(
        container.read(aiQuotaProvider).future,
        throwsA(isA<Exception>()),
      );
    });

    test('refresh sets error state on failure', () async {
      // First load succeeds.
      await container.read(aiQuotaProvider).future;

      // Now API fails.
      mockApi.aiQuotaError = Exception('Server error');

      await container.read(aiQuotaProvider.notifier).refresh();

      await expectLater(
        container.read(aiQuotaProvider).future,
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
        'item_count': 150,
      };

      final result = await container.read(syncStatusProvider).future;

      expect(result['latest_version'], 99);
      expect(result['item_count'], 150);
    });

    test('refresh reloads sync status', () async {
      // First load.
      final first = await container.read(syncStatusProvider).future;
      expect(first['latest_version'], 42);

      // Change stub.
      mockApi.syncStatusResponse = {'latest_version': 55};

      // Refresh.
      await container.read(syncStatusProvider.notifier).refresh();
      final second = await container.read(syncStatusProvider).future;

      expect(second['latest_version'], 55);
    });

    test('build sets error state when API fails', () async {
      mockApi.syncStatusError = Exception('Connection refused');

      await expectLater(
        container.read(syncStatusProvider).future,
        throwsA(isA<Exception>()),
      );
    });

    test('refresh sets error state on failure', () async {
      await container.read(syncStatusProvider).future;

      mockApi.syncStatusError = Exception('Timeout');

      await container.read(syncStatusProvider.notifier).refresh();

      await expectLater(
        container.read(syncStatusProvider).future,
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
      };

      final result = await container.read(accountInfoProvider).future;

      expect(result['id'], 'user-abc');
      expect(result['email'], 'alice@example.com');
      expect(result['username'], 'alice');
    });

    test('refresh reloads account info', () async {
      final first = await container.read(accountInfoProvider).future;
      expect(first['email'], 'test@example.com');

      mockApi.meResponse = {
        'id': 'user-1',
        'email': 'updated@example.com',
      };

      await container.read(accountInfoProvider.notifier).refresh();
      final second = await container.read(accountInfoProvider).future;

      expect(second['email'], 'updated@example.com');
    });

    test('build sets error state when API fails', () async {
      mockApi.meError = Exception('Unauthorized');

      await expectLater(
        container.read(accountInfoProvider).future,
        throwsA(isA<Exception>()),
      );
    });

    test('refresh sets error state on failure', () async {
      await container.read(accountInfoProvider).future;

      mockApi.meError = Exception('Server error');

      await container.read(accountInfoProvider.notifier).refresh();

      await expectLater(
        container.read(accountInfoProvider).future,
        throwsA(isA<Exception>()),
      );
    });
  });

  // =========================================================================
  // LlmConfigsNotifier
  // =========================================================================

  group('LlmConfigsNotifier', () {
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

    test('build fetches LLM configs from API', () async {
      mockApi.llmConfigsResponse = [
        {'id': 'cfg-1', 'name': 'GPT-4', 'provider': 'OpenAI'},
        {'id': 'cfg-2', 'name': 'DeepSeek Chat', 'provider': 'DeepSeek'},
      ];

      final result = await container.read(llmConfigsProvider).future;

      expect(result.length, 2);
      expect(result[0]['name'], 'GPT-4');
      expect(result[1]['provider'], 'DeepSeek');
    });

    test('build returns empty list when no configs', () async {
      mockApi.llmConfigsResponse = [];

      final result = await container.read(llmConfigsProvider).future;

      expect(result, isEmpty);
    });

    test('create calls API and invalidates self', () async {
      mockApi.llmConfigsResponse = [];

      // Initial load.
      await container.read(llmConfigsProvider).future;

      // Create a new config.
      final newConfig = {'name': 'Claude', 'provider': 'Anthropic'};
      await container.read(llmConfigsProvider.notifier).create(newConfig);

      expect(mockApi.createLlmConfigCalls, ['Claude']);
    });

    test('updateConfig calls API and invalidates self', () async {
      await container.read(llmConfigsProvider).future;

      final updatedConfig = {'name': 'Updated GPT-4'};
      await container.read(llmConfigsProvider.notifier).updateConfig(
        'cfg-1',
        updatedConfig,
      );

      expect(mockApi.updateLlmConfigCalls.length, 1);
      expect(mockApi.updateLlmConfigCalls.first.$1, 'cfg-1');
    });

    test('delete calls API and invalidates self', () async {
      await container.read(llmConfigsProvider).future;

      await container.read(llmConfigsProvider.notifier).delete('cfg-1');

      expect(mockApi.deleteLlmConfigCalls, ['cfg-1']);
    });

    test('test calls API and returns result', () async {
      final result = await container.read(llmConfigsProvider.notifier).test(
        'cfg-1',
      );

      expect(mockApi.testLlmConfigCalls, ['cfg-1']);
      expect(result['success'], isTrue);
    });

    test('refresh invalidates self to trigger reload', () async {
      mockApi.llmConfigsResponse = [
        {'id': 'cfg-1', 'name': 'Old Config'},
      ];

      final first = await container.read(llmConfigsProvider).future;
      expect(first.length, 1);

      // Update stub and refresh.
      mockApi.llmConfigsResponse = [
        {'id': 'cfg-1', 'name': 'Old Config'},
        {'id': 'cfg-2', 'name': 'New Config'},
      ];

      await container.read(llmConfigsProvider.notifier).refresh();
      final second = await container.read(llmConfigsProvider).future;

      expect(second.length, 2);
    });

    test('build sets error state when API fails', () async {
      mockApi.llmConfigsError = Exception('Server error');

      await expectLater(
        container.read(llmConfigsProvider).future,
        throwsA(isA<Exception>()),
      );
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

      final result = await container.read(llmProvidersProvider).future;

      expect(result, ['OpenAI', 'DeepSeek', 'Anthropic']);
    });

    test('returns empty list when no providers', () async {
      mockApi.llmProvidersResponse = [];

      final result = await container.read(llmProvidersProvider).future;

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
        {'platform': 'xhs', 'connected': true},
        {'platform': 'weibo', 'connected': false},
      ];

      final result = await container.read(platformsProvider).future;

      expect(result.length, 2);
      expect(result[0]['platform'], 'xhs');
      expect(result[1]['connected'], isFalse);
    });

    test('build returns empty list when no platforms', () async {
      mockApi.platformsResponse = [];

      final result = await container.read(platformsProvider).future;

      expect(result, isEmpty);
    });

    test('connect calls API and invalidates self', () async {
      mockApi.platformsResponse = [];

      await container.read(platformsProvider).future;

      final result = await container.read(platformsProvider.notifier).connect(
        'xhs',
      );

      expect(mockApi.connectPlatformCalls, ['xhs']);
      expect(result['status'], 'connected');
    });

    test('disconnect calls API and invalidates self', () async {
      await container.read(platformsProvider).future;

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
      mockApi.platformsResponse = [
        {'platform': 'xhs', 'connected': false},
      ];

      final first = await container.read(platformsProvider).future;
      expect(first.length, 1);

      mockApi.platformsResponse = [
        {'platform': 'xhs', 'connected': true},
        {'platform': 'weibo', 'connected': true},
      ];

      await container.read(platformsProvider.notifier).refresh();
      final second = await container.read(platformsProvider).future;

      expect(second.length, 2);
    });

    test('build sets error state when API fails', () async {
      mockApi.listPlatformsError = Exception('Server error');

      await expectLater(
        container.read(platformsProvider).future,
        throwsA(isA<Exception>()),
      );
    });

    test('connect propagates API error', () async {
      await container.read(platformsProvider).future;

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
      final counts = await container.read(localItemCountsProvider).future;

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

      final counts =
          await emptyContainer.read(localItemCountsProvider).future;

      expect(counts['notes'], 0);
      expect(counts['tags'], 0);
      expect(counts['collections'], 0);
      expect(counts['ai_content'], 0);
    });

    test('refresh invalidates self to trigger reload', () async {
      // First read.
      final first = await container.read(localItemCountsProvider).future;
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
      final second = await container.read(localItemCountsProvider).future;
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

      // Wait for async _loadStatus to complete.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

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
