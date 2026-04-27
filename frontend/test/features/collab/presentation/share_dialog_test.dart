import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/collab/presence_indicator.dart';
import 'package:anynote/features/collab/presentation/share_dialog.dart';
import 'package:anynote/l10n/app_localizations.dart';

import '../../../helpers/test_app_helper.dart';

// ---------------------------------------------------------------------------
// Fake providers
// ---------------------------------------------------------------------------

class _FakePresenceNotifier extends PresenceNotifier {
  _FakePresenceNotifier(Map<String, RoomPresence> initial)
      : super(_FakeRefForPresence()) {
    // Set state after super constructor completes.
    state = initial;
  }
}

class _FakeRefForPresence implements Ref {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

Future<void> pumpShareSheet(
  WidgetTester tester, {
  Map<String, RoomPresence> presence = const {},
}) async {
  final allOverrides = <Override>[
    ...defaultProviderOverrides(),
    presenceProvider.overrideWith((ref) {
      return _FakePresenceNotifier(presence);
    }),
  ];

  await tester.pumpWidget(
    ProviderScope(
      overrides: allOverrides,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showShareBottomSheet(context, 'note-123');
                },
                child: const Text('Open Share Sheet'),
              );
            },
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('Open Share Sheet'));
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ShareNoteSheet', () {
    testWidgets('renders without errors', (tester) async {
      await pumpShareSheet(tester);

      // Verify the sheet opened and shows the title.
      expect(find.byType(ShareNoteSheet), findsOneWidget);
    });

    testWidgets('renders share icon', (tester) async {
      await pumpShareSheet(tester);

      expect(find.byIcon(Icons.people_outline), findsOneWidget);
    });

    testWidgets('renders invite code section', (tester) async {
      await pumpShareSheet(tester);

      // The invite code section has a copy button.
      expect(find.byIcon(Icons.copy), findsWidgets);
    });

    testWidgets('renders Copy Invite Code button', (tester) async {
      await pumpShareSheet(tester);

      expect(find.text('Copy Invite Code'), findsOneWidget);
    });

    testWidgets('renders Enter Invite Code section', (tester) async {
      await pumpShareSheet(tester);

      expect(find.text('Enter Invite Code'), findsOneWidget);
    });

    testWidgets('renders join button', (tester) async {
      await pumpShareSheet(tester);

      expect(find.byIcon(Icons.login), findsWidgets);
    });

    testWidgets('renders E2E security notice', (tester) async {
      await pumpShareSheet(tester);

      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });

    testWidgets('renders text field for invite code', (tester) async {
      await pumpShareSheet(tester);

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('renders without error when presence is empty', (tester) async {
      await pumpShareSheet(tester);

      // No overflow or layout errors.
      expect(find.byType(ShareNoteSheet), findsOneWidget);
    });

    testWidgets('shows presence info when users are in room', (tester) async {
      await pumpShareSheet(
        tester,
        presence: {
          'user-1': RoomPresence(
            userId: 'user-1',
            displayName: 'Alice',
            joinedAt: DateTime.now(),
          ),
        },
      );

      // Presence section should show something about viewing.
      expect(find.textContaining('viewing'), findsWidgets);
    });
  });
}
