import 'dart:ffi';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:anynote/core/database/app_database.dart';
import 'package:anynote/core/database/post_template_seed.dart';
import 'package:anynote/features/compose/domain/post_template.dart';

void main() {
  group('built-in post template single source', () {
    test('seeded DB rows match kBuiltInPostTemplates names and ids',
        () async {
      open.overrideFor(
        OperatingSystem.linux,
        () => DynamicLibrary.open('libsqlite3.so'),
      );
      sqlite3.tempDirectory = Directory.systemTemp.path;
      final file = File(
        '${Directory.systemTemp.path}'
        '/post_template_seed_test_${DateTime.now().millisecondsSinceEpoch}'
        '.sqlite',
      );
      final db = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(db.close);

      // First access triggers onCreate, which runs the seeder.
      final rows = await db.postTemplateDao.getAll();

      expect(
        rows.map((r) => r.name),
        kBuiltInPostTemplates.map((t) => t.name),
      );
      expect(
        rows.map((r) => r.id),
        kBuiltInPostTemplates.map((t) => t.id),
      );
      expect(
        rows.map((r) => r.systemPrompt),
        kBuiltInPostTemplates.map((t) => t.systemPrompt),
      );
      expect(rows.map((r) => r.isBuiltIn), everyElement(isTrue));
    });

    test('domain fallback kBuiltInTemplates matches the seed rows', () {
      expect(
        kBuiltInTemplates.map((t) => t.name),
        kBuiltInPostTemplates.map((t) => t.name),
      );
      expect(
        kBuiltInTemplates.map((t) => t.systemPrompt),
        kBuiltInPostTemplates.map((t) => t.systemPrompt),
      );
      expect(
        kBuiltInTemplates.map((t) => t.id),
        kBuiltInPostTemplates.map((t) => t.id),
      );
      expect(kBuiltInTemplates.map((t) => t.isBuiltIn), everyElement(isTrue));
    });
  });
}
