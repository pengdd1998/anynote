// Tests for the TagsScreen widget.
//
// Tests cover:
// - Basic rendering (title, empty state, FAB)
// - Tag list rendering when tags exist in the database
// - Create tag dialog opens and closes
// - Crypto guard shows snackbar when vault is locked

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/crypto/crypto_service.dart';
import 'package:anynote/features/tags/presentation/tags_screen.dart';
import '../../../helpers/test_app_helper.dart';

// ---------------------------------------------------------------------------
// Locked crypto fake
// ---------------------------------------------------------------------------

/// A CryptoService fake where the vault is locked (isUnlocked == false).
class _LockedCryptoService extends CryptoService {
  @override
  bool get isUnlocked => false;

  @override
  Future<bool> isInitialized() async => true;

  @override
  Future<String> encryptForItem(String itemId, String plaintext) async =>
      'enc_$plaintext';

  @override
  Future<String?> decryptForItem(String itemId, String encrypted) async =>
      encrypted.replaceFirst('enc_', '');

  @override
  Future<void> lock() async {}
}

void main() {
  group('TagsScreen - basic rendering', () {
    testWidgets('renders without errors', (tester) async {
      final handle = await pumpScreen(
        tester,
        const TagsScreen(),
        overrides: defaultProviderOverrides(),
      );

      expect(find.byType(Scaffold), findsOneWidget);
      await handle.dispose();
    });

    testWidgets('shows Tags title in app bar', (tester) async {
      final handle = await pumpScreen(
        tester,
        const TagsScreen(),
        overrides: defaultProviderOverrides(),
      );

      expect(find.text('Tags'), findsOneWidget);
      await handle.dispose();
    });

    testWidgets('shows No tags empty state', (tester) async {
      final handle = await pumpScreen(
        tester,
        const TagsScreen(),
        overrides: defaultProviderOverrides(),
      );

      expect(find.text('No tags'), findsOneWidget);
      expect(find.text('Create tags to organize your notes'), findsOneWidget);
      await handle.dispose();
    });

    testWidgets('shows FAB for creating a new tag', (tester) async {
      final handle = await pumpScreen(
        tester,
        const TagsScreen(),
        overrides: defaultProviderOverrides(),
      );

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
      await handle.dispose();
    });
  });

  group('TagsScreen - tag list', () {
    testWidgets('renders tag chips when tags exist in the database',
        (tester) async {
      final db = createTestDatabase();

      // Insert a tag directly via DAO.
      await db.tagsDao.createTag(
        id: 'tag-1',
        encryptedName: 'enc_Work',
        plainName: 'Work',
      );

      final handle = await pumpScreen(
        tester,
        const TagsScreen(),
        overrides: defaultProviderOverrides(db: db),
      );

      // Wait for the StreamBuilder to emit data.
      await tester.pumpAndSettle();

      // The tag name should be visible as a Chip.
      expect(find.text('Work'), findsOneWidget);
      expect(find.byType(Chip), findsOneWidget);
      await handle.dispose();
    });

    testWidgets('renders multiple tag chips', (tester) async {
      final db = createTestDatabase();

      await db.tagsDao.createTag(
        id: 'tag-1',
        encryptedName: 'enc_Work',
        plainName: 'Work',
      );
      await db.tagsDao.createTag(
        id: 'tag-2',
        encryptedName: 'enc_Personal',
        plainName: 'Personal',
      );

      final handle = await pumpScreen(
        tester,
        const TagsScreen(),
        overrides: defaultProviderOverrides(db: db),
      );

      await tester.pumpAndSettle();

      expect(find.text('Work'), findsOneWidget);
      expect(find.text('Personal'), findsOneWidget);
      expect(find.byType(Chip), findsNWidgets(2));
      await handle.dispose();
    });
  });

  group('TagsScreen - create dialog', () {
    testWidgets('opens create tag dialog when FAB is tapped (unlocked)',
        (tester) async {
      final handle = await pumpScreen(
        tester,
        const TagsScreen(),
        overrides: defaultProviderOverrides(),
      );

      // Tap the FAB to open the dialog.
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Dialog should be visible with the New Tag title.
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('New Tag'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Create'), findsOneWidget);
      await handle.dispose();
    });

    testWidgets('closes dialog when Cancel is tapped', (tester) async {
      final handle = await pumpScreen(
        tester,
        const TagsScreen(),
        overrides: defaultProviderOverrides(),
      );

      // Open the dialog.
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);

      // Tap Cancel.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Dialog should be dismissed.
      expect(find.byType(AlertDialog), findsNothing);
      await handle.dispose();
    });

    testWidgets('create dialog has a text field for tag name', (tester) async {
      final handle = await pumpScreen(
        tester,
        const TagsScreen(),
        overrides: defaultProviderOverrides(),
      );

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // The dialog should contain a TextField with autofocus enabled.
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.autofocus, isTrue);
      await handle.dispose();
    });
  });

  group('TagsScreen - crypto guard', () {
    testWidgets('shows snackbar when vault is locked and FAB is tapped',
        (tester) async {
      final lockedCrypto = _LockedCryptoService();
      final handle = await pumpScreen(
        tester,
        const TagsScreen(),
        overrides: defaultProviderOverrides(cryptoService: lockedCrypto),
      );

      // Tap the FAB while crypto is locked.
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // A SnackBar should appear with the unlock-required message.
      expect(find.text('Please unlock your vault first'), findsOneWidget);
      // No dialog should open.
      expect(find.byType(AlertDialog), findsNothing);
      await handle.dispose();
    });
  });
}
