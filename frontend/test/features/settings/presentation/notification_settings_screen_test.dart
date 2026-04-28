import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/settings/data/notification_preferences.dart';
import 'package:anynote/features/settings/presentation/notification_settings_screen.dart';
import 'package:anynote/l10n/app_localizations.dart';

import '../../../helpers/test_app_helper.dart';

void main() {
  group('NotificationSettingsScreen', () {
    Future<void> pumpScreen(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...defaultProviderOverrides(),
            notificationPreferencesProvider
                .overrideWith(() => NotificationPreferencesNotifier()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: const NotificationSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('renders without errors', (tester) async {
      await pumpScreen(tester);
      expect(find.byType(NotificationSettingsScreen), findsOneWidget);
    });

    testWidgets('renders four switch tiles', (tester) async {
      await pumpScreen(tester);
      expect(find.byType(Switch), findsNWidgets(4));
    });

    testWidgets('switches default to enabled', (tester) async {
      await pumpScreen(tester);
      final switches = tester.widgetList<Switch>(find.byType(Switch));
      for (final sw in switches) {
        expect(sw.value, isTrue);
      }
    });

    testWidgets('tapping first switch disables it', (tester) async {
      await pumpScreen(tester);

      final firstSwitch = tester.widget<Switch>(find.byType(Switch).first);
      expect(firstSwitch.value, isTrue);

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      final updatedSwitch = tester.widget<Switch>(find.byType(Switch).first);
      expect(updatedSwitch.value, isFalse);
    });
  });
}
