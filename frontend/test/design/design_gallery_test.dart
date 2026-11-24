import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:anynote/core/database/app_database.dart';
import 'package:anynote/features/ai_chat/presentation/ai_agent_screen.dart';
import 'package:anynote/features/auth/presentation/login_screen.dart';
import 'package:anynote/features/compose/presentation/compose_screen.dart';
import 'package:anynote/features/notes/presentation/note_editor_screen.dart';
import 'package:anynote/features/notes/presentation/notes_list_screen.dart';
import 'package:anynote/features/publish/presentation/publish_screen.dart';
import 'package:anynote/features/settings/presentation/settings_screen.dart';

import '../helpers/design_gallery.dart';
import '../helpers/test_app_helper.dart';

/// Design gallery: renders the app's screens to `build/design-gallery/`.
/// Nothing is asserted about the pixels; the images are for people.
///
/// Off unless asked for — it takes minutes and wants the merged fonts:
///
///   python3 tool/design-fonts/build_fonts.py build/design-fonts
///   flutter test --dart-define=ANYNOTE_DESIGN_GALLERY=true \
///       test/design/design_gallery_test.dart
///   open build/design-gallery
/// Puts [screen] on a phone-sized surface in the app's theme, backed by a
/// database with a realistic set of notes unless `db` is given.
typedef Open = Future<void> Function(
  WidgetTester tester,
  Widget screen, {
  AppDatabase? db,
  bool dark,
});

void main() {
  const skip = !bool.fromEnvironment('ANYNOTE_DESIGN_GALLERY');

  setUpAll(loadAppFonts);

  /// Runs [body] with a way to open screens, then takes everything down
  /// inside the test — unmounting a screen queues work (drift's stream
  /// bookkeeping, autosave debounces) that has to run out before the test
  /// ends.
  void gallery(
    String name,
    Future<void> Function(WidgetTester tester, Open open) body,
  ) {
    testWidgets(
      name,
      (tester) async {
        final containers = <ProviderContainer>[];
        final databases = <AppDatabase>[];

        Future<void> open(
          WidgetTester tester,
          Widget screen, {
          AppDatabase? db,
          bool dark = false,
        }) async {
          // Screens read preferences (theme, layout) as soon as they build.
          SharedPreferences.setMockInitialValues({});
          // Take down whatever is showing. Pumping the same kind of screen
          // again would keep its state, and with it the previous database.
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
          final database = db ?? await seededDatabase();
          final container = ProviderContainer(
            overrides: defaultProviderOverrides(db: database),
          );
          containers.add(container);
          if (db == null) databases.add(database);
          usePhoneSurface(tester, dark: dark);
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: galleryApp(screen, dark: dark),
            ),
          );
        }

        await withRealShadows(() async {
          try {
            await body(tester, open);
          } finally {
            await tester.pumpWidget(const SizedBox());
            await tester.pump(const Duration(seconds: 5));
            for (final container in containers.reversed) {
              container.dispose();
            }
            // Disposing cancels the database watches, and drift closes each one
            // on a timer of its own: let the clock reach them.
            await tester.pump(const Duration(milliseconds: 1));
            // On the real clock, and not for long: a screen that watched the
            // database can keep its close waiting, and the images are already
            // on disk by now.
            await tester.runAsync(
              () => Future.wait([
                for (final database in databases)
                  database
                      .close()
                      .timeout(const Duration(seconds: 2), onTimeout: () {}),
              ]),
            );
            resetPhoneSurface(tester);
          }
        });
      },
      skip: skip,
      timeout: const Timeout(Duration(minutes: 2)),
    );
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await settle(tester);
  }

  gallery('home', (tester, open) async {
    await open(tester, const NotesListScreen());
    await capture(tester, 'home-grid');

    await tapAndSettle(tester, find.byTooltip('更多操作'));
    await capture(tester, 'home-menu');

    await tapAndSettle(tester, find.text('列表视图'));
    await capture(tester, 'home-list');

    await open(tester, const NotesListScreen(), db: createTestDatabase());
    await capture(tester, 'home-empty');

    await open(tester, const NotesListScreen(), dark: true);
    await capture(tester, 'home-grid-dark');
  });

  gallery('editor', (tester, open) async {
    await open(tester, const NoteEditorScreen(noteId: 'n-idea'));
    await capture(tester, 'editor-rich');

    await tapAndSettle(tester, find.byTooltip('纯文本'));
    await capture(tester, 'editor-plain');

    await open(
      tester,
      const NoteEditorScreen(noteId: 'n-markdown'),
      dark: true,
    );
    await capture(tester, 'editor-rich-dark');
  });

  gallery('compose', (tester, open) async {
    await open(tester, const ComposeScreen());
    await capture(tester, 'compose');

    await tapAndSettle(tester, find.text('开始写作').first);
    await capture(tester, 'compose-sheet');
  });

  gallery('settings', (tester, open) async {
    await open(tester, const SettingsScreen());
    await capture(tester, 'settings');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -900));
    await capture(tester, 'settings-2');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -900));
    await capture(tester, 'settings-3');
  });

  gallery('auth', (tester, open) async {
    await open(tester, const LoginScreen(), db: createTestDatabase());
    await capture(tester, 'auth-login');
    await open(
      tester,
      const LoginScreen(),
      db: createTestDatabase(),
      dark: true,
    );
    await capture(tester, 'auth-login-dark');
  });

  gallery('ai and publish', (tester, open) async {
    await open(tester, const AIAgentScreen());
    await capture(tester, 'ai-agent');

    await open(tester, const PublishScreen());
    await capture(tester, 'publish');
  });
}
