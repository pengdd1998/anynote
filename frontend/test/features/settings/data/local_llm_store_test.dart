import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/settings/data/api_models.dart';
import 'package:anynote/features/settings/data/local_llm_store.dart';

/// In-memory persistence backend standing in for encrypted storage.
class _InMemoryPersistence implements LlmConfigPersistence {
  String? value;
  int writes = 0;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) {
    this.value = value;
    writes++;
    return Future.value();
  }
}

LlmConfig _config({
  String id = '',
  String name = 'OpenAI',
  String? apiKey = 'sk-test',
  String? baseUrl = 'https://api.example.com/v1',
  String model = 'gpt-4o',
  bool isDefault = false,
}) =>
    LlmConfig(
      id: id,
      name: name,
      provider: 'openai',
      baseUrl: baseUrl,
      apiKey: apiKey,
      model: model,
      isDefault: isDefault,
      maxTokens: 4096,
      temperature: 0.7,
      createdAt: DateTime.utc(2024, 1, 1),
      updatedAt: DateTime.utc(2024, 1, 1),
    );

void main() {
  group('LocalLlmStore', () {
    late _InMemoryPersistence persistence;
    late LocalLlmStore store;

    setUp(() {
      persistence = _InMemoryPersistence();
      store = LocalLlmStore(persistence: persistence);
    });
    group('load', () {
      test('missing key yields an empty list', () async {
        expect(await store.load(), isEmpty);
      });

      test('corrupt JSON is tolerated as an empty list', () async {
        persistence.value = '{not valid json';
        expect(await store.load(), isEmpty);
      });

      test('non-list JSON payload is tolerated as an empty list', () async {
        persistence.value = '{"unexpected": "object"}';
        expect(await store.load(), isEmpty);
      });

      test('round-trips saved configs including the API key', () async {
        await store.create(_config(name: 'A', apiKey: 'sk-a'));
        final loaded = await store.load();

        expect(loaded, hasLength(1));
        expect(loaded.single.name, 'A');
        expect(loaded.single.apiKey, 'sk-a');
        expect(loaded.single.baseUrl, 'https://api.example.com/v1');
        expect(loaded.single.model, 'gpt-4o');
      });
    });

    group('create', () {
      test('assigns id and timestamps', () async {
        final cfg = await store.create(_config());

        expect(cfg.id, isNotEmpty);
        expect(cfg.createdAt.year, greaterThanOrEqualTo(2024));
        expect(cfg.updatedAt, cfg.createdAt);
        expect(await store.getStoredApiKey(cfg.id), 'sk-test');
      });

      test('first config automatically becomes the default', () async {
        final cfg = await store.create(_config());
        expect(cfg.isDefault, isTrue);
        expect((await store.getDefault())?.id, cfg.id);
      });

      test('second config does not steal the default flag', () async {
        final first = await store.create(_config(name: 'A'));
        final second = await store.create(_config(name: 'B'));

        expect(second.isDefault, isFalse);
        expect((await store.getDefault())?.id, first.id);
      });

      test('explicit default clears the default on stored configs', () async {
        final first = await store.create(_config(name: 'A'));
        final second = await store.create(_config(name: 'B', isDefault: true));

        expect(second.isDefault, isTrue);
        final reloaded = await store.load();
        expect(
          reloaded.firstWhere((c) => c.id == first.id).isDefault,
          isFalse,
        );
        expect((await store.getDefault())?.id, second.id);
      });
    });

    group('update', () {
      test('replaces fields by id', () async {
        final cfg = await store.create(_config(name: 'A'));

        await store.update(
          cfg.copyWith(name: 'Renamed', model: 'gpt-4o-mini'),
        );

        final reloaded = await store.load();
        expect(reloaded.single.name, 'Renamed');
        expect(reloaded.single.model, 'gpt-4o-mini');
        // Not touched fields stay intact.
        expect(reloaded.single.apiKey, 'sk-test');
        expect(reloaded.single.isDefault, isTrue);
      });

      test('never wipes the stored API key when none is provided', () async {
        final cfg = await store.create(_config());

        await store.update(cfg.copyWith(apiKey: null));

        expect(await store.getStoredApiKey(cfg.id), 'sk-test');

        // An explicitly provided key does replace the stored one.
        await store.update(cfg.copyWith(apiKey: 'sk-new'));
        expect(await store.getStoredApiKey(cfg.id), 'sk-new');
      });

      test('clears the default flag on others when flagged default',
          () async {
        final first = await store.create(_config(name: 'A'));
        final second = await store.create(_config(name: 'B'));

        await store.update(second.copyWith(isDefault: true));

        final reloaded = await store.load();
        expect(
          reloaded.firstWhere((c) => c.id == first.id).isDefault,
          isFalse,
        );
        expect(reloaded.firstWhere((c) => c.id == second.id).isDefault, isTrue);
      });

      test('throws for an unknown id', () async {
        await expectLater(
          store.update(_config(id: 'missing', name: 'X')),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('delete', () {
      test('removes the config', () async {
        final cfg = await store.create(_config());

        await store.delete(cfg.id);

        expect(await store.load(), isEmpty);
      });

      test('promotes the first remaining config when the default is deleted',
          () async {
        final first = await store.create(_config(name: 'A'));
        final second = await store.create(_config(name: 'B'));

        await store.delete(first.id);

        final reloaded = await store.load();
        expect(reloaded, hasLength(1));
        expect(reloaded.single.id, second.id);
        // Direct AI calls keep working: a default still exists.
        expect(reloaded.single.isDefault, isTrue);
      });

      test('deleting an unknown id is a no-op', () async {
        await store.create(_config());
        await store.delete('missing');
        expect(await store.load(), hasLength(1));
      });
    });

    group('setDefault', () {
      test('marks one config as the only default', () async {
        final first = await store.create(_config(name: 'A'));
        final second = await store.create(_config(name: 'B'));
        expect((await store.getDefault())?.id, first.id);

        await store.setDefault(second.id);

        final reloaded = await store.load();
        expect(
          reloaded.firstWhere((c) => c.id == first.id).isDefault,
          isFalse,
        );
        expect(
          reloaded.firstWhere((c) => c.id == second.id).isDefault,
          isTrue,
        );
        expect((await store.getDefault())?.id, second.id);
      });

      test('throws for an unknown id', () async {
        await expectLater(
          store.setDefault('missing'),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('getDefault', () {
      test('returns null when no config is flagged default', () async {
        final cfg = await store.create(_config());
        await store.setDefault(cfg.id);
        // Force-clear via a raw payload write.
        final raw = jsonDecode(persistence.value!) as List;
        persistence.value = jsonEncode([
          for (final e in raw) {...(e as Map), 'is_default': false},
        ]);

        expect(await store.getDefault(), isNull);
      });
    });

    group('getStoredApiKey', () {
      test('returns null for an unknown id', () async {
        expect(await store.getStoredApiKey('missing'), isNull);
      });
    });
  });
}
