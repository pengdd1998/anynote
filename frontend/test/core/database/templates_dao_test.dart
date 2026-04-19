import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/database/app_database.dart';
import 'package:anynote/core/database/daos/templates_dao.dart';

void main() {
  late AppDatabase db;
  late TemplatesDao templatesDao;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    templatesDao = TemplatesDao(db);
    // Force Drift to run migrations.
    await templatesDao.getAllTemplates();
  });

  tearDown(() async {
    await db.close();
  });

  // -- Helper --

  Future<String> createTestTemplate({
    String id = 'tpl-1',
    String name = 'Test Template',
    String encryptedContent = 'ZW5jLXRlbQ==',
    String? plainContent,
    String category = 'custom',
    bool isBuiltIn = false,
  }) {
    return templatesDao.createTemplate(
      id: id,
      name: name,
      encryptedContent: encryptedContent,
      plainContent: plainContent,
      category: category,
      isBuiltIn: isBuiltIn,
    );
  }

  // -- Create / Read --

  group('create and read', () {
    test('createTemplate inserts a template and returns its ID', () async {
      final id = await createTestTemplate(plainContent: 'Template body');
      expect(id, 'tpl-1');

      final all = await templatesDao.getAllTemplates();
      expect(all.length, 1);
      expect(all[0].id, 'tpl-1');
      expect(all[0].name, 'Test Template');
      expect(all[0].encryptedContent, 'ZW5jLXRlbQ==');
      expect(all[0].plainContent, 'Template body');
    });

    test('createTemplate without plainContent stores null', () async {
      await createTestTemplate();

      final all = await templatesDao.getAllTemplates();
      expect(all[0].plainContent, isNull);
    });

    test('createTemplate sets default category to custom', () async {
      await createTestTemplate();

      final all = await templatesDao.getAllTemplates();
      expect(all[0].category, 'custom');
    });

    test('createTemplate sets default isBuiltIn to false', () async {
      await createTestTemplate();

      final all = await templatesDao.getAllTemplates();
      expect(all[0].isBuiltIn, false);
    });

    test('createTemplate with custom category', () async {
      await createTestTemplate(category: 'meeting-notes');

      final all = await templatesDao.getAllTemplates();
      expect(all[0].category, 'meeting-notes');
    });

    test('createTemplate as built-in', () async {
      await createTestTemplate(
        id: 'tpl-builtin',
        name: 'Built-in Template',
        isBuiltIn: true,
      );

      final all = await templatesDao.getAllTemplates();
      expect(all[0].isBuiltIn, true);
    });

    test('getTemplateById returns correct template', () async {
      await createTestTemplate(id: 'tpl-byid', name: 'Find Me');

      final template = await templatesDao.getTemplateById('tpl-byid');
      expect(template.id, 'tpl-byid');
      expect(template.name, 'Find Me');
    });

    test('getAllTemplates orders by built-in first, then by name', () async {
      await createTestTemplate(id: 'tpl-c', name: 'Charlie');
      await createTestTemplate(id: 'tpl-b-builtin', name: 'Bravo', isBuiltIn: true);
      await createTestTemplate(id: 'tpl-a', name: 'Alpha');

      final all = await templatesDao.getAllTemplates();
      expect(all.length, 3);

      // Built-in first, then alphabetical
      expect(all[0].id, 'tpl-b-builtin'); // built-in
      expect(all[1].id, 'tpl-a'); // Alpha
      expect(all[2].id, 'tpl-c'); // Charlie
    });
  });

  // -- Update --

  group('update', () {
    test('updateTemplate changes name', () async {
      await createTestTemplate(id: 'tpl-upd', name: 'Old Name');

      await templatesDao.updateTemplate(
        id: 'tpl-upd',
        name: 'New Name',
      );

      final template = await templatesDao.getTemplateById('tpl-upd');
      expect(template.name, 'New Name');
    });

    test('updateTemplate changes encryptedContent and plainContent', () async {
      await createTestTemplate(
        id: 'tpl-upd-content',
        encryptedContent: 'old-enc',
        plainContent: 'old plain',
      );

      await templatesDao.updateTemplate(
        id: 'tpl-upd-content',
        encryptedContent: 'new-enc',
        plainContent: 'new plain',
      );

      final template = await templatesDao.getTemplateById('tpl-upd-content');
      expect(template.encryptedContent, 'new-enc');
      expect(template.plainContent, 'new plain');
    });

    test('updateTemplate without name keeps existing value', () async {
      await createTestTemplate(
        id: 'tpl-keep-name',
        name: 'Original Name',
      );

      await templatesDao.updateTemplate(
        id: 'tpl-keep-name',
        plainContent: 'updated content',
      );

      final template = await templatesDao.getTemplateById('tpl-keep-name');
      expect(template.name, 'Original Name');
      expect(template.plainContent, 'updated content');
    });
  });

  // -- Delete --

  group('delete', () {
    test('deleteTemplate removes the template', () async {
      await createTestTemplate(id: 'tpl-del');
      expect((await templatesDao.getAllTemplates()).length, 1);

      await templatesDao.deleteTemplate('tpl-del');
      expect((await templatesDao.getAllTemplates()).length, 0);
    });

    test('deleteTemplate on non-existent ID does not throw', () async {
      // Should complete without error
      await templatesDao.deleteTemplate('nonexistent');
    });
  });

  // -- Filters --

  group('filtering', () {
    test('getBuiltInTemplates returns only built-in templates', () async {
      await createTestTemplate(id: 'tpl-custom-1', name: 'Custom A');
      await createTestTemplate(
        id: 'tpl-builtin-1',
        name: 'Built-in A',
        isBuiltIn: true,
      );
      await createTestTemplate(
        id: 'tpl-builtin-2',
        name: 'Built-in B',
        isBuiltIn: true,
      );

      final builtIn = await templatesDao.getBuiltInTemplates();
      expect(builtIn.length, 2);
      final ids = builtIn.map((t) => t.id).toSet();
      expect(ids, containsAll(['tpl-builtin-1', 'tpl-builtin-2']));
    });

    test('getCustomTemplates returns only custom templates', () async {
      await createTestTemplate(id: 'tpl-custom-1', name: 'Custom A');
      await createTestTemplate(
        id: 'tpl-builtin-1',
        name: 'Built-in A',
        isBuiltIn: true,
      );

      final custom = await templatesDao.getCustomTemplates();
      expect(custom.length, 1);
      expect(custom[0].id, 'tpl-custom-1');
    });

    test('countTemplates returns correct count', () async {
      expect(await templatesDao.countTemplates(), 0);

      await createTestTemplate(id: 'tpl-cnt-1');
      expect(await templatesDao.countTemplates(), 1);

      await createTestTemplate(id: 'tpl-cnt-2');
      expect(await templatesDao.countTemplates(), 2);

      await templatesDao.deleteTemplate('tpl-cnt-1');
      expect(await templatesDao.countTemplates(), 1);
    });
  });

  // -- Watch --

  group('watchAllTemplates', () {
    test('emits initial empty list', () async {
      final stream = templatesDao.watchAllTemplates();
      final first = await stream.first;
      expect(first, isEmpty);
    });
  });
}
