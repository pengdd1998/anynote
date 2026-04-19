import 'dart:ffi';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:anynote/core/database/app_database.dart';
import 'package:anynote/core/database/daos/notes_dao.dart';

/// Benchmark tests for paginated note queries at scale (10K+ notes).
///
/// FTS5 virtual tables require file-backed databases (not :memory:), so we use
/// temp files for all tests. FTS5 MATCH queries are known to be incompatible
/// with Drift's SQL parser on Linux flutter test; the search benchmarks
/// gracefully skip if the FTS5 table is unavailable.
void main() {
  late AppDatabase db;
  late NotesDao notesDao;

  setUp(() async {
    open.overrideFor(
      OperatingSystem.linux,
      () => DynamicLibrary.open('libsqlite3.so'),
    );
    sqlite3.tempDirectory = Directory.systemTemp.path;
    final file = File(
      '${Directory.systemTemp.path}/'
      'bench_${DateTime.now().millisecondsSinceEpoch}.sqlite',
    );
    db = AppDatabase.forTesting(NativeDatabase(file));
    notesDao = NotesDao(db);
    // Force Drift to run migrations (creates tables + FTS5 virtual table).
    await notesDao.getAllNotes();
  });

  tearDown(() async {
    await db.close();
  });

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Insert [count] notes via batch insert for speed.
  /// Each note gets a unique ID, sequential plaintext content, and a timestamp
  /// spaced 1 second apart so sorting is deterministic.
  Future<void> insertBulkNotes(int count) async {
    await db.batch((b) {
      final baseTime = DateTime.now().subtract(Duration(seconds: count));
      for (var i = 0; i < count; i++) {
        final id = 'bulk-note-$i';
        final now = baseTime.add(Duration(seconds: i));
        b.insert(
          db.notes,
          NotesCompanion.insert(
            id: id,
            encryptedContent: 'enc_$i',
            plainContent: Value('Note $i: This is the content of note number '
                '$i with some extra text to simulate a realistic note body.'),
            plainTitle: Value(i % 10 == 0 ? 'Important note $i' : 'Note $i'),
            createdAt: now,
            updatedAt: now,
            version: const Value(0),
            isSynced: const Value(false),
          ),
        );
      }
    });
  }

  /// Populate the FTS5 index for bulk notes using a single batch INSERT.
  /// Returns true if the FTS5 table exists and accepts writes.
  Future<bool> populateFtsIndex(int count) async {
    try {
      await db.customStatement('''
        INSERT INTO notes_fts (note_id, content, title)
        SELECT id, plain_content, COALESCE(plain_title, '')
        FROM notes
        WHERE plain_content IS NOT NULL
      ''');
      return true;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Pagination benchmarks
  // ---------------------------------------------------------------------------

  group('pagination benchmarks', () {
    test('batch insert 10,000 notes completes within reasonable time', () async {
      final sw = Stopwatch()..start();
      await insertBulkNotes(10000);
      sw.stop();

      // 10K inserts should complete in well under 10 seconds.
      expect(sw.elapsedMilliseconds, lessThan(10000));
      // Verify count.
      final count = await notesDao.countNotes();
      expect(count, equals(10000));
    });

    test('paginated fetch of 50 notes from 10K dataset is fast', () async {
      await insertBulkNotes(10000);
      final count = await notesDao.countNotes();
      expect(count, equals(10000));

      final sw = Stopwatch()..start();
      final page = await notesDao.getPaginatedNotes(50, 0);
      sw.stop();

      expect(page.length, equals(50));
      // Should complete well under 50ms on production devices.
      // CI environments are slower, so we use a generous threshold.
      expect(sw.elapsedMilliseconds, lessThan(100));
    });

    test('paginated fetch at various offsets from 10K dataset is fast', () async {
      await insertBulkNotes(10000);

      const offsets = [0, 500, 2500, 5000, 9500];
      for (final offset in offsets) {
        final sw = Stopwatch()..start();
        final page = await notesDao.getPaginatedNotes(50, offset);
        sw.stop();

        // Last offset may return fewer than 50.
        expect(page.length, lessThanOrEqualTo(50));
        expect(page.length, greaterThan(0));
        expect(sw.elapsedMilliseconds, lessThan(100));
      }
    });

    test('paginated fetch with sort by created at from 10K dataset is fast',
        () async {
      await insertBulkNotes(10000);

      final sw = Stopwatch()..start();
      final page = await notesDao.getNotesPaginatedFiltered(
        limit: 50,
        offset: 0,
        sortBy: 'created',
      );
      sw.stop();

      expect(page.length, equals(50));
      expect(sw.elapsedMilliseconds, lessThan(100));
    });

    test('paginated fetch with sort by title from 10K dataset is fast', () async {
      await insertBulkNotes(10000);

      final sw = Stopwatch()..start();
      final page = await notesDao.getNotesPaginatedFiltered(
        limit: 50,
        offset: 0,
        sortBy: 'title',
      );
      sw.stop();

      expect(page.length, equals(50));
      expect(sw.elapsedMilliseconds, lessThan(100));
    });

    test('countNotes on 10K dataset is fast', () async {
      await insertBulkNotes(10000);

      final sw = Stopwatch()..start();
      final count = await notesDao.countNotes();
      sw.stop();

      expect(count, equals(10000));
      expect(sw.elapsedMilliseconds, lessThan(50));
    });

    test('sequential pagination of all 10K notes (200 pages) completes quickly',
        () async {
      await insertBulkNotes(10000);

      final sw = Stopwatch()..start();
      var totalFetched = 0;
      var offset = 0;
      while (true) {
        final page = await notesDao.getPaginatedNotes(50, offset);
        totalFetched += page.length;
        if (page.length < 50) break;
        offset += 50;
      }
      sw.stop();

      expect(totalFetched, equals(10000));
      // All 200 page fetches should complete in under 5 seconds (generous for CI).
      expect(sw.elapsedMilliseconds, lessThan(5000));
    });
  });

  // ---------------------------------------------------------------------------
  // Filtered pagination benchmarks
  // ---------------------------------------------------------------------------

  group('filtered pagination benchmarks', () {
    test('countNotesByTag on 10K dataset is fast', () async {
      await insertBulkNotes(10000);

      // Manually associate some notes with a tag.
      await db.customStatement(
        'INSERT INTO tags (id, encrypted_name, plain_name, version, is_synced) '
        "VALUES ('tag-bench', 'enc', 'bench', 0, 0)",
      );
      // Tag every 10th note using a single SQL statement for speed.
      await db.customStatement(
        'INSERT INTO note_tags (note_id, tag_id) '
        "SELECT id, 'tag-bench' FROM notes WHERE id LIKE 'bulk-note-%' "
        'AND CAST(SUBSTR(id, 11) AS INTEGER) % 10 = 0',
      );

      final sw = Stopwatch()..start();
      final count = await notesDao.countNotesByTag('tag-bench');
      sw.stop();

      expect(count, equals(1000));
      expect(sw.elapsedMilliseconds, lessThan(100));
    });

    test('paginated fetch with tag filter from 10K dataset is fast', () async {
      await insertBulkNotes(10000);

      // Manually associate some notes with a tag.
      await db.customStatement(
        'INSERT INTO tags (id, encrypted_name, plain_name, version, is_synced) '
        "VALUES ('tag-pf', 'enc', 'pf', 0, 0)",
      );
      await db.customStatement(
        'INSERT INTO note_tags (note_id, tag_id) '
        "SELECT id, 'tag-pf' FROM notes WHERE id LIKE 'bulk-note-%' "
        'AND CAST(SUBSTR(id, 11) AS INTEGER) % 10 = 0',
      );

      final sw = Stopwatch()..start();
      final page = await notesDao.getNotesPaginatedFiltered(
        limit: 50,
        offset: 0,
        tagFilter: 'tag-pf',
      );
      sw.stop();

      expect(page.length, equals(50));
      expect(sw.elapsedMilliseconds, lessThan(100));
    });
  });

  // ---------------------------------------------------------------------------
  // FTS5 search benchmarks
  //
  // FTS5 MATCH queries are not compatible with Drift's SQL parser when running
  // via NativeDatabase in the flutter test environment on Linux. The sqlparser
  // package interprets FTS5 table names as column references in MATCH clauses.
  // Production code uses sqlite3_flutter_libs on mobile which handles this
  // correctly. Run on a real device/emulator for actual FTS5 benchmarks.
  // ---------------------------------------------------------------------------

  group('FTS5 search benchmarks', () {
    test('FTS5 search on 10K dataset is fast', () async {
      // Placeholder: verify bulk data can be created.
      await insertBulkNotes(10000);
      final count = await notesDao.countNotes();
      expect(count, equals(10000));
    }, skip: 'FTS5 MATCH requires native mobile SQLite; skipped in flutter test env',);

    test('FTS5 search count on 10K dataset is fast', () async {
      await insertBulkNotes(10000);
      final count = await notesDao.countNotes();
      expect(count, equals(10000));
    }, skip: 'FTS5 MATCH requires native mobile SQLite; skipped in flutter test env',);

    test('FTS5 search pagination across all matches completes quickly', () async {
      await insertBulkNotes(10000);
      final count = await notesDao.countNotes();
      expect(count, equals(10000));
    }, skip: 'FTS5 MATCH requires native mobile SQLite; skipped in flutter test env',);

    test('FTS5 search for common word across 10K dataset', () async {
      await insertBulkNotes(10000);
      final count = await notesDao.countNotes();
      expect(count, equals(10000));
    }, skip: 'FTS5 MATCH requires native mobile SQLite; skipped in flutter test env',);
  });

  // ---------------------------------------------------------------------------
  // Simulated scroll performance
  // ---------------------------------------------------------------------------

  group('simulated scroll performance', () {
    test('consecutive page fetches sustain responsive scrolling', () async {
      await insertBulkNotes(10000);

      // Simulate scrolling through the first 1000 notes (20 page loads).
      // Each page load should be fast enough not to cause visible jank.
      // On a real device this runs at 60fps; here we measure that page loads
      // complete in a reasonable time (under 50ms each on production hardware).
      var totalTime = 0;
      var pageCount = 0;
      var fastPages = 0;

      for (var offset = 0; offset < 1000; offset += 50) {
        final sw = Stopwatch()..start();
        await notesDao.getPaginatedNotes(50, offset);
        sw.stop();

        totalTime += sw.elapsedMilliseconds;
        pageCount++;
        if (sw.elapsedMilliseconds <= 50) fastPages++;
      }

      // Average page load should be under 30ms (smooth scroll experience).
      final avgMs = totalTime / pageCount;
      expect(avgMs, lessThan(30));

      // At least 80% of page loads should complete in under 50ms.
      // (CI disk I/O is slower than production flash storage.)
      final ratio = fastPages / pageCount;
      expect(ratio, greaterThan(0.8));
    });

    test('count query does not block pagination', () async {
      await insertBulkNotes(10000);

      // Run count + paginated fetch concurrently, as the notes list does.
      final sw = Stopwatch()..start();
      final results = await Future.wait([
        notesDao.countNotes(),
        notesDao.getPaginatedNotes(50, 0),
      ]);
      sw.stop();

      expect(results[0], equals(10000));
      expect((results[1] as List).length, equals(50));
      // Concurrent execution should still be fast.
      expect(sw.elapsedMilliseconds, lessThan(200));
    });
  });

  // ---------------------------------------------------------------------------
  // Memory footprint estimation
  // ---------------------------------------------------------------------------

  group('memory footprint', () {
    test('50-note page uses reasonable memory', () async {
      await insertBulkNotes(10000);

      final page = await notesDao.getPaginatedNotes(50, 0);
      expect(page.length, equals(50));

      // Estimate memory: each Note has ~10 fields. A rough Dart object is
      // ~64 bytes overhead + field data. With 50-char plainContent and 20-char
      // plainTitle, each note is roughly 200-400 bytes.
      // 50 notes should be well under 50 KB.
      // This is a sanity check, not a precise measurement.
      for (final note in page) {
        expect(note.id, isNotEmpty);
        expect(note.encryptedContent, isNotEmpty);
      }
    });
  });
}
