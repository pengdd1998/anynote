import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/database/app_database.dart';
import 'package:anynote/features/compose/data/compose_providers.dart';
import 'package:anynote/features/compose/domain/post_template.dart';
import 'package:anynote/features/compose/presentation/template_editor_screen.dart';
import 'package:anynote/features/compose/presentation/template_selector_sheet.dart';
import '../../../helpers/test_app_helper.dart';

/// Created-at value that sorts a seeded template before the built-in seeds
/// (which use `created_at = 0`), keeping its card visible in the sheet's
/// viewport without scrolling (the list is ordered oldest-first and lazily
/// built by the ListView).
final _earlyCreatedAt = DateTime.fromMillisecondsSinceEpoch(-10000);

/// Builds a [PostTemplate] for seeding tests.
PostTemplate _template(
  String id,
  String name, {
  bool isBuiltIn = false,
  DateTime? createdAt,
}) =>
    PostTemplate(
      id: id,
      name: name,
      description: '测试模板描述',
      systemPrompt: 'Write a test post.',
      isBuiltIn: isBuiltIn,
      createdAt: createdAt ?? DateTime(2026, 1, 1),
    );

/// Inserts templates via raw SQL (mirrors how the app seeds/creates them).
Future<void> _insertTemplates(AppDatabase db, List<PostTemplate> templates) async {
  for (final t in templates) {
    await db.customStatement(
      'INSERT INTO post_templates '
      '(id, name, description, system_prompt, structure_hint, '
      'tone_hint, is_built_in, created_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [
        t.id,
        t.name,
        t.description,
        t.systemPrompt,
        t.structureHint,
        t.toneHint,
        t.isBuiltIn ? 1 : 0,
        t.createdAt.millisecondsSinceEpoch ~/ 1000,
      ],
    );
  }
}

/// Host screen that opens the selector sheet like the compose flow does.
Widget _host({
  PostTemplate? selectedTemplate,
  required ValueChanged<PostTemplate?> onSelected,
}) {
  return Scaffold(
    body: Builder(
      builder: (context) => Center(
        child: FilledButton(
          onPressed: () => TemplateSelectorSheet.show(
            context,
            selectedTemplate: selectedTemplate,
            onSelected: onSelected,
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );
}

void main() {
  group('TemplateSelectorSheet', () {
    testWidgets('shows a no-template option that clears the provider selection',
        (tester) async {
      final db = createTestDatabase();
      await _insertTemplates(db, [_template('tpl-user', '我的模板', createdAt: _earlyCreatedAt)]);

      final selected = <PostTemplate?>[];
      final handle = await pumpScreen(
        tester,
        _host(
          selectedTemplate: _template('tpl-user', '我的模板'),
          onSelected: selected.add,
        ),
        overrides: defaultProviderOverrides(db: db),
      );

      // Seed a template selection in the compose session provider.
      handle.container
          .read(composeSessionProvider.notifier)
          .setTemplate(_template('tpl-user', '我的模板'));
      await tester.pump();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // The no-template option and the template card are both listed.
      expect(find.text('无模板'), findsOneWidget);
      expect(find.text('我的模板'), findsOneWidget);

      await tester.tap(find.text('无模板'));
      await tester.pumpAndSettle();

      // The provider selection is cleared and the callback received null.
      expect(
        handle.container.read(composeSessionProvider).selectedTemplate,
        isNull,
      );
      expect(selected, [isNull]);
      // The sheet closed.
      expect(find.text('无模板'), findsNothing);

      await handle.dispose();
    });

    testWidgets(
        'user templates offer edit and delete; built-in templates do not',
        (tester) async {
      final db = createTestDatabase();
      await _insertTemplates(db, [
        _template('tpl-user', '我的模板', createdAt: _earlyCreatedAt),
        _template(
          'tpl-builtin',
          '内置模板',
          isBuiltIn: true,
          // A bit after the user template, still before the built-in seeds.
          createdAt: DateTime.fromMillisecondsSinceEpoch(-5000),
        ),
      ]);

      final handle = await pumpScreen(
        tester,
        _host(onSelected: (_) {}),
        overrides: defaultProviderOverrides(db: db),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Only the user-created template has the actions menu.
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
      expect(find.text('我的模板'), findsOneWidget);
      expect(find.text('内置模板'), findsOneWidget);

      // Open the actions sheet via the menu.
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text('编辑模板'), findsOneWidget);
      expect(find.text('删除模板'), findsOneWidget);

      // Choose edit: the editor opens pre-filled with the template.
      await tester.tap(find.text('编辑模板'));
      await tester.pumpAndSettle();

      expect(find.byType(TemplateEditorScreen), findsOneWidget);
      // App bar title shows the template name and the name field is pre-filled.
      expect(find.text('我的模板'), findsWidgets);
      expect(find.text('Write a test post.'), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('long-press on a user template opens the actions sheet',
        (tester) async {
      final db = createTestDatabase();
      await _insertTemplates(db, [_template('tpl-user', '我的模板', createdAt: _earlyCreatedAt)]);

      final handle = await pumpScreen(
        tester,
        _host(onSelected: (_) {}),
        overrides: defaultProviderOverrides(db: db),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.longPress(find.text('我的模板'));
      await tester.pumpAndSettle();

      expect(find.text('编辑模板'), findsOneWidget);
      expect(find.text('删除模板'), findsOneWidget);

      // Close the actions sheet.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      await handle.dispose();
    });

    testWidgets('delete confirms and removes the template', (tester) async {
      final db = createTestDatabase();
      await _insertTemplates(db, [_template('tpl-user', '我的模板', createdAt: _earlyCreatedAt)]);

      final handle = await pumpScreen(
        tester,
        _host(onSelected: (_) {}),
        overrides: defaultProviderOverrides(db: db),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除模板'));
      await tester.pumpAndSettle();

      // Confirmation dialog appears.
      expect(find.text('确定要删除「我的模板」吗？此操作无法撤销。'), findsOneWidget);

      // Confirm the deletion.
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();

      // The row is gone from the database and the list refreshed.
      final row = await db.postTemplateDao.getById('tpl-user');
      expect(row, isNull);
      expect(find.text('我的模板'), findsNothing);

      // Let the confirmation snackbar dismiss to avoid pending timers.
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      await handle.dispose();
    });

    testWidgets('delete can be cancelled', (tester) async {
      final db = createTestDatabase();
      await _insertTemplates(db, [_template('tpl-user', '我的模板', createdAt: _earlyCreatedAt)]);

      final handle = await pumpScreen(
        tester,
        _host(onSelected: (_) {}),
        overrides: defaultProviderOverrides(db: db),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除模板'));
      await tester.pumpAndSettle();

      // Cancel: the template stays.
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      final row = await db.postTemplateDao.getById('tpl-user');
      expect(row, isNotNull);
      expect(find.text('我的模板'), findsOneWidget);

      await handle.dispose();
    });
  });
}
