@Tags(['integration'])
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sodium_libs/sodium_libs_sumo.dart';

import 'package:anynote/core/crypto/encryptor.dart';
import 'sodium_test_init.dart';

/// End-to-end encryption round-trip integration test.
///
/// Exercises the full crypto pipeline:
///   master key → per-item key derivation → encrypt → decrypt → verify
///
/// This test requires the sodium native library (VM only).
void main() {
  late Uint8List masterKey;

  setUpAll(() async {
    registerTestSodiumPlatform();
    await SodiumSumoInit.init();
    // Simulate a 32-byte master key (normally derived from Argon2id).
    masterKey = Uint8List.fromList(
      List.generate(32, (i) => (i * 7 + 13) % 256),
    );
  });

  group('E2E encryption round-trip', () {
    test('single item: derive key → encrypt → decrypt → match', () async {
      const plaintext = 'Hello AnyNote - this is my secret note!';
      const itemId = '550e8400-e29b-41d4-a716-446655440000';

      // Step 1: Derive per-item key from master key + item UUID.
      final itemKey = await Encryptor.derivePerItemKey(masterKey, itemId);
      expect(itemKey.length, 32);

      // Step 2: Encrypt plaintext with per-item key.
      final encrypted = await Encryptor.encrypt(plaintext, itemKey);
      expect(encrypted, isNotEmpty);

      // Step 3: Decrypt ciphertext with same per-item key.
      final decrypted = await Encryptor.decrypt(encrypted, itemKey);

      // Step 4: Verify round-trip integrity.
      expect(decrypted, plaintext);
    });

    test('multiple items: each gets unique key, cross-decrypt fails', () async {
      const items = ['item-aaa', 'item-bbb', 'item-ccc'];
      const plaintexts = [
        'Content for AAA',
        'Content for BBB',
        'Content for CCC',
      ];

      // Derive keys and encrypt each item.
      final keys = <String, Uint8List>{};
      final ciphertexts = <String, String>{};

      for (var i = 0; i < items.length; i++) {
        final key = await Encryptor.derivePerItemKey(masterKey, items[i]);
        keys[items[i]] = key;
        ciphertexts[items[i]] = await Encryptor.encrypt(plaintexts[i], key);
      }

      // Verify all keys are unique.
      expect(keys[items[0]], isNot(equals(keys[items[1]])));
      expect(keys[items[1]], isNot(equals(keys[items[2]])));

      // Verify each decrypts with its own key.
      for (var i = 0; i < items.length; i++) {
        final decrypted = await Encryptor.decrypt(
          ciphertexts[items[i]]!,
          keys[items[i]]!,
        );
        expect(decrypted, plaintexts[i]);
      }

      // Verify cross-decryption fails (item-aaa key cannot decrypt item-bbb).
      expect(
        () => Encryptor.decrypt(ciphertexts['item-bbb']!, keys['item-aaa']!),
        throwsA(isA<Exception>()),
      );
    });

    test('empty data round-trip', () async {
      const itemId = 'empty-data-item';
      final itemKey = await Encryptor.derivePerItemKey(masterKey, itemId);

      final encrypted = await Encryptor.encrypt('', itemKey);
      final decrypted = await Encryptor.decrypt(encrypted, itemKey);
      expect(decrypted, '');
    });

    test('large data round-trip (~100KB)', () async {
      const itemId = 'large-data-item';
      final itemKey = await Encryptor.derivePerItemKey(masterKey, itemId);

      // ~100KB plaintext.
      final plaintext = 'X' * 100000;
      final encrypted = await Encryptor.encrypt(plaintext, itemKey);
      final decrypted = await Encryptor.decrypt(encrypted, itemKey);
      expect(decrypted, plaintext);
      expect(decrypted.length, 100000);
    });

    test('binary blob round-trip with per-item key', () async {
      const itemId = 'binary-blob-item';
      final itemKey = await Encryptor.derivePerItemKey(masterKey, itemId);

      final data = Uint8List.fromList(
        List.generate(4096, (i) => i % 256),
      );

      final encrypted = await Encryptor.encryptBlob(data, itemKey);
      final decrypted = await Encryptor.decryptBlob(encrypted, itemKey);
      expect(decrypted, equals(data));
    });

    test('Chinese text round-trip', () async {
      const itemId = 'chinese-text-item';
      final itemKey = await Encryptor.derivePerItemKey(masterKey, itemId);

      const plaintext = 'AnyNote - your privacy-first note app. E2E encrypted!';
      final encrypted = await Encryptor.encrypt(plaintext, itemKey);
      final decrypted = await Encryptor.decrypt(encrypted, itemKey);
      expect(decrypted, plaintext);
    });

    test('key derivation determinism: same inputs produce same key', () async {
      const itemId = 'determinism-test';

      final key1 = await Encryptor.derivePerItemKey(masterKey, itemId);
      final key2 = await Encryptor.derivePerItemKey(masterKey, itemId);

      expect(key1, equals(key2));

      // Encrypting with key1, decrypting with key2 should work.
      const plaintext = 'cross-decrypt determinism test';
      final encrypted = await Encryptor.encrypt(plaintext, key1);
      final decrypted = await Encryptor.decrypt(encrypted, key2);
      expect(decrypted, plaintext);
    });

    test('tampered ciphertext fails decrypt with per-item key', () async {
      const itemId = 'tamper-test';
      final itemKey = await Encryptor.derivePerItemKey(masterKey, itemId);

      const plaintext = 'tamper detection test';
      final encrypted = await Encryptor.encrypt(plaintext, itemKey);

      // Tamper with the ciphertext.
      final raw = Uint8List.fromList(base64Decode(encrypted));
      raw[30] ^= 0xFF;
      final tampered = base64Encode(raw);

      expect(
        () => Encryptor.decrypt(tampered, itemKey),
        throwsA(isA<Exception>()),
      );
    });

    test('full pipeline: 50 sequential items encrypt/decrypt correctly',
        () async {
      final errors = <String>[];

      for (var i = 0; i < 50; i++) {
        final itemId = 'seq-item-$i';
        final plaintext = 'Note content for item $i with unique data';

        final itemKey = await Encryptor.derivePerItemKey(masterKey, itemId);
        final encrypted = await Encryptor.encrypt(plaintext, itemKey);
        final decrypted = await Encryptor.decrypt(encrypted, itemKey);

        if (decrypted != plaintext) {
          errors.add('Item $i: decrypted mismatch');
        }
      }

      expect(errors, isEmpty, reason: 'All 50 items should round-trip correctly');
    });
  });
}
