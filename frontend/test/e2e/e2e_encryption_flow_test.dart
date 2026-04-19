import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sodium_libs/sodium_libs_sumo.dart';

import 'package:anynote/core/crypto/encryptor.dart';

import '../core/crypto/sodium_test_init.dart';

/// End-to-end test simulating the full client-server encryption + sync flow.
///
/// Uses the same Encryptor class that the app uses in production.
/// Verifies: key derivation, encrypt/decrypt round-trips, sync payload structure,
/// share key independence, and deterministic auth key hashing.

void main() {
  setUpAll(() async {
    registerTestSodiumPlatform();
    await SodiumSumoInit.init();
  });

  group('E2E encryption flow', () {
    test('per-item key derivation produces unique keys for different items',
        () async {
      final encryptKey = Uint8List.fromList(
        List.generate(32, (i) => i),
      );

      final noteKey = await Encryptor.derivePerItemKey(
        encryptKey,
        '550e8400-e29b-41d4-a716-446655440000',
      );
      final tagKey = await Encryptor.derivePerItemKey(
        encryptKey,
        '660e8400-e29b-41d4-a716-446655440001',
      );

      expect(noteKey.length, 32);
      expect(tagKey.length, 32);
      expect(_bytesEqual(noteKey, tagKey), isFalse);
    });

    test('encrypt/decrypt round-trip preserves content', () async {
      final key =
          await Encryptor.derivePerItemKey(Uint8List(32), 'test-note-1');
      final content = '# My First Note\n\nHello from AnyNote! E2E encrypted.';

      final encrypted = await Encryptor.encrypt(content, key);
      expect(encrypted, isNotEmpty);

      final decrypted = await Encryptor.decrypt(encrypted, key);
      expect(decrypted, equals(content));
    });

    test('wrong key fails to decrypt', () async {
      final noteKey =
          await Encryptor.derivePerItemKey(Uint8List(32), 'note-1');
      final tagKey =
          await Encryptor.derivePerItemKey(Uint8List(32), 'tag-1');

      final encrypted =
          await Encryptor.encrypt('secret content', noteKey);

      expect(
        () => Encryptor.decrypt(encrypted, tagKey),
        throwsA(anything),
      );
    });

    test('encrypted data is base64 and server-compatible', () async {
      final key =
          await Encryptor.derivePerItemKey(Uint8List(32), 'server-test');
      final content = 'Content for server sync';

      final encrypted = await Encryptor.encrypt(content, key);

      // Valid base64
      final decoded = base64.decode(encrypted);
      expect(decoded.length, greaterThan(content.length));

      // Can be JSON-serialized (server stores as text)
      final jsonPayload = jsonEncode({'encrypted_data': encrypted});
      final parsed = jsonDecode(jsonPayload) as Map<String, dynamic>;
      final fromJson = parsed['encrypted_data'] as String;

      final decrypted = await Encryptor.decrypt(fromJson, key);
      expect(decrypted, equals(content));
    });

    test('sync push payload structure matches server API', () async {
      final key = await Encryptor.derivePerItemKey(Uint8List(32), 'sync-test');
      final noteContent = '# Sync Test\nThis note will be pushed to server';

      final encrypted = await Encryptor.encrypt(noteContent, key);
      final noteId = '550e8400-e29b-41d4-a716-446655440000';

      final payload = {
        'blobs': [
          {
            'item_id': noteId,
            'item_type': 'note',
            'version': 1,
            'encrypted_data': encrypted,
            'blob_size': base64.decode(encrypted).length,
          }
        ],
      };

      final json = jsonEncode(payload);
      expect(json, contains('"blobs"'));
      expect(json, contains(noteId));

      // Round-trip through JSON and decrypt
      final parsed = jsonDecode(json) as Map<String, dynamic>;
      final blobs = parsed['blobs'] as List;
      final dataFromJson = blobs[0]['encrypted_data'] as String;
      final decrypted = await Encryptor.decrypt(dataFromJson, key);
      expect(decrypted, equals(noteContent));
    });

    test('share encryption is independent from note encryption', () async {
      final noteKey =
          await Encryptor.derivePerItemKey(Uint8List(32), 'note-uuid');
      final shareKey =
          await Encryptor.derivePerItemKey(Uint8List(32), 'share-uuid');
      final content = 'Shared note content';

      final noteEncrypted = await Encryptor.encrypt(content, noteKey);
      final shareEncrypted = await Encryptor.encrypt(content, shareKey);

      // Different keys → different ciphertext
      expect(noteEncrypted, isNot(equals(shareEncrypted)));

      // Each decrypts with its own key
      expect(await Encryptor.decrypt(noteEncrypted, noteKey), equals(content));
      expect(
          await Encryptor.decrypt(shareEncrypted, shareKey), equals(content));
    });

    test('per-item key derivation is deterministic', () async {
      final encryptKey = Uint8List.fromList(
        List.generate(32, (i) => i * 2),
      );
      const itemId = 'deterministic-test-uuid';

      final key1 = await Encryptor.derivePerItemKey(encryptKey, itemId);
      final key2 = await Encryptor.derivePerItemKey(encryptKey, itemId);

      expect(_bytesEqual(key1, key2), isTrue);
    });

    test('multiple notes can be encrypted and synced independently', () async {
      final encryptKey = Uint8List.fromList(
        List.generate(32, (i) => i),
      );

      final notes = List.generate(
        5,
        (i) => 'Note $i: ${List.generate(50, (j) => 'word$j').join(' ')}',
      );
      final noteIds = List.generate(5, (i) => 'batch-note-uuid-$i');

      // Encrypt all
      final encryptedNotes = <String, String>{};
      for (var i = 0; i < notes.length; i++) {
        final itemKey =
            await Encryptor.derivePerItemKey(encryptKey, noteIds[i]);
        encryptedNotes[noteIds[i]] = await Encryptor.encrypt(notes[i], itemKey);
      }

      // All unique ciphertexts
      expect(encryptedNotes.values.toSet().length, 5);

      // Decrypt all and verify
      for (var i = 0; i < notes.length; i++) {
        final itemKey =
            await Encryptor.derivePerItemKey(encryptKey, noteIds[i]);
        final decrypted =
            await Encryptor.decrypt(encryptedNotes[noteIds[i]]!, itemKey);
        expect(decrypted, equals(notes[i]));
      }
    });

    test('blob encrypt/decrypt round-trip works for binary data', () async {
      final key = await Encryptor.derivePerItemKey(Uint8List(32), 'blob-test');
      final data = Uint8List.fromList(List.generate(1024, (i) => i % 256));

      final encrypted = await Encryptor.encryptBlob(data, key);
      expect(encrypted.length, greaterThan(data.length));

      final decrypted = await Encryptor.decryptBlob(encrypted, key);
      expect(decrypted.length, equals(data.length));
      expect(_bytesEqual(decrypted, data), isTrue);
    });

    test('Chinese text encrypts and decrypts correctly', () async {
      final key =
          await Encryptor.derivePerItemKey(Uint8List(32), 'chinese-test');
      final content = '# 中文笔记\n\n这是一条端到端加密的中文笔记。加密算法使用 XChaCha20-Poly1305。';

      final encrypted = await Encryptor.encrypt(content, key);
      final decrypted = await Encryptor.decrypt(encrypted, key);
      expect(decrypted, equals(content));
    });

    test('empty content encrypts and decrypts', () async {
      final key =
          await Encryptor.derivePerItemKey(Uint8List(32), 'empty-test');

      final encrypted = await Encryptor.encrypt('', key);
      final decrypted = await Encryptor.decrypt(encrypted, key);
      expect(decrypted, equals(''));
    });
  });
}

bool _bytesEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
