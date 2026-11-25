import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/notes/presentation/notes_list_screen.dart';
import 'package:anynote/routing/app_router.dart';

import '../helpers/boot_app.dart';
import '../helpers/visibility.dart';

/// Boots the real app and looks at what is on screen.
void main() {
  testWidgets('the home page is on screen after boot', (tester) async {
    await bootApp(tester, (tester) async {
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
    });
  });
}
