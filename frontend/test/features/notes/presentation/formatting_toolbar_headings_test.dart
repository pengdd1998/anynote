import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import 'package:anynote/core/theme/app_icons.dart';
import 'package:anynote/features/notes/presentation/widgets/formatting_toolbar.dart';
import 'package:anynote/l10n/app_localizations.dart';

/// The three heading buttons on the editor's formatting toolbar.
void main() {
  testWidgets('H1, H2 and H3 are three different glyphs', (tester) async {
    final controller = quill.QuillController.basic();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          ...AppLocalizations.localizationsDelegates,
          quill.FlutterQuillLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: FormattingToolbar(quillController: controller),
        ),
      ),
    );

    // They used to be one glyph at three sizes, so two of them were the
    // same button as far as the eye could tell.
    final glyphs = [
      for (final level in ['H1', 'H2', 'H3'])
        tester
            .widget<Icon>(
              find.descendant(
                of: find.byTooltip(level),
                matching: find.byType(Icon),
              ),
            )
            .icon!,
    ];
    expect(glyphs, [
      AppIcons.heading1,
      AppIcons.heading2,
      AppIcons.heading3,
    ]);
    expect(glyphs.toSet().length, 3);
  });
}
