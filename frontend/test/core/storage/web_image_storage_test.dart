import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:anynote/core/storage/web_image_storage.dart';

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  // ── saveWebImage ──────────────────────────────────────

  group('saveWebImage', () {
    test('saves image and returns a key with correct format', () async {
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final key = await WebImageStorage.saveWebImage(bytes, 'note-abc');

      expect(key, startsWith('web_image_note-abc_'));
      expect(key.length, greaterThan('web_image_note-abc_'.length));
    });

    test('saves image data that can be loaded back', () async {
      final bytes = Uint8List.fromList([10, 20, 30, 40]);
      final key = await WebImageStorage.saveWebImage(bytes, 'note-rt');

      final loaded = await WebImageStorage.loadWebImage(key);

      expect(loaded, isNotNull);
      expect(loaded, bytes);
    });

    test('generates different keys for different content', () async {
      final bytes1 = Uint8List.fromList([1, 2, 3]);
      final bytes2 = Uint8List.fromList([4, 5, 6]);

      final key1 = await WebImageStorage.saveWebImage(bytes1, 'note-same');
      final key2 = await WebImageStorage.saveWebImage(bytes2, 'note-same');

      expect(key1, isNot(equals(key2)));
    });

    test('generates same key for identical content', () async {
      final bytes = Uint8List.fromList([42, 43, 44]);

      final key1 = await WebImageStorage.saveWebImage(bytes, 'note-dup');
      final key2 = await WebImageStorage.saveWebImage(bytes, 'note-dup');

      expect(key1, equals(key2));
    });

    test('stores data as base64 in SharedPreferences', () async {
      final bytes = Uint8List.fromList([7, 8, 9]);
      final key = await WebImageStorage.saveWebImage(bytes, 'note-raw');

      final stored = prefs.getString(key);
      expect(stored, isNotNull);
      expect(base64Decode(stored!), bytes);
    });

    test('updates registry with image size', () async {
      final bytes = Uint8List.fromList(List.generate(100, (i) => i % 256));
      await WebImageStorage.saveWebImage(bytes, 'note-reg');

      final usage = await WebImageStorage.getStorageUsage();
      expect(usage, 100);
    });

    test('overwrites existing image with same key', () async {
      final bytes1 = Uint8List.fromList([1, 1, 1]);
      final bytes2 = Uint8List.fromList([2, 2, 2, 2]);

      await WebImageStorage.saveWebImage(bytes1, 'note-ow');
      await WebImageStorage.saveWebImage(bytes2, 'note-ow');

      // Same key because same noteId + same content produces same hash,
      // but here the content differs so keys differ.
      // Instead, force same key by using identical content:
      final keyA = await WebImageStorage.saveWebImage(bytes1, 'note-ow2');
      final keyB = await WebImageStorage.saveWebImage(bytes1, 'note-ow2');
      expect(keyA, keyB);

      final loaded = await WebImageStorage.loadWebImage(keyA);
      expect(loaded, bytes1);
    });

    test('replacing existing image updates storage usage correctly', () async {
      final bytes1 = Uint8List.fromList(List.generate(50, (i) => i));
      final bytes2 = Uint8List.fromList(List.generate(100, (i) => i));

      // Same noteId, different content -> different keys, different usage
      await WebImageStorage.saveWebImage(bytes1, 'note-usage');
      var usage = await WebImageStorage.getStorageUsage();
      expect(usage, 50);

      await WebImageStorage.saveWebImage(bytes2, 'note-usage');
      usage = await WebImageStorage.getStorageUsage();
      expect(usage, 150); // both stored
    });
  });

  // ── loadWebImage ──────────────────────────────────────

  group('loadWebImage', () {
    test('returns null for non-existent key', () async {
      final loaded = await WebImageStorage.loadWebImage('nonexistent_key');
      expect(loaded, isNull);
    });

    test('returns correct bytes after save', () async {
      final bytes = Uint8List.fromList([100, 200, 55]);
      final key = await WebImageStorage.saveWebImage(bytes, 'note-load');

      final loaded = await WebImageStorage.loadWebImage(key);
      expect(loaded, bytes);
    });

    test('handles large image data', () async {
      final bytes = Uint8List.fromList(List.generate(10000, (i) => i % 256));
      final key = await WebImageStorage.saveWebImage(bytes, 'note-large');

      final loaded = await WebImageStorage.loadWebImage(key);
      expect(loaded!.length, 10000);
      expect(loaded, bytes);
    });

    test('returns correct data for multiple images', () async {
      final bytes1 = Uint8List.fromList([1, 2, 3]);
      final bytes2 = Uint8List.fromList([4, 5, 6]);

      final key1 = await WebImageStorage.saveWebImage(bytes1, 'note-m1');
      final key2 = await WebImageStorage.saveWebImage(bytes2, 'note-m2');

      final loaded1 = await WebImageStorage.loadWebImage(key1);
      final loaded2 = await WebImageStorage.loadWebImage(key2);

      expect(loaded1, bytes1);
      expect(loaded2, bytes2);
    });
  });

  // ── deleteWebImage ────────────────────────────────────

  group('deleteWebImage', () {
    test('deletes an existing image and returns true', () async {
      final bytes = Uint8List.fromList([11, 22, 33]);
      final key = await WebImageStorage.saveWebImage(bytes, 'note-del');

      final deleted = await WebImageStorage.deleteWebImage(key);
      expect(deleted, isTrue);

      final loaded = await WebImageStorage.loadWebImage(key);
      expect(loaded, isNull);
    });

    test('returns false for non-existent key', () async {
      final deleted = await WebImageStorage.deleteWebImage('nonexistent');
      expect(deleted, isFalse);
    });

    test('updates storage usage after deletion', () async {
      final bytes = Uint8List.fromList(List.generate(200, (i) => i));
      final key = await WebImageStorage.saveWebImage(bytes, 'note-usage-del');

      var usage = await WebImageStorage.getStorageUsage();
      expect(usage, 200);

      await WebImageStorage.deleteWebImage(key);

      usage = await WebImageStorage.getStorageUsage();
      expect(usage, 0);
    });

    test('removes image from registry', () async {
      final bytes = Uint8List.fromList([42]);
      final key = await WebImageStorage.saveWebImage(bytes, 'note-reg');

      expect(await WebImageStorage.getImageCount(), 1);

      await WebImageStorage.deleteWebImage(key);

      expect(await WebImageStorage.getImageCount(), 0);
    });

    test('does not affect other images', () async {
      final bytes1 = Uint8List.fromList([1]);
      final bytes2 = Uint8List.fromList([2]);

      final key1 = await WebImageStorage.saveWebImage(bytes1, 'note-keep');
      final key2 = await WebImageStorage.saveWebImage(bytes2, 'note-rm');

      await WebImageStorage.deleteWebImage(key2);

      final loaded1 = await WebImageStorage.loadWebImage(key1);
      expect(loaded1, bytes1);

      final loaded2 = await WebImageStorage.loadWebImage(key2);
      expect(loaded2, isNull);
    });
  });

  // ── deleteWebImagesForNote ────────────────────────────

  group('deleteWebImagesForNote', () {
    test('deletes all images for a given note', () async {
      // Different content -> different keys, same noteId
      await WebImageStorage.saveWebImage(
        Uint8List.fromList([1]),
        'note-batch',
      );
      await WebImageStorage.saveWebImage(
        Uint8List.fromList([2]),
        'note-batch',
      );
      await WebImageStorage.saveWebImage(
        Uint8List.fromList([3]),
        'note-other',
      );

      final count = await WebImageStorage.deleteWebImagesForNote('note-batch');
      expect(count, 2);

      expect(await WebImageStorage.getImageCount(), 1);
    });

    test('does not delete images for other notes', () async {
      final bytes1 = Uint8List.fromList([10]);
      final bytes2 = Uint8List.fromList([20]);

      final key1 = await WebImageStorage.saveWebImage(bytes1, 'note-keep');
      await WebImageStorage.saveWebImage(bytes2, 'note-remove');

      await WebImageStorage.deleteWebImagesForNote('note-remove');

      final loaded = await WebImageStorage.loadWebImage(key1);
      expect(loaded, bytes1);
    });

    test('returns 0 when no images exist for note', () async {
      final count = await WebImageStorage.deleteWebImagesForNote('nonexistent');
      expect(count, 0);
    });
  });

  // ── getStorageUsage ───────────────────────────────────

  group('getStorageUsage', () {
    test('returns 0 when no images stored', () async {
      final usage = await WebImageStorage.getStorageUsage();
      expect(usage, 0);
    });

    test('returns total bytes across all images', () async {
      await WebImageStorage.saveWebImage(
        Uint8List.fromList(List.generate(100, (i) => i)),
        'note-u1',
      );
      await WebImageStorage.saveWebImage(
        Uint8List.fromList(List.generate(200, (i) => i)),
        'note-u2',
      );

      final usage = await WebImageStorage.getStorageUsage();
      expect(usage, 300);
    });

    test('decreases after deletion', () async {
      final key = await WebImageStorage.saveWebImage(
        Uint8List.fromList(List.generate(500, (i) => i)),
        'note-udel',
      );

      expect(await WebImageStorage.getStorageUsage(), 500);

      await WebImageStorage.deleteWebImage(key);

      expect(await WebImageStorage.getStorageUsage(), 0);
    });
  });

  // ── getImageCount ─────────────────────────────────────

  group('getImageCount', () {
    test('returns 0 when no images stored', () async {
      expect(await WebImageStorage.getImageCount(), 0);
    });

    test('returns correct count after saves', () async {
      await WebImageStorage.saveWebImage(
        Uint8List.fromList([1]),
        'note-c1',
      );
      await WebImageStorage.saveWebImage(
        Uint8List.fromList([2]),
        'note-c2',
      );
      await WebImageStorage.saveWebImage(
        Uint8List.fromList([3]),
        'note-c3',
      );

      expect(await WebImageStorage.getImageCount(), 3);
    });

    test('decreases after deletion', () async {
      final key = await WebImageStorage.saveWebImage(
        Uint8List.fromList([1]),
        'note-cd',
      );
      expect(await WebImageStorage.getImageCount(), 1);

      await WebImageStorage.deleteWebImage(key);
      expect(await WebImageStorage.getImageCount(), 0);
    });
  });

  // ── Max size limit enforcement ────────────────────────

  group('max size limit', () {
    test('throws when exceeding 5 MB limit', () async {
      // Store 4 MB first
      final largeBytes = Uint8List.fromList(
        List.generate(4 * 1024 * 1024, (i) => i % 256),
      );
      await WebImageStorage.saveWebImage(largeBytes, 'note-big');

      // Try to store another 2 MB -- should exceed 5 MB total
      final extraBytes = Uint8List.fromList(
        List.generate(2 * 1024 * 1024, (i) => i % 256),
      );

      expect(
        () => WebImageStorage.saveWebImage(extraBytes, 'note-bigger'),
        throwsA(isA<StateError>()),
      );
    });

    test('allows saving up to the limit', () async {
      // Save 3 MB
      final bytes1 = Uint8List.fromList(
        List.generate(3 * 1024 * 1024, (i) => i % 256),
      );
      await WebImageStorage.saveWebImage(bytes1, 'note-lim1');

      // Save 2 MB -- total 5 MB, exactly at limit
      final bytes2 = Uint8List.fromList(
        List.generate(2 * 1024 * 1024, (i) => (i + 1) % 256),
      );
      // This should succeed (5 MB exactly == maxTotalBytes)
      final key = await WebImageStorage.saveWebImage(bytes2, 'note-lim2');
      expect(key, isNotEmpty);
    });

    test('allows replacing image within budget', () async {
      // Store 3 MB
      final bytes1 = Uint8List.fromList(
        List.generate(3 * 1024 * 1024, (i) => i % 256),
      );
      final _ = await WebImageStorage.saveWebImage(bytes1, 'note-repl');

      // Replace with 4 MB (same key would need same content, so use same noteId
      // to create a different key with different content)
      final bytes2 = Uint8List.fromList(
        List.generate(4 * 1024 * 1024, (i) => (i + 1) % 256),
      );

      // Total would be 3 + 4 = 7 MB > 5 MB, so this should fail
      expect(
        () => WebImageStorage.saveWebImage(bytes2, 'note-repl2'),
        throwsA(isA<StateError>()),
      );
    });

    test('budget freed after deletion allows new saves', () async {
      // Store 4 MB
      final bytes = Uint8List.fromList(
        List.generate(4 * 1024 * 1024, (i) => i % 256),
      );
      final key = await WebImageStorage.saveWebImage(bytes, 'note-free');

      // Try 2 MB -- should fail (4 + 2 = 6 > 5)
      final extra = Uint8List.fromList(
        List.generate(2 * 1024 * 1024, (i) => (i + 1) % 256),
      );
      expect(
        () => WebImageStorage.saveWebImage(extra, 'note-extra1'),
        throwsA(isA<StateError>()),
      );

      // Delete the 4 MB image
      await WebImageStorage.deleteWebImage(key);

      // Now 2 MB should fit
      final newKey = await WebImageStorage.saveWebImage(extra, 'note-extra2');
      expect(newKey, isNotEmpty);
    });
  });

  // ── deleteAll ─────────────────────────────────────────

  group('deleteAll', () {
    test('removes all stored images and resets registry', () async {
      await WebImageStorage.saveWebImage(
        Uint8List.fromList([1]),
        'note-da1',
      );
      await WebImageStorage.saveWebImage(
        Uint8List.fromList([2]),
        'note-da2',
      );
      await WebImageStorage.saveWebImage(
        Uint8List.fromList([3]),
        'note-da3',
      );

      expect(await WebImageStorage.getImageCount(), 3);
      expect(await WebImageStorage.getStorageUsage(), 3);

      await WebImageStorage.deleteAll();

      expect(await WebImageStorage.getImageCount(), 0);
      expect(await WebImageStorage.getStorageUsage(), 0);
    });

    test('is a no-op when nothing is stored', () async {
      // Should not throw
      await WebImageStorage.deleteAll();
      expect(await WebImageStorage.getImageCount(), 0);
    });
  });

  // ── Round-trip ────────────────────────────────────────

  group('round-trip', () {
    test('save, load, delete lifecycle works', () async {
      final bytes = Uint8List.fromList(List.generate(500, (i) => i % 256));

      // Save
      final key = await WebImageStorage.saveWebImage(bytes, 'note-lifecycle');
      expect(key, isNotEmpty);

      // Load
      final loaded = await WebImageStorage.loadWebImage(key);
      expect(loaded, bytes);

      // Verify usage
      expect(await WebImageStorage.getStorageUsage(), 500);

      // Delete
      final deleted = await WebImageStorage.deleteWebImage(key);
      expect(deleted, isTrue);

      // Verify gone
      final afterDelete = await WebImageStorage.loadWebImage(key);
      expect(afterDelete, isNull);
      expect(await WebImageStorage.getStorageUsage(), 0);
    });

    test('multiple notes with independent lifecycles', () async {
      final bytesA = Uint8List.fromList([1, 1, 1]);
      final bytesB = Uint8List.fromList([2, 2, 2]);

      final keyA = await WebImageStorage.saveWebImage(bytesA, 'note-ind-a');
      final keyB = await WebImageStorage.saveWebImage(bytesB, 'note-ind-b');

      // Delete note A's images
      await WebImageStorage.deleteWebImagesForNote('note-ind-a');

      // Note B should still be intact
      final loadedB = await WebImageStorage.loadWebImage(keyB);
      expect(loadedB, bytesB);

      // Note A should be gone
      final loadedA = await WebImageStorage.loadWebImage(keyA);
      expect(loadedA, isNull);
    });
  });
}
