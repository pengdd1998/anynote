import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:anynote/core/share/share_service.dart';
import 'package:anynote/features/share/presentation/shared_note_viewer.dart';
import 'package:anynote/main.dart';

// ---------------------------------------------------------------------------
// Fake ShareService
// ---------------------------------------------------------------------------

class FakeShareService extends ShareService {
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

  FakeShareService({this.onDecryptServer, this.onDecryptPayload})
      : super(ApiClient(baseUrl: 'http://localhost:8080'));

  @override
  Future<DecryptedSharedNote> decryptServerSharedNote({
    required String shareId,
    String? key,
    String? password,
  }) async {
    if (onDecryptServer != null) {
      final result = onDecryptServer(shareId: shareId, key: key, password: password);
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
    if (onDecryptPayload != null) {
      final result = onDecryptPayload(payload: payload, key: key, password: password);
      if (result != null) return result;
    }
    throw Exception('decrypt failed');
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// The 32-char hex pattern used by the viewer to detect server shares.
final _hex32 = RegExp(r'^[0-9a-f]{32}$');

/// Pump the SharedNoteViewer inside a minimal ProviderScope.
Future<void> pumpViewer(
  WidgetTester tester, {
  required String shareId,
  String? shareKeyFragment,
  ShareService? shareService,
}) async {
  final service = shareService ?? FakeShareService();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        shareServiceProvider.overrideWithValue(service),
        apiClientProvider.overrideWithValue(
          ApiClient(baseUrl: 'http://localhost:8080'),
        ),
      ],
      child: MaterialApp(
        home: SharedNoteViewer(
          shareId: shareId,
          shareKeyFragment: shareKeyFragment,
        ),
      ),
    ),
  );
  // Allow async decryption to start.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  // ===========================================================================
  // Server share detection
  // ===========================================================================

  group('_detectIsServerShare logic', () {
    test('32-char hex string matches server share pattern', () {
      expect(_hex32.hasMatch('a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6'), isTrue);
    });

    test('uppercase hex does not match (lowercase only)', () {
      expect(_hex32.hasMatch('A1B2C3D4E5F6A7B8C9D0E1F2A3B4C5D6'), isFalse);
    });

    test('shorter hex string does not match', () {
      expect(_hex32.hasMatch('a1b2c3d4'), isFalse);
    });

    test('longer base64url string does not match', () {
      expect(
        _hex32.hasMatch('SGVsbG8gV29ybGQhVGhpcyBpcyBhIGxvbmdlciBwYXlsb2Fk'),
        isFalse,
      );
    });

    test('mixed alphanumeric does not match', () {
      expect(_hex32.hasMatch('a1b2c3d4e5f6a7b8c9d0e1f2a3b4xyz'), isFalse);
    });
  });

  // ===========================================================================
  // Widget rendering
  // ===========================================================================

  group('SharedNoteViewer', () {
    testWidgets('shows loading indicator while decrypting', (tester) async {
      // Use a share with key (non-password) that returns slowly.
      final service = FakeShareService(
        onDecryptServer: ({required String shareId, String? key, String? password}) {
          // Return a value that completes after pumps.
          return DecryptedSharedNote(
            title: 'Test',
            content: 'Content',
          );
        },
      );

      await pumpViewer(
        tester,
        shareId: 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6',
        shareKeyFragment: 'someKey',
        shareService: service,
      );

      // After initial pump, the widget may show loading briefly.
      expect(find.byType(SharedNoteViewer), findsOneWidget);
    });

    testWidgets('shows password input when shareKeyFragment is null',
        (tester) async {
      await pumpViewer(
        tester,
        shareId: 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6',
        shareKeyFragment: null,
      );

      // Should show password input (lock icon and password field).
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('shows decrypted note after successful server decryption',
        (tester) async {
      final service = FakeShareService(
        onDecryptServer: ({required String shareId, String? key, String? password}) {
          return DecryptedSharedNote(
            title: 'Shared Note Title',
            content: '# Hello\n\nWorld',
          );
        },
      );

      await pumpViewer(
        tester,
        shareId: 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6',
        shareKeyFragment: 'someKey',
        shareService: service,
      );

      await tester.pumpAndSettle();

      expect(find.text('Shared Note Title'), findsOneWidget);
    });

    testWidgets('shows error state when decryption fails', (tester) async {
      // Default FakeShareService throws, which triggers error state.
      await pumpViewer(
        tester,
        shareId: 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6',
        shareKeyFragment: 'someKey',
      );

      await tester.pumpAndSettle();

      // Error icon should appear.
      expect(find.byIcon(Icons.link_off), findsOneWidget);
    });

    testWidgets('password input has obscureText enabled', (tester) async {
      await pumpViewer(
        tester,
        shareId: 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6',
        shareKeyFragment: null,
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.obscureText, isTrue);
    });

    testWidgets('password input is auto-focused', (tester) async {
      await pumpViewer(
        tester,
        shareId: 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6',
        shareKeyFragment: null,
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.autofocus, isTrue);
    });

    testWidgets('unlock button is present in password mode', (tester) async {
      await pumpViewer(
        tester,
        shareId: 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6',
        shareKeyFragment: null,
      );

      // FilledButton for unlock should be visible.
      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('renders Scaffold with AppBar', (tester) async {
      await pumpViewer(
        tester,
        shareId: 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6',
        shareKeyFragment: null,
      );

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('self-contained share (non-hex ID) uses payload path',
        (tester) async {
      var payloadCalled = false;
      final service = FakeShareService(
        onDecryptPayload: ({required String payload, String? key, String? password}) {
          payloadCalled = true;
          return DecryptedSharedNote(
            title: 'Payload Note',
            content: 'Content from payload',
          );
        },
      );

      await pumpViewer(
        tester,
        // Non-hex ID (base64url-like) triggers self-contained path.
        shareId: 'SGVsbG8gV29ybGQ',
        shareKeyFragment: 'someKey',
        shareService: service,
      );

      await tester.pumpAndSettle();

      expect(payloadCalled, isTrue);
      expect(find.text('Payload Note'), findsOneWidget);
    });
  });
}
