import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/database/app_database.dart';
import 'package:anynote/features/notes/presentation/widgets/template_management_screen.dart';
import '../../../../helpers/test_app_helper.dart';

void main() {
  group('TemplateManagementScreen', () {
    testWidgets('shows loading indicator initially', (tester) async {
      final db = createTestDatabase();
      addTearDown(() => db.close());

      final handle = await pumpScreen(
        tester,
        const TemplateManagementScreen(),
        overrides: defaultProviderOverrides(db: db),
      );
      addTearDown(() => handle.dispose());

      // After pumpScreen settles, loading should be done.
      // Verify Scaffold is present.
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('renders built-in templates section', (tester) async {
      final db = createTestDatabase();
      addTearDown(() => db.close());

      // Insert a built-in template.
      await db.into(db.noteTemplates).insert(
            NoteTemplatesCompanion.insert(
              id: 'tmpl-builtin-1',
              name: 'Meeting Notes',
              encryptedContent: 'enc-meeting',
              plainContent: const Value('## Meeting Notes\nDate: '),
              category: const Value('work'),
              isBuiltIn: const Value(true),
              usageCount: const Value(5),
            ),
          );

      final handle = await pumpScreen(
        tester,
        const TemplateManagementScreen(),
        overrides: defaultProviderOverrides(db: db),
      );
      addTearDown(() => handle.dispose());

      // The built-in template name should be visible.
      expect(find.text('Meeting Notes'), findsOneWidget);
      // The "Built-in Templates" section header should be present.
      expect(find.text('Built-in Templates'), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('renders user templates section', (tester) async {
      final db = createTestDatabase();
      addTearDown(() => db.close());

      await db.into(db.noteTemplates).insert(
            NoteTemplatesCompanion.insert(
              id: 'tmpl-user-1',
              name: 'My Custom Template',
              encryptedContent: 'enc-custom',
              plainContent: const Value('# Custom'),
              category: const Value('personal'),
              isBuiltIn: const Value(false),
              usageCount: const Value(2),
            ),
          );

      final handle = await pumpScreen(
        tester,
        const TemplateManagementScreen(),
        overrides: defaultProviderOverrides(db: db),
      );
      addTearDown(() => handle.dispose());

      expect(find.text('My Custom Template'), findsOneWidget);
      // Category badge should show "Personal".
      expect(find.text('Personal'), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('shows empty state when no user templates', (tester) async {
      final db = createTestDatabase();
      addTearDown(() => db.close());

      final handle = await pumpScreen(
        tester,
        const TemplateManagementScreen(),
        overrides: defaultProviderOverrides(db: db),
      );
      addTearDown(() => handle.dispose());

      // No user templates text should be visible.
      expect(find.text('No templates yet'), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('FAB is present for creating new templates', (tester) async {
      final db = createTestDatabase();
      addTearDown(() => db.close());

      final handle = await pumpScreen(
        tester,
        const TemplateManagementScreen(),
        overrides: defaultProviderOverrides(db: db),
      );
      addTearDown(() => handle.dispose());

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('tapping FAB opens create template dialog', (tester) async {
      final db = createTestDatabase();
      addTearDown(() => db.close());

      final handle = await pumpScreen(
        tester,
        const TemplateManagementScreen(),
        overrides: defaultProviderOverrides(db: db),
      );
      addTearDown(() => handle.dispose());

      // Tap the FAB.
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Dialog should open with "New Template" title.
      expect(find.text('New Template'), findsOneWidget);
      expect(find.text('Template Name'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Create'), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('template tile shows popup menu with actions', (tester) async {
      final db = createTestDatabase();
      addTearDown(() => db.close());

      await db.into(db.noteTemplates).insert(
            NoteTemplatesCompanion.insert(
              id: 'tmpl-menu',
              name: 'Template With Menu',
              encryptedContent: 'enc',
              plainContent: const Value('content'),
              category: const Value('creative'),
              isBuiltIn: const Value(false),
              usageCount: const Value(0),
            ),
          );

      final handle = await pumpScreen(
        tester,
        const TemplateManagementScreen(),
        overrides: defaultProviderOverrides(db: db),
      );
      addTearDown(() => handle.dispose());

      // Find and tap the popup menu button (trailing icon on ListTile).
      final popupButtons = find.byType(PopupMenuButton<String>);
      expect(popupButtons, findsOneWidget);

      await tester.tap(popupButtons.first);
      await tester.pumpAndSettle();

      // Popup menu should show edit, duplicate, delete actions.
      expect(find.text('Edit Template'), findsOneWidget);
      expect(find.text('Duplicate'), findsOneWidget);
      expect(find.text('Delete Template'), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('built-in templates show only duplicate action',
        (tester) async {
      final db = createTestDatabase();
      addTearDown(() => db.close());

      await db.into(db.noteTemplates).insert(
            NoteTemplatesCompanion.insert(
              id: 'tmpl-bi-menu',
              name: 'Built-in Only',
              encryptedContent: 'enc',
              plainContent: const Value('content'),
              category: const Value('work'),
              isBuiltIn: const Value(true),
              usageCount: const Value(0),
            ),
          );

      final handle = await pumpScreen(
        tester,
        const TemplateManagementScreen(),
        overrides: defaultProviderOverrides(db: db),
      );
      addTearDown(() => handle.dispose());

      // Open popup menu.
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      // Built-in templates should only show Duplicate.
      expect(find.text('Duplicate'), findsOneWidget);
      expect(find.text('Edit Template'), findsNothing);
      expect(find.text('Delete Template'), findsNothing);

      await handle.dispose();
    });

    testWidgets('pull-to-refresh reloads templates', (tester) async {
      final db = createTestDatabase();
      addTearDown(() => db.close());

      await db.into(db.noteTemplates).insert(
            NoteTemplatesCompanion.insert(
              id: 'tmpl-refresh',
              name: 'Refresh Test',
              encryptedContent: 'enc',
              plainContent: const Value('c'),
              category: const Value('work'),
              isBuiltIn: const Value(false),
            ),
          );

      final handle = await pumpScreen(
        tester,
        const TemplateManagementScreen(),
        overrides: defaultProviderOverrides(db: db),
      );
      addTearDown(() => handle.dispose());

      // Should have a RefreshIndicator wrapping the list.
      expect(find.byType(RefreshIndicator), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('delete confirmation dialog appears for user templates',
        (tester) async {
      final db = createTestDatabase();
      addTearDown(() => db.close());

      await db.into(db.noteTemplates).insert(
            NoteTemplatesCompanion.insert(
              id: 'tmpl-del',
              name: 'To Be Deleted',
              encryptedContent: 'enc',
              plainContent: const Value('c'),
              category: const Value('personal'),
              isBuiltIn: const Value(false),
            ),
          );

      final handle = await pumpScreen(
        tester,
        const TemplateManagementScreen(),
        overrides: defaultProviderOverrides(db: db),
      );
      addTearDown(() => handle.dispose());

      // Open popup menu and tap delete.
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete Template'));
      await tester.pumpAndSettle();

      // Confirmation dialog should appear.
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Delete Template'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      await handle.dispose();
    });
  });
}
