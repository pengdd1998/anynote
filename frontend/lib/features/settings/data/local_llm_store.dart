import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/storage/app_secure_storage.dart';
import 'api_models.dart';

/// Persistence contract for [LocalLlmStore].
///
/// Abstracted so tests can inject an in-memory backend instead of the real
/// encrypted storage (which requires a platform channel).
abstract class LlmConfigPersistence {
  /// Reads the raw JSON payload, or null when nothing was stored yet.
  Future<String?> read();

  /// Writes the raw JSON payload.
  Future<void> write(String value);
}

/// Device-local store for user LLM configurations (including API keys).
///
/// Privacy: configs are persisted ONLY in the device's encrypted shared
/// preferences and are NEVER uploaded to the AnyNote server. AI calls with a
/// local config go directly from the client to the LLM provider; the server
/// proxy is only the shared-mode fallback when no local config exists.
class LocalLlmStore {
  LocalLlmStore({LlmConfigPersistence? persistence})
      : persistence = persistence ?? const SecureLlmPersistence();

  /// Storage key in [AppSecureStorage] holding the JSON list of configs.
  static const String storageKey = 'local_llm_configs';

  final LlmConfigPersistence persistence;

  /// Loads all locally stored configs.
  ///
  /// Missing key -> empty list; a corrupt payload is tolerated as empty
  /// rather than crashing the app (the user can simply re-add configs).
  Future<List<LlmConfig>> load() async {
    try {
      final raw = await persistence.read();
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((e) => LlmConfig.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      // Corrupt JSON or unreadable payload: start from an empty list.
      return const [];
    }
  }

  /// Persists the full config list (including API keys) to encrypted storage.
  Future<void> save(List<LlmConfig> configs) {
    final encoded = jsonEncode(configs.map((c) => c.toJson()).toList());
    return persistence.write(encoded);
  }

  /// Creates [draft] in the store, assigning a fresh id (uuid) and timestamps.
  ///
  /// If no stored config is flagged as default, the new config becomes the
  /// default (first config is default). Returns the stored config.
  Future<LlmConfig> create(LlmConfig draft) async {
    final configs = await load();
    final now = DateTime.now().toUtc();
    var cfg = draft.copyWith(
      id: const Uuid().v4(),
      createdAt: now,
      updatedAt: now,
    );
    final hasDefault = configs.any((c) => c.isDefault);
    if (!cfg.isDefault && !hasDefault) {
      cfg = cfg.copyWith(isDefault: true);
    }
    // Enforce a single default.
    await save([
      for (final c in configs)
        if (cfg.isDefault) c.copyWith(isDefault: false) else c,
      cfg,
    ]);
    return cfg;
  }

  /// Updates an existing config matched by [LlmConfig.id].
  ///
  /// Never wipes a stored API key: when [cfg.apiKey] is null or empty, the
  /// previously stored key is kept (the edit dialog only sends a key when the
  /// user re-enters one). If [cfg.isDefault] is true, the default flag is
  /// cleared on all other configs.
  Future<void> update(LlmConfig cfg) async {
    final configs = await load();
    final index = configs.indexWhere((c) => c.id == cfg.id);
    if (index < 0) {
      throw StateError('LLM config not found: ${cfg.id}');
    }
    final updated = (cfg.apiKey == null || cfg.apiKey!.isEmpty)
        ? cfg.copyWith(apiKey: configs[index].apiKey)
        : cfg;
    if (updated.isDefault) {
      await save([
        for (final c in configs)
          c.id == cfg.id ? updated : c.copyWith(isDefault: false),
      ]);
    } else {
      configs[index] = updated;
      await save(configs);
    }
  }

  /// Deletes the config with [id].
  ///
  /// If the deleted config was the default, the first remaining config is
  /// promoted so direct AI calls keep working.
  Future<void> delete(String id) async {
    final configs = await load();
    final remaining = configs.where((c) => c.id != id).toList();
    if (remaining.length == configs.length) return;
    final wasDefault = configs.any((c) => c.id == id && c.isDefault);
    if (wasDefault &&
        remaining.isNotEmpty &&
        !remaining.any((c) => c.isDefault)) {
      remaining[0] = remaining[0].copyWith(isDefault: true);
    }
    await save(remaining);
  }

  /// Marks [id] as the only default config.
  Future<void> setDefault(String id) async {
    final configs = await load();
    if (!configs.any((c) => c.id == id)) {
      throw StateError('LLM config not found: $id');
    }
    await save([
      for (final c in configs) c.copyWith(isDefault: c.id == id),
    ]);
  }

  /// The default config, or null when none is flagged as default.
  Future<LlmConfig?> getDefault() async {
    for (final c in await load()) {
      if (c.isDefault) return c;
    }
    return null;
  }

  /// The stored API key for [id], or null when the config does not exist.
  Future<String?> getStoredApiKey(String id) async {
    for (final c in await load()) {
      if (c.id == id) return c.apiKey;
    }
    return null;
  }
}

/// Default persistence backend: the app's encrypted shared preferences.
class SecureLlmPersistence implements LlmConfigPersistence {
  const SecureLlmPersistence();

  @override
  Future<String?> read() =>
      AppSecureStorage.instance.read(key: LocalLlmStore.storageKey);

  @override
  Future<void> write(String value) =>
      AppSecureStorage.instance.write(key: LocalLlmStore.storageKey, value: value);
}

/// Provides the device-local LLM config store.
final localLlmStoreProvider = Provider<LocalLlmStore>((ref) => LocalLlmStore());
