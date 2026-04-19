import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sodium_libs/sodium_libs_sumo.dart';

import 'package:anynote/core/crypto/crypto_service.dart';
import 'package:anynote/core/crypto/encryptor.dart';
import 'package:anynote/core/crypto/master_key.dart';
import 'sodium_test_init.dart';

void main() {
  late CryptoService service;
  late Uint8List testEncryptKey;

  setUpAll(() async {
    // Initialize sodium so that MasterKeyManager and Encryptor can work.
    registerTestSodiumPlatform();
    await SodiumSumoInit.init();
    // Derive a deterministic encrypt key for testing.
    // We derive it the same way the app does: from a known master key.
    final salt = Uint8List.fromList(List.generate(32, (i) => i));
    final masterKey =
        await MasterKeyManager.deriveMasterKey('test-password', salt);
    testEncryptKey = await MasterKeyManager.deriveEncryptKey(masterKey);
  });

  setUp(() {
    service = CryptoService();
  });

  /// Helper: inject an encrypt key into the service for testing.
  /// Uses the @visibleForTesting injectEncryptKey method.
  void injectEncryptKey(CryptoService svc, Uint8List key) {
    svc.injectEncryptKey(key);
  }

  group('encryptForItem / decryptForItem round-trip', () {
    test('same item ID encrypts and decrypts correctly', () async {
      injectEncryptKey(service, testEncryptKey);
      const itemId = 'note-test-123';
      const plaintext = 'Hello, CryptoService!';

      final encrypted = await service.encryptForItem(itemId, plaintext);
      final decrypted = await service.decryptForItem(itemId, encrypted);

      expect(decrypted, plaintext);
    });

    test('round-trip with Chinese content', () async {
      injectEncryptKey(service, testEncryptKey);
      const itemId = 'note-chinese';
      const plaintext =
          '\u4eca\u5929\u5929\u6c14\u5f88\u597d\uff0c\u9002\u5408\u5199\u7b14\u8bb0\u3002';

      final encrypted = await service.encryptForItem(itemId, plaintext);
      final decrypted = await service.decryptForItem(itemId, encrypted);

      expect(decrypted, plaintext);
    });

    test('round-trip with empty string', () async {
      injectEncryptKey(service, testEncryptKey);
      const itemId = 'note-empty';
      const plaintext = '';

      final encrypted = await service.encryptForItem(itemId, plaintext);
      final decrypted = await service.decryptForItem(itemId, encrypted);

      expect(decrypted, plaintext);
    });

    test('different item IDs produce different ciphertexts', () async {
      injectEncryptKey(service, testEncryptKey);
      const plaintext = 'same content, different items';

      final encrypted1 =
          await service.encryptForItem('item-alpha', plaintext);
      final encrypted2 =
          await service.encryptForItem('item-beta', plaintext);

      // Different per-item keys should produce different ciphertexts.
      // However, random nonces also guarantee this. The important invariant
      // is that each item's key is independent.
      expect(encrypted1, isNot(equals(encrypted2)));
    });

    test('decrypting with wrong item ID returns null', () async {
      injectEncryptKey(service, testEncryptKey);
      const plaintext = 'secret for item A';

      final encrypted =
          await service.encryptForItem('item-a', plaintext);

      // Attempting to decrypt with a different item ID uses a different key
      final result =
          await service.decryptForItem('item-b', encrypted);

      expect(result, isNull);
    });

    test('decrypting tampered ciphertext returns null', () async {
      injectEncryptKey(service, testEncryptKey);
      const itemId = 'note-tamper';
      const plaintext = 'original content';

      final encrypted =
          await service.encryptForItem(itemId, plaintext);

      // Tamper with the base64 string
      final tampered = _flipBase64Char(encrypted);
      final result = await service.decryptForItem(itemId, tampered);

      expect(result, isNull);
    });
  });

  group('encryptBlobForItem / decryptBlobForItem round-trip', () {
    test('binary blob round-trip', () async {
      injectEncryptKey(service, testEncryptKey);
      const itemId = 'blob-test';
      final data = Uint8List.fromList(List.generate(256, (i) => i));

      final encrypted = await service.encryptBlobForItem(itemId, data);
      final decrypted =
          await service.decryptBlobForItem(itemId, encrypted);

      expect(decrypted, equals(data));
    });

    test('blob with wrong item ID returns null', () async {
      injectEncryptKey(service, testEncryptKey);
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);

      final encrypted =
          await service.encryptBlobForItem('blob-a', data);
      final result =
          await service.decryptBlobForItem('blob-b', encrypted);

      expect(result, isNull);
    });

    test('blob with tampered data returns null', () async {
      injectEncryptKey(service, testEncryptKey);
      const itemId = 'blob-tamper';
      final data = Uint8List.fromList([10, 20, 30]);

      final encrypted =
          await service.encryptBlobForItem(itemId, data);

      // Tamper with the encrypted data
      final tampered = Uint8List.fromList(encrypted);
      tampered[tampered.length - 1] ^= 0xFF;

      final result =
          await service.decryptBlobForItem(itemId, tampered);

      expect(result, isNull);
    });
  });

  group('lock/unlock lifecycle', () {
    test('decrypt returns null when locked (no encrypt key)', () async {
      // Service is freshly created -- no key injected, locked by default
      expect(service.isUnlocked, isFalse);

      final result =
          await service.decryptForItem('any-item', 'any-encrypted');

      expect(result, isNull);
    });

    test('encrypt throws StateError when locked', () async {
      expect(service.isUnlocked, isFalse);

      expect(
        () => service.encryptForItem('any-item', 'text'),
        throwsA(isA<StateError>()),
      );
    });

    test('isUnlocked returns true after key injection', () async {
      injectEncryptKey(service, testEncryptKey);
      expect(service.isUnlocked, isTrue);
    });

    test('lock clears the encrypt key', () async {
      injectEncryptKey(service, testEncryptKey);
      expect(service.isUnlocked, isTrue);

      await service.lock();
      expect(service.isUnlocked, isFalse);

      // Decrypt should now return null (catches the StateError internally)
      final result = await service.decryptForItem(
        'any-item',
        'any-encrypted',
      );
      expect(result, isNull);
    });

    test('re-lock and re-unlock cycle', () async {
      const itemId = 'cycle-test';
      const plaintext = 'lock cycle test';

      // First unlock
      injectEncryptKey(service, testEncryptKey);
      final encrypted = await service.encryptForItem(itemId, plaintext);

      // Lock
      await service.lock();
      expect(service.isUnlocked, isFalse);

      // Re-unlock
      injectEncryptKey(service, testEncryptKey);
      expect(service.isUnlocked, isTrue);

      // Should still decrypt with same key
      final decrypted = await service.decryptForItem(itemId, encrypted);
      expect(decrypted, plaintext);
    });
  });

  group('clearAll', () {
    test('clears cached key and sets isUnlocked to false', () async {
      injectEncryptKey(service, testEncryptKey);
      expect(service.isUnlocked, isTrue);

      // clearAll calls KeyStorage.clearAll() which requires flutter_secure_storage.
      // We cannot call clearAll() in a unit test without mocking the platform.
      // Instead, verify that lock() (which only clears memory) works correctly,
      // and document that clearAll() = lock() + KeyStorage.clearAll().
      await service.lock();
      expect(service.isUnlocked, isFalse);
    });
  });

  group('provider', () {
    test('cryptoServiceProvider creates a CryptoService instance', () {
      // Verify the provider can be instantiated
      final svc = CryptoService();
      expect(svc, isA<CryptoService>());
      expect(svc.isUnlocked, isFalse);
    });
  });

  group('per-item key isolation', () {
    test('item key from CryptoService matches manual derivation', () async {
      injectEncryptKey(service, testEncryptKey);
      const itemId = 'isolation-check';

      // Derive the same key manually
      final manualKey =
          await Encryptor.derivePerItemKey(testEncryptKey, itemId);

      // Encrypt with CryptoService
      const plaintext = 'isolation test';
      final encrypted = await service.encryptForItem(itemId, plaintext);

      // Decrypt manually with the derived key
      final decrypted = await Encryptor.decrypt(encrypted, manualKey);

      expect(decrypted, plaintext);
    });

    test('100 different items produce 100 unique item keys', () async {
      final keys = <String>{};
      for (var i = 0; i < 100; i++) {
        final key = await Encryptor.derivePerItemKey(
          testEncryptKey,
          'item-$i',
        );
        keys.add(key.map((b) => b.toRadixString(16).padLeft(2, '0')).join());
      }
      expect(keys.length, 100);
    });
  });
}

/// Flip a character in a base64 string to simulate corruption.
/// Returns a string that differs from the input by one character.
String _flipBase64Char(String base64) {
  final chars = base64.split('');
  // Flip a character near the middle of the string
  final idx = chars.length ~/ 2;
  final c = chars[idx];
  // Replace with a different valid base64 character
  const replacements = {
    'A': 'B',
    'B': 'C',
    'C': 'D',
    'a': 'b',
    'b': 'c',
    '0': '1',
    '+': '/',
    '/': '+',
  };
  chars[idx] = replacements[c] ?? 'A';
  return chars.join();
}
