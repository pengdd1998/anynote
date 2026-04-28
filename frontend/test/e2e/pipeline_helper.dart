// Shared infrastructure for full-pipeline E2E tests that exercise real
// libsodium crypto + real Drift database + real SyncEngine with a mock API.
//
// This module provides:
// - Sodium initialization for the test runner
// - In-memory Drift database factory
// - Real CryptoService with injected test keys
// - MockSyncApiClient that captures push requests and serves pull responses

import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sodium_libs/sodium_libs_sumo.dart';

import 'package:anynote/core/crypto/crypto_service.dart';
import 'package:anynote/core/crypto/encryptor.dart';
import 'package:anynote/core/database/app_database.dart';
import 'package:anynote/core/network/api_client.dart';
import 'package:anynote/core/sync/sync_engine.dart';

import '../core/crypto/sodium_test_init.dart';

// ---------------------------------------------------------------------------
// Sodium initialization
// ---------------------------------------------------------------------------

/// Whether sodium has been initialized for this test process.
bool _sodiumInitialized = false;

/// Initialize libsodium for the test runner.
///
/// Call this in `setUpAll` once per test group. It is safe to call multiple
/// times; subsequent calls are no-ops.
Future<void> initSodium() async {
  if (_sodiumInitialized) return;
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  registerTestSodiumPlatform();
  await SodiumSumoInit.init();
  _sodiumInitialized = true;
}

// ---------------------------------------------------------------------------
// Database factory
// ---------------------------------------------------------------------------

/// Create a fresh in-memory Drift database suitable for pipeline tests.
///
/// The caller is responsible for calling `db.close()` in tearDown.
AppDatabase createPipelineDatabase() {
  SyncEngine.resetDeviceIdCache();
  return AppDatabase.forTesting(NativeDatabase.memory());
}

// ---------------------------------------------------------------------------
// Crypto factory
// ---------------------------------------------------------------------------

/// Generate a deterministic 32-byte encrypt key for testing.
Uint8List generateTestEncryptKey() {
  return Uint8List.fromList(List.generate(32, (i) => (i * 7 + 13) % 256));
}

/// Create a real [CryptoService] with the given encrypt key injected.
///
/// This bypasses Argon2id key derivation and flutter_secure_storage so
/// that tests can run without a device keychain.
CryptoService createPipelineCrypto(Uint8List encryptKey) {
  final crypto = CryptoService();
  crypto.injectEncryptKey(encryptKey);
  return crypto;
}

// ---------------------------------------------------------------------------
// Mock API client
// ---------------------------------------------------------------------------

/// A mock [ApiClient] that intercepts syncPull and syncPush calls
/// without making network requests.
///
/// Usage:
///   - Set [pullResponse] before calling engine.pull()
///   - After engine.push(), inspect [capturedPushItems]
///   - For cross-device tests, copy capturedPushItems into a fresh
///     MockSyncApiClient's pullResponse on a second device.
class MockSyncApiClient extends ApiClient {
  MockSyncApiClient() : super(baseUrl: 'http://localhost:0');

  // -- Pull configuration --

  /// The response to return on the next syncPull call.
  SyncPullResponseDto? pullResponse;

  /// The `sinceVersion` value received in the most recent syncPull call.
  int? lastPullSinceVersion;

  // -- Push capture --

  /// Items captured from the most recent syncPush call.
  final List<Map<String, dynamic>> capturedPushItems = [];

  /// The raw JSON body sent in the most recent syncPush call.
  Map<String, dynamic>? lastPushRequestBody;

  // -- Override sync methods --

  @override
  Future<SyncPullResponseDto> syncPull(int sinceVersion) async {
    lastPullSinceVersion = sinceVersion;
    return pullResponse ?? SyncPullResponseDto(blobs: [], latestVersion: 0);
  }

  @override
  Future<dynamic> syncPush(dynamic req) async {
    final body = req as Map<String, dynamic>;
    lastPushRequestBody = body;
    final blobs = body['blobs'] as List<dynamic>;
    capturedPushItems.clear();
    for (final blob in blobs) {
      capturedPushItems.add(blob as Map<String, dynamic>);
    }

    // Accept all pushed items.
    final acceptedIds =
        capturedPushItems.map((b) => b['item_id'] as String).toList();

    return {
      'accepted': acceptedIds,
      'conflicts': <dynamic>[],
    };
  }

  // -- Stub out other methods that are not needed --

  @override
  Future<Map<String, dynamic>> syncStatus() async => {
        'latest_version': 0,
        'item_count': 0,
      };
}

// ---------------------------------------------------------------------------
// Helper: encrypt a note envelope for pull tests
// ---------------------------------------------------------------------------

/// Encrypt a note envelope (JSON with content and title) using real libsodium.
///
/// This produces a base64-encoded ciphertext that can be placed in a
/// SyncPullResponseDto blob. The [encryptKey] must be the same 32-byte key
/// used by the CryptoService on the receiving end.
Future<String> encryptNoteEnvelope({
  required Uint8List encryptKey,
  required String itemId,
  required String content,
  String? title,
}) async {
  final envelope = <String, dynamic>{
    'content': content,
  };
  if (title != null) {
    envelope['title'] = title;
  }
  final plaintext = jsonEncode(envelope);
  final itemKey = await Encryptor.derivePerItemKey(encryptKey, itemId);
  return Encryptor.encrypt(plaintext, itemKey);
}

/// Encrypt a plaintext string for pull tests (tags, collections, contents).
///
/// Unlike notes, these item types encrypt the plaintext directly without
/// wrapping in a JSON envelope.
Future<String> encryptPlaintext({
  required Uint8List encryptKey,
  required String itemId,
  required String plaintext,
}) async {
  final itemKey = await Encryptor.derivePerItemKey(encryptKey, itemId);
  return Encryptor.encrypt(plaintext, itemKey);
}

/// Build a blob map suitable for SyncPullResponseDto.blobs.
///
/// The [encryptedDataBase64] should be produced by [encryptNoteEnvelope] or
/// [encryptPlaintext].
Map<String, dynamic> buildPullBlob({
  required String itemId,
  required String itemType,
  required String encryptedDataBase64,
  required int version,
  DateTime? updatedAt,
}) {
  return {
    'item_id': itemId,
    'item_type': itemType,
    'encrypted_data': encryptedDataBase64,
    'version': version,
    'updated_at': (updatedAt ?? DateTime.now()).toUtc().toIso8601String(),
  };
}
