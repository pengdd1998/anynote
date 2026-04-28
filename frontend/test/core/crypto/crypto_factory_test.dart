import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sodium_libs/sodium_libs_sumo.dart';

import 'package:anynote/core/crypto/crypto_factory.dart';
import 'sodium_test_init.dart';

void main() {
  late Uint8List testKey;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerTestSodiumPlatform();
    await SodiumSumoInit.init();
    // Deterministic 32-byte test key.
    testKey = Uint8List.fromList(
      List.generate(32, (i) => (i * 7 + 13) % 256),
    );
  });

  group('CryptoFactory', () {
    test('isNativeBackend returns true', () {
      expect(CryptoFactory.instance.isNativeBackend, isTrue);
    });

    test('instance is singleton (same identity)', () {
      final a = CryptoFactory.instance;
      final b = CryptoFactory.instance;
      expect(identical(a, b), isTrue);
    });

    test('encrypt/decrypt round-trip works', () async {
      const plaintext = 'hello world';
      final encrypted =
          await CryptoFactory.instance.encrypt(plaintext, testKey);
      final decrypted =
          await CryptoFactory.instance.decrypt(encrypted, testKey);
      expect(decrypted, plaintext);
    });

    test('deriveItemKey returns deterministic 32-byte key for same inputs',
        () async {
      const itemId = 'note-uuid-abc';
      final key1 = await CryptoFactory.instance.deriveItemKey(testKey, itemId);
      final key2 = await CryptoFactory.instance.deriveItemKey(testKey, itemId);

      expect(key1.length, 32);
      expect(key1, equals(key2));
    });

    test('deriveItemKey returns different keys for different item IDs',
        () async {
      final key1 = await CryptoFactory.instance.deriveItemKey(
        testKey,
        'note-uuid-aaaa',
      );
      final key2 = await CryptoFactory.instance.deriveItemKey(
        testKey,
        'note-uuid-bbbb',
      );

      expect(key1, isNot(equals(key2)));
    });
  });
}
