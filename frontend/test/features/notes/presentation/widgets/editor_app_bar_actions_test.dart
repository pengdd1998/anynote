import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/theme/app_colors.dart';
import 'package:anynote/core/theme/app_icons.dart';
import 'package:anynote/core/theme/app_theme.dart';
import 'package:anynote/features/notes/presentation/widgets/editor_app_bar_actions.dart';
import 'package:anynote/l10n/app_localizations.dart';

/// The editor's top bar: one action, which says its name, beside a status
/// that is drawn in the ink made for status.
void main() {
  Widget bar({
    bool isSaving = false,
    bool isDirty = false,
    Brightness brightness = Brightness.light,
    VoidCallback? onDone,
  }) =>
      ProviderScope(
        child: MaterialApp(
          theme: brightness == Brightness.dark
              ? AppTheme.darkTheme()
              : AppTheme.lightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Consumer(
            builder: (context, ref, _) {
              final config = _config(
                onDone: onDone ?? () {},
                isSaving: isSaving,
                isDirty: isDirty,
              );
              return Scaffold(
                appBar: AppBar(
                  actions:
                      EditorAppBarActions.buildActions(context, ref, config),
                ),
              );
            },
          ),
        ),
      );

  Color? savedInk(WidgetTester tester) =>
      tester.widget<Icon>(find.byIcon(AppIcons.checkCircle)).color;

  Color? unsavedInk(WidgetTester tester) =>
      tester.widget<Icon>(find.byIcon(AppIcons.circleFilled)).color;

  Color? savingInk(WidgetTester tester) {
    final spinner = find.byType(CircularProgressIndicator);
    return tester.widget<CircularProgressIndicator>(spinner).color;
  }

  testWidgets('the one action says its name, and does it', (tester) async {
    var closed = 0;
    await tester.pumpWidget(bar(onDone: () => closed++));
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(tester.element(find.byType(AppBar)))!;

    // Not a second check beside the saved mark's check: a button with a word.
    await tester.tap(find.text(l10n.done));
    await tester.pump();
    expect(closed, 1);
    // It still explains itself on long press.
    expect(find.byTooltip(l10n.saveAndClose), findsOneWidget);
    // The saved mark keeps the only check: with one on the action too, the
    // row read "check, check" before it got to the word.
    expect(find.byIcon(AppIcons.checkCircle), findsOneWidget);
    expect(find.byIcon(AppIcons.check), findsNothing);
  });

  testWidgets('light: the three states take the light status inks', (
    tester,
  ) async {
    await tester.pumpWidget(bar());
    await tester.pumpAndSettle();
    expect(savedInk(tester), AppColors.statusSuccessInk);

    await tester.pumpWidget(bar(isDirty: true));
    expect(unsavedInk(tester), AppColors.statusErrorInk);

    await tester.pumpWidget(bar(isSaving: true));
    expect(savingInk(tester), AppColors.lightTextSecondary);
  });

  testWidgets('dark: the three states take the dark status inks', (
    tester,
  ) async {
    const dark = Brightness.dark;
    await tester.pumpWidget(bar(brightness: dark));
    await tester.pumpAndSettle();
    expect(savedInk(tester), AppColors.statusSuccessInkDark);

    await tester.pumpWidget(bar(isDirty: true, brightness: dark));
    expect(unsavedInk(tester), AppColors.statusErrorInkDark);

    await tester.pumpWidget(bar(isSaving: true, brightness: dark));
    expect(savingInk(tester), AppColors.darkTextSecondary);
  });
}

/// A config for an existing, unlocked, plain-text note; every callback is a
/// no-op except [onDone].
EditorActionsConfig _config({
  required VoidCallback onDone,
  bool isSaving = false,
  bool isDirty = false,
}) {
  void nothing() {}
  return EditorActionsConfig(
    noteId: 'note-1',
    isNew: false,
    isLocked: false,
    isSaving: isSaving,
    isDirty: isDirty,
    useRichEditor: false,
    isPreview: false,
    isFoldView: false,
    isTypewriterScroll: false,
    isFocusMode: false,
    isZenMode: false,
    hasReminder: false,
    onToggleLock: nothing,
    onShowReminderPicker: nothing,
    onToggleRichEditor: nothing,
    onTogglePreview: nothing,
    onToggleFoldView: nothing,
    onReadAloud: nothing,
    onShowTagPicker: nothing,
    onShowBacklinks: nothing,
    onShowRelatedNotes: nothing,
    onShowProperties: nothing,
    onPrint: nothing,
    onPickImage: nothing,
    onPasteImage: nothing,
    onAiAction: (_) {},
    onToggleTypewriterScroll: nothing,
    onToggleFocusMode: nothing,
    onToggleZenMode: nothing,
    onSaveAndClose: onDone,
  );
}
