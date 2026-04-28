import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/storage/image_compressor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ImageCompressor constants', () {
    test('maxWidth is a reasonable value', () {
      expect(ImageCompressor.maxWidth, greaterThan(0));
      expect(ImageCompressor.maxWidth, lessThanOrEqualTo(4096));
    });

    test('maxHeight is a reasonable value', () {
      expect(ImageCompressor.maxHeight, greaterThan(0));
      expect(ImageCompressor.maxHeight, lessThanOrEqualTo(4096));
    });

    test('quality is in valid range', () {
      expect(ImageCompressor.quality, greaterThan(0));
      expect(ImageCompressor.quality, lessThanOrEqualTo(100));
    });

    test('skipCompressionThreshold is positive', () {
      expect(ImageCompressor.skipCompressionThreshold, greaterThan(0));
    });

    test('maxWidth and maxHeight are equal for aspect ratio preservation', () {
      expect(ImageCompressor.maxWidth, ImageCompressor.maxHeight);
    });

    test('quality is at least 70 for acceptable visual quality', () {
      expect(ImageCompressor.quality, greaterThanOrEqualTo(70));
    });
  });

  group('ImageCompressor.compress', () {
    test('returns small images unchanged', () async {
      // Create bytes smaller than the skip threshold (100 KB).
      final smallBytes =
          Uint8List.fromList(List.generate(1024, (i) => i % 256));

      final result = await ImageCompressor.compress(smallBytes);

      expect(result, smallBytes);
    });

    test('returns empty bytes unchanged', () async {
      final emptyBytes = Uint8List(0);

      final result = await ImageCompressor.compress(emptyBytes);

      expect(result, emptyBytes);
    });

    test('returns bytes under threshold unchanged', () async {
      // 99 KB -- just under the 100 KB threshold.
      final bytes = Uint8List(99 * 1024);

      final result = await ImageCompressor.compress(bytes);

      expect(result, bytes);
    });

    test('accepts custom maxWidth parameter', () async {
      final smallBytes = Uint8List.fromList(List.generate(512, (i) => i % 256));

      // With custom maxWidth, still returns small bytes as-is.
      final result = await ImageCompressor.compress(
        smallBytes,
        maxWidth: 800,
      );

      expect(result, smallBytes);
    });

    test('accepts custom quality parameter', () async {
      final smallBytes = Uint8List.fromList(List.generate(512, (i) => i % 256));

      final result = await ImageCompressor.compress(
        smallBytes,
        quality: 50,
      );

      expect(result, smallBytes);
    });

    test('returns Uint8List type', () async {
      final bytes = Uint8List.fromList([1, 2, 3]);

      final result = await ImageCompressor.compress(bytes);

      expect(result, isA<Uint8List>());
    });

    test('handles single byte input', () async {
      final bytes = Uint8List.fromList([42]);

      final result = await ImageCompressor.compress(bytes);

      expect(result.length, 1);
      expect(result[0], 42);
    });

    test('handles repeated bytes', () async {
      final bytes = Uint8List.fromList(List.filled(2048, 128));

      final result = await ImageCompressor.compress(bytes);

      // Below threshold, returns unchanged.
      expect(result, bytes);
    });

    test('does not modify original bytes', () async {
      final original = Uint8List.fromList([10, 20, 30, 40, 50]);
      final copy = Uint8List.fromList(original);

      await ImageCompressor.compress(original);

      expect(original, copy);
    });
  });

  group('ImageCompressor threshold behavior', () {
    test('exactly at threshold returns original bytes', () async {
      // Exactly 100 KB.
      final bytes = Uint8List(100 * 1024);

      final result = await ImageCompressor.compress(bytes);

      // At threshold (not strictly less than), compression is skipped.
      expect(result, bytes);
    });

    test('one byte below threshold returns original bytes', () async {
      final bytes = Uint8List(100 * 1024 - 1);

      final result = await ImageCompressor.compress(bytes);

      expect(result, bytes);
    });

    test('compress method is idempotent for small images', () async {
      final bytes = Uint8List.fromList(List.generate(500, (i) => i % 256));

      final result1 = await ImageCompressor.compress(bytes);
      final result2 = await ImageCompressor.compress(result1);

      expect(result1, result2);
    });
  });
}
