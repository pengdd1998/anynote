import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/database/app_database.dart';
import 'package:anynote/core/database/daos/note_properties_dao.dart';
import 'package:anynote/features/notes/presentation/widgets/properties_sheet.dart';
import 'package:anynote/l10n/app_localizations.dart';
import 'package:anynote/main.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Unmount the widget tree and close the database to prevent Drift timer
/// leaks. Must be called at the end of each test, before assertions are done
/// or right after them.
Future<void> cleanupTest(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(Container());
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
  await db.close();
}

/// Pumps a [PropertiesSheet] bottom sheet with a fresh in-memory database.
Future<AppDatabase> pumpSheet(
  WidgetTester tester, {
  String noteId = 'test-note-1',
}) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());

  await tester.pumpWidget(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => PropertiesSheet(noteId: noteId),
                  );
                },
                child: const Text('Open Sheet'),
              );
            },
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('Open Sheet'));
  await tester.pumpAndSettle();

  return db;
}

typedef SeedAction = Future<void> Function(AppDatabase db);

/// Pumps a [PropertiesSheet] with a database that already has data pre-loaded.
Future<AppDatabase> pumpSheetWithData(
  WidgetTester tester, {
  required String noteId,
  required List<SeedAction> seedActions,
}) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());

  // Seed data before mounting the widget.
  for (final action in seedActions) {
    await action(db);
  }

  await tester.pumpWidget(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => PropertiesSheet(noteId: noteId),
                  );
                },
                child: const Text('Open Sheet'),
              );
            },
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('Open Sheet'));
  await tester.pumpAndSettle();

  return db;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('PropertiesSheet', () {
    testWidgets('renders Properties header', (tester) async {
      final db = await pumpSheet(tester);
      expect(find.text('Properties'), findsOneWidget);
      await cleanupTest(tester, db);
    });

    testWidgets('renders empty state when no properties', (tester) async {
      final db = await pumpSheet(tester);
      expect(find.text('No properties'), findsOneWidget);
      expect(
        find.text('Add custom metadata to this note'),
        findsOneWidget,
      );
      await cleanupTest(tester, db);
    });

    testWidgets('empty state has Add Property button', (tester) async {
      final db = await pumpSheet(tester);
      expect(find.text('Add Property'), findsOneWidget);
      await cleanupTest(tester, db);
    });

    testWidgets('header has close button', (tester) async {
      final db = await pumpSheet(tester);
      expect(find.byIcon(Icons.close), findsOneWidget);
      await cleanupTest(tester, db);
    });

    testWidgets('tapping Add Property button shows dialog', (tester) async {
      final db = await pumpSheet(tester);

      // Tap the "Add Property" button in the empty state.
      await tester.tap(find.widgetWithText(FilledButton, 'Add Property'));
      await tester.pumpAndSettle();

      // The dialog should appear with "Add Property" title.
      expect(find.text('Add Property'), findsAtLeast(1));
      await cleanupTest(tester, db);
    });

    testWidgets('renders property list when properties exist', (tester) async {
      const noteId = 'prop-test-note';
      final db = await pumpSheetWithData(
        tester,
        noteId: noteId,
        seedActions: [
          (db) => db.notesDao.createNote(
                id: noteId,
                encryptedContent: 'enc',
                plainTitle: 'Prop Test',
                plainContent: 'content',
              ),
          (db) => db.notePropertiesDao.createTextProperty(
                id: 'prop-1',
                noteId: noteId,
                key: 'status',
                value: 'Todo',
              ),
        ],
      );

      // The property tile should show the display name and value.
      expect(find.text('Status'), findsOneWidget);
      expect(find.text('Todo'), findsOneWidget);
      await cleanupTest(tester, db);
    });

    testWidgets('property tile has edit and delete buttons', (tester) async {
      const noteId = 'prop-btn-note';
      final db = await pumpSheetWithData(
        tester,
        noteId: noteId,
        seedActions: [
          (db) => db.notesDao.createNote(
                id: noteId,
                encryptedContent: 'enc',
                plainTitle: 'Btn Test',
                plainContent: 'content',
              ),
          (db) => db.notePropertiesDao.createTextProperty(
                id: 'prop-btn-1',
                noteId: noteId,
                key: 'priority',
                value: 'High',
              ),
        ],
      );

      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      await cleanupTest(tester, db);
    });

    testWidgets('delete shows confirmation dialog', (tester) async {
      const noteId = 'prop-del-note';
      final db = await pumpSheetWithData(
        tester,
        noteId: noteId,
        seedActions: [
          (db) => db.notesDao.createNote(
                id: noteId,
                encryptedContent: 'enc',
                plainTitle: 'Del Test',
                plainContent: 'content',
              ),
          (db) => db.notePropertiesDao.createTextProperty(
                id: 'prop-del-1',
                noteId: noteId,
                key: 'status',
                value: 'Done',
              ),
        ],
      );

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.text('Delete Property'), findsOneWidget);
      expect(
        find.text('Remove this property from the note?'),
        findsOneWidget,
      );
      await cleanupTest(tester, db);
    });

    testWidgets('renders number property with value display', (tester) async {
      const noteId = 'prop-num-note';
      final db = await pumpSheetWithData(
        tester,
        noteId: noteId,
        seedActions: [
          (db) => db.notesDao.createNote(
                id: noteId,
                encryptedContent: 'enc',
                plainTitle: 'Num Test',
                plainContent: 'content',
              ),
          (db) => db.notePropertiesDao.createNumberProperty(
                id: 'prop-num-1',
                noteId: noteId,
                key: 'cost',
                value: 42.5,
              ),
        ],
      );

      // "Cost" is formatted from snake_case key, "42.5" is the number value.
      expect(find.text('Cost'), findsOneWidget);
      expect(find.text('42.5'), findsOneWidget);
      await cleanupTest(tester, db);
    });
  });

  group('PropertyType', () {
    test('propertyTypeFromString converts correctly', () {
      expect(propertyTypeFromString('text'), PropertyType.text);
      expect(propertyTypeFromString('number'), PropertyType.number);
      expect(propertyTypeFromString('date'), PropertyType.date);
      expect(propertyTypeFromString('unknown'), PropertyType.text);
    });

    test('propertyTypeToString converts correctly', () {
      expect(propertyTypeToString(PropertyType.text), 'text');
      expect(propertyTypeToString(PropertyType.number), 'number');
      expect(propertyTypeToString(PropertyType.date), 'date');
    });
  });

  group('BuiltInProperties', () {
    test('contains expected property keys', () {
      expect(BuiltInProperties.properties.containsKey('status'), isTrue);
      expect(BuiltInProperties.properties.containsKey('priority'), isTrue);
      expect(BuiltInProperties.properties.containsKey('due_date'), isTrue);
      expect(BuiltInProperties.properties.containsKey('start_date'), isTrue);
    });

    test('getInfo returns null for unknown key', () {
      expect(BuiltInProperties.getInfo('nonexistent'), isNull);
    });

    test('status property has options', () {
      final info = BuiltInProperties.getInfo('status')!;
      expect(info.options, isNotNull);
      expect(info.options!.isNotEmpty, isTrue);
      expect(info.options, contains('Todo'));
      expect(info.options, contains('Done'));
    });

    test('priority property has options', () {
      final info = BuiltInProperties.getInfo('priority')!;
      expect(info.options, isNotNull);
      expect(info.options, contains('High'));
      expect(info.options, contains('Low'));
    });
  });
}
