import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:anynote/core/constants/changelog.dart';
import 'package:anynote/features/notes/presentation/notes_list_screen.dart';
import 'package:anynote/main.dart';
import 'package:anynote/routing/app_router.dart';

import '../helpers/test_app_helper.dart';
import '../helpers/visibility.dart';

/// Boots the real app — router, shell, home screen — the way a signed-in
/// user opens it, and looks at what is on screen.
void main() {
  testWidgets('the home page is on screen after boot', (tester) async {
    // The plugins the app starts with have nothing to talk to in a test.
    final messenger = tester.binding.defaultBinaryMessenger;
    const connectivity =
        MethodChannel('dev.fluttercommunity.plus/connectivity');
    const connectivityStatus = EventChannel(
      'dev.fluttercommunity.plus/connectivity_status',
    );
    const backgroundWork = MethodChannel(
      'be.tramckrijte.workmanager/foreground_channel_work_manager',
    );
    messenger.setMockMethodCallHandler(
      connectivity,
      (call) async => ['wifi'],
    );
    messenger.setMockStreamHandler(
      connectivityStatus,
      MockStreamHandler.inline(
        onListen: (_, events) => events.success(['wifi']),
        onCancel: (_) {},
      ),
    );
    messenger.setMockMethodCallHandler(backgroundWork, (call) async => null);
    addTearDown(() {
      messenger.setMockMethodCallHandler(connectivity, null);
      messenger.setMockStreamHandler(connectivityStatus, null);
      messenger.setMockMethodCallHandler(backgroundWork, null);
    });

    // No "what's new" on top of it.
    SharedPreferences.setMockInitialValues({
      'app_version': Changelog.kCurrentVersion,
    });
    final database = createTestDatabase();
    final signedIn = StateProvider<bool>((_) => true);
    final container = ProviderContainer(
      overrides: [
        ...defaultProviderOverrides(db: database),
        authStateProvider.overrideWith((ref) => ref.watch(signedIn)),
      ],
    );
    // main() sets both before runApp(); the router's redirect reads them.
    globalContainer = container;
    containerReady = true;

    // Taken down inside the test: unmounting queues work (drift closing its
    // stream queries, the sync scheduler) that has to run out before the
    // test ends.
    try {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const RepaintBoundary(child: AnyNoteApp()),
        ),
      );
      await _open(tester);

      expect(appRouter.routerDelegate.currentConfiguration.uri.path, '/notes');
      // Inside the home screen: a route left under the shell carries the
      // same wordmark, and it is not the one that has to be on screen.
      await expectOnScreen(
        tester,
        find.descendant(
          of: find.byType(NotesListScreen),
          matching: find.text('AnyNote'),
        ),
      );
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
      container.dispose();
      // Disposing cancels the database watches, and drift closes each on a
      // timer of its own: let the clock reach them.
      await tester.pump(const Duration(milliseconds: 1));
      await tester.runAsync(
        () => database
            .close()
            .timeout(const Duration(seconds: 2), onTimeout: () {}),
      );
    }
  });
}

/// Gives the app real time to open its database and read its settings.
Future<void> _open(WidgetTester tester) async {
  for (var frame = 0; frame < 25; frame++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}
