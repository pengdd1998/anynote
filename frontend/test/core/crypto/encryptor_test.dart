import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sodium_libs/sodium_libs_sumo.dart';

import 'package:anynote/core/crypto/encryptor.dart';
import 'sodium_test_init.dart';

void main() {
  late Uint8List testKey;

  setUpAll(() async {
    registerTestSodiumPlatform();
    await SodiumSumoInit.init();
    // Generate a deterministic 32-byte test key
    testKey = Uint8List.fromList(
      List.generate(32, (i) => (i * 7 + 13) % 256),
    );
  });

  group('encrypt/decrypt round-trip', () {
    test('normal ASCII string', () async {
      const plaintext = 'Hello, AnyNote!';
      final encrypted = await Encryptor.encrypt(plaintext, testKey);
      final decrypted = await Encryptor.decrypt(encrypted, testKey);
      expect(decrypted, plaintext);
    });

    test('empty string', () async {
      const plaintext = '';
      final encrypted = await Encryptor.encrypt(plaintext, testKey);
      final decrypted = await Encryptor.decrypt(encrypted, testKey);
      expect(decrypted, plaintext);
    });

    test('unicode and Chinese text', () async {
      const plaintext = 'AnyNote - \u4f60\u597d\u4e16\u754c \u{1F600} \u00e9\u00e8\u00ea';
      final encrypted = await Encryptor.encrypt(plaintext, testKey);
      final decrypted = await Encryptor.decrypt(encrypted, testKey);
      expect(decrypted, plaintext);
    });

    test('multi-byte emoji text', () async {
      const plaintext =
          '\u{1F680} Rocket science \u{1F913} with \u{2764}\u{FE0F}\u{1F525}';
      final encrypted = await Encryptor.encrypt(plaintext, testKey);
      final decrypted = await Encryptor.decrypt(encrypted, testKey);
      expect(decrypted, plaintext);
    });

    test('large content (~100KB)', () async {
      // Generate ~100KB of repeating text
      final plaintext = 'A' * 100000;
      final encrypted = await Encryptor.encrypt(plaintext, testKey);
      final decrypted = await Encryptor.decrypt(encrypted, testKey);
      expect(decrypted, plaintext);
      // Verify the ciphertext is roughly the same size plus nonce+tag overhead
      final raw = base64Decode(encrypted);
      expect(raw.length, greaterThanOrEqualTo(plaintext.length));
    });

    test('encryptBlob/decryptBlob round-trip with binary data', () async {
      final data = Uint8List.fromList(
        List.generate(1024, (i) => i % 256),
      );
      final encrypted = await Encryptor.encryptBlob(data, testKey);
      final decrypted = await Encryptor.decryptBlob(encrypted, testKey);
      expect(decrypted, equals(data));
    });

    test('encryptBlob/decryptBlob with empty data', () async {
      final data = Uint8List(0);
      final encrypted = await Encryptor.encryptBlob(data, testKey);
      final decrypted = await Encryptor.decryptBlob(encrypted, testKey);
      expect(decrypted, equals(data));
    });

    test('encryptBlob/decryptBlob with large binary data (~100KB)', () async {
      final data = Uint8List.fromList(
        List.generate(100000, (i) => (i * 3 + 17) % 256),
      );
      final encrypted = await Encryptor.encryptBlob(data, testKey);
      final decrypted = await Encryptor.decryptBlob(encrypted, testKey);
      expect(decrypted, equals(data));
    });
  });

  group('nonce uniqueness', () {
    test('encrypting same plaintext twice produces different ciphertexts',
        () async {
      const plaintext = 'same content';
      final encrypted1 = await Encryptor.encrypt(plaintext, testKey);
      final encrypted2 = await Encryptor.encrypt(plaintext, testKey);
      // Ciphertexts should differ due to random nonces
      expect(encrypted1, isNot(equals(encrypted2)));
      // But both should decrypt correctly
      expect(await Encryptor.decrypt(encrypted1, testKey), plaintext);
      expect(await Encryptor.decrypt(encrypted2, testKey), plaintext);
    });

    test('100 sequential encrypts produce 100 unique nonces', () async {
      const plaintext = 'nonce test';
      final nonces = <String>{};
      for (var i = 0; i < 100; i++) {
        final encrypted = await Encryptor.encrypt(plaintext, testKey);
        final raw = base64Decode(encrypted);
        // Extract the 24-byte nonce and encode as hex for comparison
        final nonceHex = raw.sublist(0, 24).map(
          (b) => b.toRadixString(16).padLeft(2, '0'),
        ).join();
        nonces.add(nonceHex);
      }
      // All 100 nonces should be unique
      expect(nonces.length, 100);
    });
  });

  group('authentication tag verification', () {
    test('tampered ciphertext fails decrypt (flipped byte)', () async {
      const plaintext = 'sensitive data';
      final encrypted = await Encryptor.encrypt(plaintext, testKey);
      final raw = Uint8List.fromList(base64Decode(encrypted));

      // Flip a byte in the ciphertext area (after the nonce)
      final tampered = Uint8List.fromList(raw);
      tampered[25] ^= 0xFF; // Flip byte at position 25 (just past nonce)

      final tamperedBase64 = base64Encode(tampered);
      expect(
        () => Encryptor.decrypt(tamperedBase64, testKey),
        throwsA(isA<Exception>()),
      );
    });

    test('truncated ciphertext fails decrypt', () async {
      const plaintext = 'will be truncated';
      final encrypted = await Encryptor.encrypt(plaintext, testKey);
      final raw = base64Decode(encrypted);

      // Truncate: keep nonce + a few bytes, drop the rest
      final truncated = base64Encode(raw.sublist(0, raw.length - 10));
      expect(
        () => Encryptor.decrypt(truncated, testKey),
        throwsA(isA<Exception>()),
      );
    });

    test('wrong key fails decrypt', () async {
      const plaintext = 'wrong key test';
      final encrypted = await Encryptor.encrypt(plaintext, testKey);

      // Generate a different key
      final wrongKey = Uint8List.fromList(
        List.generate(32, (i) => (i * 11 + 29) % 256),
      );

      expect(
        () => Encryptor.decrypt(encrypted, wrongKey),
        throwsA(isA<Exception>()),
      );
    });

    test('decryptBlob with tampered data throws', () async {
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);
      final encrypted = await Encryptor.encryptBlob(data, testKey);

      final tampered = Uint8List.fromList(encrypted);
      tampered[26] ^= 0x42;

      expect(
        () => Encryptor.decryptBlob(tampered, testKey),
        throwsA(isA<Exception>()),
      );
    });

    test('decryptBlob with data too short throws ArgumentError', () async {
      final shortData = Uint8List.fromList([1, 2, 3]);
      expect(
        () => Encryptor.decryptBlob(shortData, testKey),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('per-item key derivation', () {
    test('derivePerItemKey produces deterministic output', () async {
      const itemId = 'note-uuid-1234';
      final key1 = await Encryptor.derivePerItemKey(testKey, itemId);
      final key2 = await Encryptor.derivePerItemKey(testKey, itemId);
      expect(key1, equals(key2));
    });

    test('different item IDs produce different keys', () async {
      final key1 =
          await Encryptor.derivePerItemKey(testKey, 'note-uuid-aaaa');
      final key2 =
          await Encryptor.derivePerItemKey(testKey, 'note-uuid-bbbb');
      expect(key1, isNot(equals(key2)));
    });

    test('derived key is 32 bytes (256 bits)', () async {
      final key =
          await Encryptor.derivePerItemKey(testKey, 'test-item-id');
      expect(key.length, 32);
    });

    test('different encrypt keys produce different item keys for same ID',
        () async {
      final otherKey = Uint8List.fromList(
        List.generate(32, (i) => (i * 11 + 29) % 256),
      );
      const itemId = 'shared-item-id';

      final derived1 = await Encryptor.derivePerItemKey(testKey, itemId);
      final derived2 = await Encryptor.derivePerItemKey(otherKey, itemId);
      expect(derived1, isNot(equals(derived2)));
    });

    test('full round-trip: encrypt with derived key then decrypt', () async {
      const plaintext = 'per-item encrypted content';
      const itemId = 'note-round-trip-test';

      final itemKey = await Encryptor.derivePerItemKey(testKey, itemId);
      final encrypted = await Encryptor.encrypt(plaintext, itemKey);
      final decrypted = await Encryptor.decrypt(encrypted, itemKey);
      expect(decrypted, plaintext);
    });
  });

  group('wire format', () {
    test('ciphertext starts with 24-byte nonce', () async {
      const plaintext = 'wire format test';
      final encrypted = await Encryptor.encrypt(plaintext, testKey);
      final raw = base64Decode(encrypted);

      // XChaCha20-Poly1305 nonce is 24 bytes
      expect(raw.length, greaterThanOrEqualTo(24));
      // The first 24 bytes are the nonce -- they should look random (not all zeros)
      final nonce = raw.sublist(0, 24);
      expect(nonce.every((b) => b == 0), isFalse);
    });

    test('ciphertext length matches nonce + encrypted data + tag', () async {
      const plaintext = 'size check';
      final plainBytes = utf8.encode(plaintext);
      final encrypted = await Encryptor.encrypt(plaintext, testKey);
      final raw = base64Decode(encrypted);

      // nonce(24) + plaintext.length + tag(16)
      expect(raw.length, 24 + plainBytes.length + 16);
    });

    test('blob ciphertext starts with 24-byte nonce', () async {
      final data = Uint8List.fromList([10, 20, 30, 40, 50]);
      final encrypted = await Encryptor.encryptBlob(data, testKey);

      expect(encrypted.length, greaterThanOrEqualTo(24));
      final nonce = encrypted.sublist(0, 24);
      expect(nonce.every((b) => b == 0), isFalse);
    });

    test('blob ciphertext length matches nonce + data + tag', () async {
      final data = Uint8List.fromList(List.generate(50, (i) => i));
      final encrypted = await Encryptor.encryptBlob(data, testKey);

      // nonce(24) + data.length + tag(16)
      expect(encrypted.length, 24 + data.length + 16);
    });

    test('base64 output is valid base64', () async {
      const plaintext = 'base64 check';
      final encrypted = await Encryptor.encrypt(plaintext, testKey);

      // Should not throw on decode
      final decoded = base64Decode(encrypted);
      expect(decoded.length, greaterThan(0));
    });
  });
}
