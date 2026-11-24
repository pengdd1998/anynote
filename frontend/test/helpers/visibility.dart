import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Checks that [finder] is really on screen.
///
/// "In the widget tree" is not "on screen": a page can be built, laid out,
/// and still be transparent. Every fade around it has to be opaque, nothing
/// above it offstage, it has to lie inside the viewport, and it has to leave
/// a mark in the frame that is not the colour of the frame's corner.
///
/// [finder] should match something drawn on the frame's background colour;
/// the pixel check is what that assumption buys.
Future<void> expectOnScreen(WidgetTester tester, Finder finder) async {
  expect(finder, findsWidgets);
  final target = finder.first;

  final fades = tester.renderObjectList<RenderAnimatedOpacity>(
    find.ancestor(of: target, matching: find.byType(FadeTransition)),
  );
  expect(
    fades.map((fade) => fade.opacity.value),
    everyElement(1.0),
    reason: 'a fade around the content is not fully opaque',
  );

  final offstage = tester.widgetList<Offstage>(
    find.ancestor(of: target, matching: find.byType(Offstage)),
  );
  expect(
    offstage.map((widget) => widget.offstage),
    everyElement(false),
    reason: 'hidden by an offstage ancestor',
  );

  final screen =
      Offset.zero & (tester.view.physicalSize / tester.view.devicePixelRatio);
  final rect = tester.getRect(target);
  final inView = rect.intersect(screen);
  expect(
    screen.contains(rect.center) &&
        inView.width * inView.height >= rect.width * rect.height / 2,
    isTrue,
    reason: 'laid out at $rect, which is mostly outside the screen $screen',
  );

  // The frame itself. Capturing it needs the real clock.
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byType(RepaintBoundary).first,
    );
    final image = await boundary.toImage();
    try {
      final frame = (await image.toByteData())!.buffer.asUint8List();
      final corner = boundary.localToGlobal(Offset.zero) + const Offset(2, 2);
      final background = _pixel(frame, image.width, corner);
      var painted = false;
      for (var x = rect.left.floor(); x < rect.right && !painted; x++) {
        for (var y = rect.top.floor(); y < rect.bottom; y++) {
          if (_pixel(frame, image.width, Offset(x * 1.0, y * 1.0)) !=
              background) {
            painted = true;
            break;
          }
        }
      }
      expect(painted, isTrue, reason: 'nothing of it reached the frame');
    } finally {
      image.dispose();
    }
  });
}

/// The frame's pixel at [at], as one 32-bit value.
int _pixel(List<int> rgba, int width, Offset at) {
  final x = at.dx.floor().clamp(0, width - 1);
  final y = at.dy.floor();
  var value = 0;
  for (var channel = 0; channel < 4; channel++) {
    value = (value << 8) | rgba[(y * width + x) * 4 + channel];
  }
  return value;
}
