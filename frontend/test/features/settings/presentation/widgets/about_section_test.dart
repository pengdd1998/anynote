import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:anynote/core/providers/app_info_provider.dart';
import 'package:anynote/features/settings/presentation/widgets/about_section.dart';
import 'package:anynote/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Pump the [AboutSection] inside a localized [MaterialApp] with a
/// [ProviderScope] that overrides [appInfoProvider] with fake data.
Future<void> pumpAboutSection(
  WidgetTester tester, {
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appInfoProvider.overrideWith(
          (ref) async => PackageInfo(
            appName: 'AnyNote',
            packageName: 'com.anynote.app',
            version: '1.3.0',
            buildNumber: '42',
          ),
        ),
        ...overrides,
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: const Scaffold(body: AboutSection()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('AboutSection', () {
    testWidgets('renders About header', (tester) async {
      await pumpAboutSection(tester);

      expect(find.text('About'), findsOneWidget);
    });

    testWidgets('renders version info from PackageInfo', (tester) async {
      await pumpAboutSection(tester);

      expect(find.text('Version'), findsOneWidget);
      // PackageInfo version + build number: "1.3.0 (42)"
      expect(find.text('1.3.0 (42)'), findsOneWidget);
    });

    testWidgets('renders privacy policy item', (tester) async {
      await pumpAboutSection(tester);

      expect(find.text('Privacy Policy'), findsOneWidget);
      // Chevron trailing icon indicates tappable navigation.
      expect(find.byIcon(Icons.privacy_tip_outlined), findsOneWidget);
    });

    testWidgets('renders terms of service item', (tester) async {
      await pumpAboutSection(tester);

      expect(find.text('Terms of Service'), findsOneWidget);
      expect(find.byIcon(Icons.description_outlined), findsOneWidget);
    });

    testWidgets('tapping privacy policy opens a dialog', (tester) async {
      await pumpAboutSection(tester);

      // Tap the privacy policy row.
      await tester.tap(find.text('Privacy Policy'));
      await tester.pumpAndSettle();

      // A dialog should open with "Privacy Policy" as title.
      expect(find.byType(AlertDialog), findsOneWidget);
      // The dialog has a Dismiss button.
      expect(find.text('Dismiss'), findsOneWidget);

      // Dismiss the dialog.
      await tester.tap(find.text('Dismiss'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('tapping terms of service opens a dialog', (tester) async {
      await pumpAboutSection(tester);

      await tester.tap(find.text('Terms of Service'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Dismiss'), findsOneWidget);

      await tester.tap(find.text('Dismiss'));
      await tester.pumpAndSettle();
    });

    testWidgets('shows info icon for version row', (tester) async {
      await pumpAboutSection(tester);

      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });
  });
}
