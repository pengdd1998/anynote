// End-to-end widget tests for the share creation and viewing flow.
//
// Tests cover:
// - SharedNoteViewer renders for a server share with key
// - SharedNoteViewer renders password input for protected share
// - Decrypted content is displayed after successful server decryption
// - Self-contained share (payload path) works
// - Error state is shown when decryption fails

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/network/api_client.dart';
import 'package:anynote/core/share/share_service.dart';
import 'package:anynote/features/share/presentation/shared_note_viewer.dart';
import 'package:anynote/l10n/app_localizations.dart';
import 'package:anynote/main.dart';

// ---------------------------------------------------------------------------
// Fake ShareService for share flow tests
// ---------------------------------------------------------------------------

class _FakeShareService extends ShareService {
  final DecryptedSharedNote? Function({
    required String shareId,
    String? key,
    String? password,
  })? onDecryptServer;

  final DecryptedSharedNote? Function({
    required String payload,
    String? key,
    String? password,
  })? onDecryptPayload;

  _FakeShareService({this.onDecryptServer, this.onDecryptPayload})
      : super(ApiClient(baseUrl: 'http://localhost:8080'));

  @override
  Future<DecryptedSharedNote> decryptServerSharedNote({
    required String shareId,
    String? key,
    String? password,
  }) async {
    final handler = onDecryptServer;
    if (handler != null) {
      final result = handler(shareId: shareId, key: key, password: password);
      if (result != null) return result;
    }
    throw Exception('decrypt failed');
  }

  @override
  Future<DecryptedSharedNote> decryptSharedNote({
    required String payload,
    String? key,
    String? password,
  }) async {
    final handler = onDecryptPayload;
    if (handler != null) {
      final result = handler(payload: payload, key: key, password: password);
      if (result != null) return result;
    }
    throw Exception('decrypt failed');
  }
}

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

Future<void> _pumpViewer(
  WidgetTester tester, {
  required String shareId,
  String? shareKeyFragment,
  ShareService? shareService,
}) async {
  final service = shareService ?? _FakeShareService();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        shareServiceProvider.overrideWithValue(service),
        apiClientProvider.overrideWithValue(
          ApiClient(baseUrl: 'http://localhost:8080'),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: SharedNoteViewer(
          shareId: shareId,
          shareKeyFragment: shareKeyFragment,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Share flow - server share with key', () {
    testWidgets('shows decrypted title after successful server decryption',
        (tester) async {
      final service = _FakeShareService(
        onDecryptServer: (
            {required String shareId, String? key, String? password}) {
          return DecryptedSharedNote(
            title: 'My Shared Note',
            content: '# Hello World\n\nThis is shared.',
          );
        },
      );

      await _pumpViewer(
        tester,
        shareId: 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6',
        shareKeyFragment: 'someKey',
        shareService: service,
      );
      await tester.pumpAndSettle();

      expect(find.text('My Shared Note'), findsOneWidget);
    });

    testWidgets('shows error state when decryption fails', (tester) async {
      // Default _FakeShareService throws.
      await _pumpViewer(
        tester,
        shareId: 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6',
        shareKeyFragment: 'someKey',
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.link_off), findsOneWidget);
      // The full l10n string includes additional text about the link.
      expect(
        find.textContaining('Failed to decrypt the shared note'),
        findsOneWidget,
      );
    });
  });

  group('Share flow - password-protected share', () {
    testWidgets('shows password input when shareKeyFragment is null',
        (tester) async {
      await _pumpViewer(
        tester,
        shareId: 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6',
        shareKeyFragment: null,
      );

      expect(find.byIcon(Icons.lock_outline), findsNWidgets(2));
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Password Required'), findsOneWidget);
    });

    testWidgets('password field is obscured', (tester) async {
      await _pumpViewer(
        tester,
        shareId: 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6',
        shareKeyFragment: null,
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.obscureText, isTrue);
    });

    testWidgets('unlock button is present in password mode', (tester) async {
      await _pumpViewer(
        tester,
        shareId: 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6',
        shareKeyFragment: null,
      );

      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.text('Unlock'), findsOneWidget);
    });

    testWidgets('shows error after incorrect password submission',
        (tester) async {
      final service = _FakeShareService(
        onDecryptServer: (
            {required String shareId, String? key, String? password}) {
          // Always throw to simulate wrong password.
          throw Exception('wrong password');
        },
      );

      await _pumpViewer(
        tester,
        shareId: 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6',
        shareKeyFragment: null,
        shareService: service,
      );

      // Enter a password and submit.
      await tester.enterText(find.byType(TextField), 'wrongpass');
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      // The error text "Incorrect password." is displayed via the
      // TextField's InputDecoration errorText, rendered as a sub-widget.
      expect(find.textContaining('Incorrect password'), findsOneWidget);
    });
  });

  group('Share flow - self-contained share (payload path)', () {
    testWidgets('uses payload decryption for non-hex share ID', (tester) async {
      var payloadCalled = false;
      final service = _FakeShareService(
        onDecryptPayload: (
            {required String payload, String? key, String? password}) {
          payloadCalled = true;
          return DecryptedSharedNote(
            title: 'Payload Note',
            content: 'Content from payload path',
          );
        },
      );

      await _pumpViewer(
        tester,
        shareId: 'SGVsbG8gV29ybGQ',
        shareKeyFragment: 'someKey',
        shareService: service,
      );
      await tester.pumpAndSettle();

      expect(payloadCalled, isTrue);
      expect(find.text('Payload Note'), findsOneWidget);
    });
  });

  group('Share flow - Scaffold structure', () {
    testWidgets('has Scaffold with AppBar showing Share Note title',
        (tester) async {
      await _pumpViewer(
        tester,
        shareId: 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6',
        shareKeyFragment: null,
      );

      // Get localization from the widget context
      final BuildContext context =
          tester.element(find.byType(SharedNoteViewer));
      final l10n = AppLocalizations.of(context)!;

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text(l10n.shareNote), findsOneWidget);
    });
  });
}
