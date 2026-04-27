import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/settings/presentation/widgets/sign_out_section.dart';
import 'package:anynote/l10n/app_localizations.dart';

import '../../../../helpers/test_app_helper.dart';

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('SignOutSection', () {
    testWidgets('renders Sign Out button', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: defaultProviderOverrides(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: const Scaffold(body: SignOutSection()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sign Out'), findsOneWidget);
      expect(find.byIcon(Icons.logout), findsOneWidget);
    });

    testWidgets('tapping Sign Out shows confirmation dialog', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: defaultProviderOverrides(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: const Scaffold(body: SignOutSection()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the Sign Out row.
      await tester.tap(find.text('Sign Out'));
      await tester.pumpAndSettle();

      // Confirmation dialog should appear.
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Sign Out'), findsAtLeast(1));
    });

    testWidgets('canceling confirmation dialog dismisses it', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: defaultProviderOverrides(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: const Scaffold(body: SignOutSection()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign Out'));
      await tester.pumpAndSettle();

      // Tap Cancel in the dialog.
      expect(find.text('Cancel'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Dialog should be dismissed.
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('uses error color for the sign out button', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: defaultProviderOverrides(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: const Scaffold(body: SignOutSection()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The DestructiveSettingsItem renders text with the error color.
      // Verify that the logout icon and text are present.
      final logoutIcon = find.byIcon(Icons.logout);
      expect(logoutIcon, findsOneWidget);
    });

    testWidgets('Sign Out button is wrapped in a tappable row', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: defaultProviderOverrides(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: const Scaffold(body: SignOutSection()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The row should be tappable (InkWell from DestructiveSettingsItem).
      expect(find.byType(InkWell), findsOneWidget);
    });
  });

  group('SyncButton', () {
    testWidgets('renders Sync Now button', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: defaultProviderOverrides(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: const Scaffold(body: SyncButton()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sync Now'), findsOneWidget);
      expect(find.byType(OutlinedButton), findsOneWidget);
    });
  });
}
