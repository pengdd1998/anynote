import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/settings/presentation/widgets/account_section.dart';
import 'package:anynote/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Pump the [AccountSection] inside a localized [MaterialApp].
Future<void> pumpAccountSection(
  WidgetTester tester, {
  required AsyncValue<Map<String, dynamic>> accountAsync,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: AccountSection(accountAsync: accountAsync),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('AccountSection', () {
    group('with data state', () {
      testWidgets('renders Account header', (tester) async {
        await pumpAccountSection(
          tester,
          accountAsync: AsyncData({
            'email': 'user@example.com',
            'plan': 'pro',
          }),
        );

        expect(find.text('Account'), findsOneWidget);
      });

      testWidgets('renders email from account data', (tester) async {
        await pumpAccountSection(
          tester,
          accountAsync: AsyncData({
            'email': 'user@example.com',
            'plan': 'pro',
          }),
        );

        expect(find.text('Email'), findsOneWidget);
        expect(find.text('user@example.com'), findsOneWidget);
      });

      testWidgets('renders plan from account data', (tester) async {
        await pumpAccountSection(
          tester,
          accountAsync: AsyncData({
            'email': 'user@example.com',
            'plan': 'pro',
          }),
        );

        expect(find.text('Plan'), findsOneWidget);
        expect(find.text('pro'), findsOneWidget);
      });

      testWidgets('renders Upgrade button', (tester) async {
        await pumpAccountSection(
          tester,
          accountAsync: AsyncData({
            'email': 'user@example.com',
            'plan': 'free',
          }),
        );

        expect(find.text('Upgrade'), findsOneWidget);
      });

      testWidgets('renders profile row', (tester) async {
        await pumpAccountSection(
          tester,
          accountAsync: AsyncData({
            'email': 'user@example.com',
            'plan': 'free',
          }),
        );

        expect(find.text('Profile'), findsOneWidget);
        expect(find.text('Edit display name and bio'), findsOneWidget);
      });

      testWidgets('shows Free plan label when plan is null', (tester) async {
        await pumpAccountSection(
          tester,
          accountAsync: AsyncData({
            'email': 'user@example.com',
          }),
        );

        // Falls back to l10n.freePlan which is "Free".
        expect(find.text('Free'), findsOneWidget);
      });
    });

    group('with loading state', () {
      testWidgets('shows loading placeholders', (tester) async {
        await pumpAccountSection(
          tester,
          accountAsync: const AsyncLoading(),
        );

        expect(find.text('Account'), findsOneWidget);
        expect(find.text('Loading...'), findsNWidgets(2));
      });
    });

    group('with error state', () {
      testWidgets('shows error message', (tester) async {
        await pumpAccountSection(
          tester,
          accountAsync: AsyncError(Exception('network'), StackTrace.empty),
        );

        expect(find.text('Account'), findsOneWidget);
        expect(find.text('Unable to load account info'), findsOneWidget);
      });
    });
  });
}
