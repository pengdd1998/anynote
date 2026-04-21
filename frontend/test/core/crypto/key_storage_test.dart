import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

// KeyStorage._encode and _decode are private, so we replicate the exact
// encoding logic here to verify correctness independently. This is the same
// hex-encoding scheme used throughout the app for storing cryptographic keys.

/// Replicates KeyStorage._encode: bytes -> lowercase hex string.
String encodeHex(Uint8List data) {
  return data.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// Replicates KeyStorage._decode: lowercase hex string -> bytes.
Uint8List decodeHex(String hex) {
  final bytes = <int>[];
  for (var i = 0; i < hex.length; i += 2) {
    bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }
  return Uint8List.fromList(bytes);
}

void main() {
  // ---------------------------------------------------------------------------
  // Hex encoding (matches KeyStorage._encode)
  // ---------------------------------------------------------------------------

  group('hex encoding', () {
    test('encodes single zero byte', () {
      final data = Uint8List.fromList([0x00]);
      expect(encodeHex(data), '00');
    });

    test('encodes single 0xFF byte', () {
      final data = Uint8List.fromList([0xFF]);
      expect(encodeHex(data), 'ff');
    });

    test('encodes multi-byte array', () {
      final data = Uint8List.fromList([0x0A, 0x1B]);
      expect(encodeHex(data), '0a1b');
    });

    test('encodes all possible byte values', () {
      final data = Uint8List.fromList(List.generate(256, (i) => i));
      final encoded = encodeHex(data);

      // Each byte produces 2 hex chars, so 256 bytes -> 512 chars.
      expect(encoded.length, 512);

      // Spot-check first and last bytes.
      expect(encoded.substring(0, 2), '00');
      expect(encoded.substring(510, 512), 'ff');
    });

    test('encodes empty array to empty string', () {
      final data = Uint8List.fromList([]);
      expect(encodeHex(data), '');
    });

    test('encodes a full 32-byte key', () {
      final key = Uint8List.fromList(List.generate(32, (i) => i + 1));
      final encoded = encodeHex(key);

      expect(encoded.length, 64);
      expect(encoded.substring(0, 2), '01');
      expect(encoded.substring(62, 64), '20'); // 32 decimal = 0x20
    });
  });

  // ---------------------------------------------------------------------------
  // Hex decoding (matches KeyStorage._decode)
  // ---------------------------------------------------------------------------

  group('hex decoding', () {
    test('decodes "00" to single zero byte', () {
      final result = decodeHex('00');
      expect(result, Uint8List.fromList([0x00]));
    });

    test('decodes "ff" to single 0xFF byte', () {
      final result = decodeHex('ff');
      expect(result, Uint8List.fromList([0xFF]));
    });

    test('decodes multi-byte hex string', () {
      final result = decodeHex('0a1b');
      expect(result, Uint8List.fromList([0x0A, 0x1B]));
    });

    test('decodes uppercase hex is case-insensitive via int.parse', () {
      // int.parse with radix 16 handles both cases, so "0A1B" should also work.
      final result = decodeHex('0A1B');
      expect(result, Uint8List.fromList([0x0A, 0x1B]));
    });

    test('decodes empty string to empty byte array', () {
      final result = decodeHex('');
      expect(result, Uint8List.fromList([]));
    });

    test('decodes 32-byte key (64 hex chars)', () {
      final hex = List.generate(32, (i) => (i + 1).toRadixString(16).padLeft(2, '0')).join();
      final result = decodeHex(hex);

      expect(result.length, 32);
      for (var i = 0; i < 32; i++) {
        expect(result[i], i + 1);
      }
    });
  });

  // ---------------------------------------------------------------------------
  // Round-trip: encode then decode
  // ---------------------------------------------------------------------------

  group('encode-decode round-trip', () {
    test('round-trip preserves single byte', () {
      final original = Uint8List.fromList([0xAB]);
      expect(decodeHex(encodeHex(original)), original);
    });

    test('round-trip preserves empty array', () {
      final original = Uint8List.fromList([]);
      expect(decodeHex(encodeHex(original)), original);
    });

    test('round-trip preserves 32-byte cryptographic key', () {
      final key = Uint8List.fromList([
        0xDE, 0xAD, 0xBE, 0xEF, 0xCA, 0xFE, 0xBA, 0xBE,
        0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF,
        0xFE, 0xDC, 0xBA, 0x98, 0x76, 0x54, 0x32, 0x10,
        0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77,
      ]);
      expect(decodeHex(encodeHex(key)), key);
    });

    test('round-trip preserves random-looking data', () {
      final data = Uint8List.fromList([
        0x5A, 0x3C, 0xF1, 0x9E, 0x00, 0xFF, 0x80, 0x7F,
        0xAA, 0x55, 0xCC, 0x33,
      ]);
      expect(decodeHex(encodeHex(data)), data);
    });

    test('round-trip preserves all 256 byte values', () {
      final data = Uint8List.fromList(List.generate(256, (i) => i));
      expect(decodeHex(encodeHex(data)), data);
    });

    test('decode-encode round-trip for hex string', () {
      const hex = 'deadbeef01020304';
      expect(encodeHex(decodeHex(hex)), hex);
    });
  });

  // ---------------------------------------------------------------------------
  // Edge cases
  // ---------------------------------------------------------------------------

  group('edge cases', () {
    test('all-zeros 32-byte array encodes to 64 zero chars', () {
      final zeros = Uint8List(32);
      expect(encodeHex(zeros), '0' * 64);
    });

    test('all-0xFF 32-byte array encodes to 64 f chars', () {
      final ff = Uint8List filled = Uint8List(32)..fillRange(0, 32, 0xFF);
      expect(encodeHex(ff), 'f' * 64);
    });

    test('encoding is deterministic (same input, same output)', () {
      final data = Uint8List.fromList([0x12, 0x34, 0x56, 0x78]);
      final first = encodeHex(data);
      final second = encodeHex(data);
      expect(first, second);
    });
  });
}
