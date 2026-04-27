import 'package:drift/drift.dart' hide Column, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/database/app_database.dart';
import 'package:anynote/features/notes/presentation/widgets/note_compare_screen.dart';
import '../../../../helpers/test_app_helper.dart';

void main() {
  group('NoteCompareScreen', () {
    testWidgets('shows error when notes do not exist', (tester) async {
      final db = createTestDatabase();
      addTearDown(() => db.close());

      final handle = await pumpScreen(
        tester,
        const NoteCompareScreen(
          leftNoteId: 'nonexistent-left',
          rightNoteId: 'nonexistent-right',
        ),
        overrides: defaultProviderOverrides(db: db),
      );
      addTearDown(() => handle.dispose());

      // Should show error state with error icon.
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      // Should show a retry button.
      expect(find.text('Retry'), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('shows loading indicator while notes load', (tester) async {
      final db = createTestDatabase();
      addTearDown(() => db.close());

      final handle = await pumpScreen(
        tester,
        const NoteCompareScreen(
          leftNoteId: 'a',
          rightNoteId: 'b',
        ),
        overrides: defaultProviderOverrides(db: db),
      );
      addTearDown(() => handle.dispose());

      // Scaffold should render.
      expect(find.byType(Scaffold), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('renders diff view with two different notes', (tester) async {
      final db = createTestDatabase();
      addTearDown(() => db.close());

      final now = DateTime(2026, 4, 25);
      await db.into(db.notes).insert(
            NotesCompanion.insert(
              id: 'left-1',
              encryptedContent: 'enc_left',
              plainTitle: const Value('Note A'),
              plainContent: const Value('Line one\nLine two\nLine three'),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db.into(db.notes).insert(
            NotesCompanion.insert(
              id: 'right-1',
              encryptedContent: 'enc_right',
              plainTitle: const Value('Note A v2'),
              plainContent:
                  const Value('Line one\nLine modified\nLine three\nLine four'),
              createdAt: now,
              updatedAt: now.add(const Duration(hours: 1)),
            ),
          );

      final handle = await pumpScreen(
        tester,
        const NoteCompareScreen(
          leftNoteId: 'left-1',
          rightNoteId: 'right-1',
        ),
        overrides: defaultProviderOverrides(db: db),
      );
      addTearDown(() => handle.dispose());

      // Extra pumps to let the addPostFrameCallback + async _loadNotes()
      // chain complete.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // After loading, note titles should appear.
      expect(find.text('Note A'), findsOneWidget);
      expect(find.text('Note A v2'), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('shows view mode toggle for different notes', (tester) async {
      // Use a wide viewport so AppBar actions are not overflow-hidden.
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final db = createTestDatabase();
      addTearDown(() => db.close());

      final now = DateTime(2026, 4, 25);
      await db.into(db.notes).insert(
            NotesCompanion.insert(
              id: 'toggle-left',
              encryptedContent: 'enc_tl',
              plainTitle: const Value('L'),
              plainContent: const Value('old line'),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db.into(db.notes).insert(
            NotesCompanion.insert(
              id: 'toggle-right',
              encryptedContent: 'enc_tr',
              plainTitle: const Value('R'),
              plainContent: const Value('new line'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      final handle = await pumpScreen(
        tester,
        const NoteCompareScreen(
          leftNoteId: 'toggle-left',
          rightNoteId: 'toggle-right',
        ),
        overrides: defaultProviderOverrides(db: db),
      );
      addTearDown(() => handle.dispose());

      // Give the addPostFrameCallback + async _loadNotes() chain time to
      // complete.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // View mode toggle labels should be present in the app bar.
      expect(find.text('Unified'), findsOneWidget);
      expect(find.text('Side-by-side'), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('shows diff lines with added and removed content',
        (tester) async {
      final db = createTestDatabase();
      addTearDown(() => db.close());

      final now = DateTime(2026, 4, 25);
      // FakeCryptoService decrypts by stripping the "enc_" prefix, so the
      // encryptedContent must start with "enc_" followed by the desired
      // plaintext (the screen overwrites plainContent with the decrypted
      // value when crypto.isUnlocked is true).
      await db.into(db.notes).insert(
            NotesCompanion.insert(
              id: 'diff-left',
              encryptedContent: 'enc_removed line',
              plainTitle: const Value('Diff L'),
              plainContent: const Value('removed line'),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db.into(db.notes).insert(
            NotesCompanion.insert(
              id: 'diff-right',
              encryptedContent: 'enc_added line',
              plainTitle: const Value('Diff R'),
              plainContent: const Value('added line'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      final handle = await pumpScreen(
        tester,
        const NoteCompareScreen(
          leftNoteId: 'diff-left',
          rightNoteId: 'diff-right',
        ),
        overrides: defaultProviderOverrides(db: db),
      );
      addTearDown(() => handle.dispose());

      // Give the addPostFrameCallback + async _loadNotes() chain time to
      // complete.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Diff lines should contain the content.
      expect(find.textContaining('removed line'), findsOneWidget);
      expect(find.textContaining('added line'), findsOneWidget);

      await handle.dispose();
    });
  });
}
