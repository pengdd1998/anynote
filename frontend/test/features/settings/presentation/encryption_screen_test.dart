import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/settings/data/settings_providers.dart';
import 'package:anynote/features/settings/presentation/encryption_screen.dart';
import '../../../helpers/test_app_helper.dart';

void main() {
  group('EncryptionScreen', () {
    List<Override> encryptionOverrides() => [
          ...defaultProviderOverrides(),
          encryptionStatusProvider.overrideWith((ref) {
            return EncryptionStatusNotifier(FakeCryptoService());
          }),
          localItemCountsProvider
              .overrideWith(() => _FakeLocalItemCountsNotifier()),
          recoveryKeyProvider.overrideWith((ref) async => null),
        ];

    testWidgets('renders without errors', (tester) async {
      final handle = await pumpScreen(
        tester,
        const EncryptionScreen(),
        overrides: encryptionOverrides(),
      );
      addTearDown(() => handle.dispose());

      // Let stagger animations and microtasks settle.
      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsOneWidget);
    });
  });
}

/// Fake local item counts notifier.
class _FakeLocalItemCountsNotifier extends LocalItemCountsNotifier {
  @override
  Future<Map<String, int>> build() async {
    return {'notes': 0, 'tags': 0, 'collections': 0, 'ai_content': 0};
  }
}
