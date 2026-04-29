import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:anynote/core/sync/background_sync_service.dart';
import 'package:anynote/features/settings/presentation/widgets/sync_section.dart';
import 'package:anynote/l10n/app_localizations.dart';

import '../../../../helpers/test_app_helper.dart';

// ---------------------------------------------------------------------------
// Fake BackgroundSyncService for toggle tests
// ---------------------------------------------------------------------------

class _FakeBackgroundSyncService extends BackgroundSyncService {
  final void Function(bool) _onChanged;

  _FakeBackgroundSyncService(this._onChanged) : super(_FakeBgRef());

  Future<bool> isInitialized() async => true;

  @override
  Future<void> setEnabled(bool enabled) async {
    _onChanged(enabled);
  }
}

class _FakeBgRef implements Ref {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Pump the [SyncSection] inside a localized MaterialApp with providers.
Future<void> pumpSyncSection(
  WidgetTester tester, {
  List<Override> overrides = const [],
}) async {
  SharedPreferences.setMockInitialValues({
    'background_sync_enabled': false,
  });

  final allOverrides = <Override>[
    ...defaultProviderOverrides(),
    backgroundSyncEnabledProvider.overrideWith((ref) async => false),
    ...overrides,
  ];

  await tester.pumpWidget(
    ProviderScope(
      overrides: allOverrides,
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('en'),
        home: Scaffold(body: SyncSection()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Pump with a mutable backing state so toggle tests work.
Future<void> pumpSyncSectionWithState(
  WidgetTester tester, {
  required bool Function() getEnabled,
  required void Function(bool) setEnabled,
}) async {
  SharedPreferences.setMockInitialValues({
    'background_sync_enabled': false,
  });

  final allOverrides = <Override>[
    ...defaultProviderOverrides(),
    backgroundSyncEnabledProvider.overrideWith((ref) async => getEnabled()),
    backgroundSyncProvider.overrideWith((ref) {
      return _FakeBackgroundSyncService((v) => setEnabled(v));
    }),
  ];

  await tester.pumpWidget(
    ProviderScope(
      overrides: allOverrides,
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('en'),
        home: Scaffold(body: SyncSection()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('SyncSection', () {
    testWidgets('renders background sync toggle', (tester) async {
      await pumpSyncSection(tester);

      expect(find.text('Background sync'), findsOneWidget);
    });

    testWidgets('renders background sync description', (tester) async {
      await pumpSyncSection(tester);

      expect(find.textContaining('periodically'), findsOneWidget);
    });

    testWidgets('shows switch in off state when disabled', (tester) async {
      await pumpSyncSection(tester);

      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, isFalse);
    });

    testWidgets('shows switch in on state when enabled', (tester) async {
      bool enabled = true;

      await pumpSyncSectionWithState(
        tester,
        getEnabled: () => enabled,
        setEnabled: (v) => enabled = v,
      );

      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, isTrue);
    });

    testWidgets('renders sync icon', (tester) async {
      await pumpSyncSection(tester);

      expect(find.byIcon(Icons.sync), findsOneWidget);
    });

    testWidgets('tapping switch toggles value', (tester) async {
      bool enabled = false;

      await pumpSyncSectionWithState(
        tester,
        getEnabled: () => enabled,
        setEnabled: (v) => enabled = v,
      );

      // Initial state: disabled.
      var switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, isFalse);

      // Tap the switch to enable.
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      // After toggling, the Switch widget should now be on.
      switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, isTrue);
    });

    testWidgets('tapping the row toggles switch', (tester) async {
      bool enabled = false;

      await pumpSyncSectionWithState(
        tester,
        getEnabled: () => enabled,
        setEnabled: (v) => enabled = v,
      );

      // Tap the entire row (not just the switch).
      await tester.tap(find.text('Background sync'));
      await tester.pumpAndSettle();

      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, isTrue);
    });
  });
}
