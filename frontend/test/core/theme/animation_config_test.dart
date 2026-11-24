import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart' show CustomTransitionPage;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:anynote/core/theme/animation_config.dart';
import 'package:anynote/core/theme/app_animation.dart';
import 'package:anynote/core/theme/app_binding.dart';
import 'package:anynote/core/theme/page_transitions.dart';
import 'package:anynote/core/widgets/pressable_scale.dart';
import 'package:anynote/features/notes/presentation/widgets/staggered_card_entrance.dart';

/// The app ships `WidgetsFlutterBinding` with [ReduceMotionBinding]. The test
/// binding with the same mixin puts that lever under test as it goes out.
class _TestBinding extends AutomatedTestWidgetsFlutterBinding
    with ReduceMotionBinding {}

/// An opacity fade of the ordinary kind: nothing here asks about motion.
class _FadeIn extends StatefulWidget {
  const _FadeIn();

  @override
  State<_FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<_FadeIn> {
  bool _shown = false;

  void show() => setState(() => _shown = true);

  void hide() => setState(() => _shown = false);

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _shown ? 1 : 0,
      duration: const Duration(milliseconds: 300),
      child: const Text('fading'),
    );
  }
}

void main() {
  _TestBinding();

  tearDown(() => ReduceMotionSwitch.override = null);

  Widget withMotion(bool reduceMotion, Widget child) => MediaQuery(
        data: const MediaQueryData(),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: AnimationConfig(reduceMotion: reduceMotion, child: child),
        ),
      );

  Finder wrappedIn(Type type, String text) =>
      find.ancestor(of: find.text(text), matching: find.byType(type));

  group('context.motion', () {
    AnimationConfig? read;

    Future<void> pump(WidgetTester tester, bool reduceMotion) async {
      await tester.pumpWidget(
        withMotion(
          reduceMotion,
          Builder(
            builder: (context) {
              read = context.motion;
              return const SizedBox();
            },
          ),
        ),
      );
    }

    testWidgets('hands out the tokens', (tester) async {
      await pump(tester, false);

      expect(read!.fast, AppAnimation.fast);
      expect(read!.standard, AppAnimation.standard);
      expect(read!.emphasized, AppAnimation.emphasized);
      expect(read!.expressive, AppAnimation.expressive);
      expect(read!.arrive, AppAnimation.arrive);
      expect(read!.depart, AppAnimation.depart);
    });

    testWidgets('gives nothing a duration or an ease when motion is reduced',
        (tester) async {
      await pump(tester, true);

      expect(read!.fast, Duration.zero);
      expect(read!.standard, Duration.zero);
      expect(read!.emphasized, Duration.zero);
      expect(read!.expressive, Duration.zero);
      expect(read!.arrive, Curves.linear);
      expect(read!.depart, Curves.linear);
    });
  });

  group('ReduceMotionBinding', () {
    testWidgets('an animation nothing asked about ends in a frame',
        (tester) async {
      await tester.pumpWidget(
        withMotion(false, const MaterialApp(home: Scaffold(body: _FadeIn()))),
      );
      final state = tester.state<_FadeInState>(find.byType(_FadeIn));

      /// The frame on which the fade has finished, counting from the one
      /// that started it.
      Future<int> framesToShow() async {
        state.show();
        await tester.pump();
        var frames = 0;
        while (tester.binding.hasScheduledFrame && frames < 60) {
          await tester.pump(const Duration(milliseconds: 16));
          frames++;
        }
        return frames;
      }

      final full = await framesToShow();
      state.hide();
      await tester.pumpAndSettle();

      ReduceMotionSwitch.override = true;
      final reduced = await framesToShow();

      // 300ms of fade is some twenty frames; the switch leaves it one or two.
      expect(full, greaterThanOrEqualTo(15));
      expect(reduced, lessThanOrEqualTo(3));
    });
  });

  group('the "减少动画" setting', () {
    test('is read back after a restart', () async {
      SharedPreferences.setMockInitialValues({'reduce_motion': 'on'});

      final notifier = ReduceMotionNotifier();
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state, isTrue);
      expect(ReduceMotionSwitch.override, isTrue);
    });

    test('follows the system when nothing was ever chosen', () async {
      SharedPreferences.setMockInitialValues({});

      final notifier = ReduceMotionNotifier();
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state, isNull);
      expect(ReduceMotionSwitch.override, isNull);
    });

    test('is written down when it changes', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = ReduceMotionNotifier();

      await notifier.set(true);
      var prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('reduce_motion'), 'on');

      await notifier.set(null);
      prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('reduce_motion'), 'system');
      expect(ReduceMotionSwitch.override, isNull);
    });
  });

  group('authored motion', () {
    testWidgets('a pushed page is a bare fade when motion is reduced',
        (tester) async {
      ReduceMotionSwitch.override = true;
      final page =
          slideTransition(const Text('Page')) as CustomTransitionPage<void>;
      expect(page.transitionDuration, AppAnimation.fast);

      await tester.pumpWidget(
        withMotion(
          true,
          Navigator(pages: [page], onDidRemovePage: (_) {}),
        ),
      );

      expect(wrappedIn(FadeTransition, 'Page'), findsWidgets);
      expect(wrappedIn(SlideTransition, 'Page'), findsNothing);
      expect(wrappedIn(ScaleTransition, 'Page'), findsNothing);
    });

    testWidgets('a pushed page is lifted when motion is on', (tester) async {
      final page =
          slideTransition(const Text('Page')) as CustomTransitionPage<void>;
      expect(page.transitionDuration, AppAnimation.emphasized);

      await tester.pumpWidget(
        withMotion(
          false,
          Navigator(pages: [page], onDidRemovePage: (_) {}),
        ),
      );

      expect(wrappedIn(SlideTransition, 'Page'), findsWidgets);
      expect(wrappedIn(ScaleTransition, 'Page'), findsWidgets);
    });

    testWidgets('a sheet opened over a page leaves the page where it is',
        (tester) async {
      final page =
          slideTransition(const Text('Page')) as CustomTransitionPage<void>;
      await tester.pumpWidget(
        MaterialApp(
          home: Navigator(pages: [page], onDidRemovePage: (_) {}),
        ),
      );

      unawaited(
        showModalBottomSheet<void>(
          context: tester.element(find.text('Page')),
          builder: (_) => const SizedBox(height: 200),
        ),
      );
      await tester.pumpAndSettle();

      final scale = tester
          .widget<Transform>(wrappedIn(Transform, 'Page').first)
          .transform
          .entry(0, 0);
      expect(scale, 1);
    });

    testWidgets('a note lands, unless motion is reduced', (tester) async {
      await tester.pumpWidget(
        withMotion(
          true,
          const StaggeredCardEntrance(index: 0, child: Text('note')),
        ),
      );
      expect(wrappedIn(Transform, 'note'), findsNothing);

      await tester.pumpWidget(
        withMotion(
          false,
          const StaggeredCardEntrance(index: 0, child: Text('note')),
        ),
      );
      expect(wrappedIn(Transform, 'note'), findsWidgets);
    });

    testWidgets('only the first screenful of notes lands', (tester) async {
      await tester.pumpWidget(
        withMotion(
          false,
          const StaggeredCardEntrance(index: 8, child: Text('note')),
        ),
      );
      expect(wrappedIn(Transform, 'note'), findsNothing);
    });

    testWidgets('a press dims instead of shrinking when motion is reduced',
        (tester) async {
      await tester.pumpWidget(
        withMotion(
          true,
          PressableScale(onPressed: () {}, child: const Text('press')),
        ),
      );

      final gesture =
          await tester.startGesture(tester.getCenter(find.text('press')));
      await tester.pump();

      expect(
        tester.widget<Opacity>(wrappedIn(Opacity, 'press').first).opacity,
        lessThan(1),
      );
      expect(
        tester
            .widget<Transform>(wrappedIn(Transform, 'press').first)
            .transform
            .entry(0, 0),
        1,
      );

      await gesture.up();
      await tester.pump();
      final opacity = tester.widget<Opacity>(wrappedIn(Opacity, 'press').first);
      expect(opacity.opacity, 1);
    });
  });
}
