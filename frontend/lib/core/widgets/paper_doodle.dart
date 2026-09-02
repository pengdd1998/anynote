import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Hand-drawn corner doodles for sticky-note cards, matching the design
/// mockup's ink sketches (star, book, bulb, sprout, heart). Each doodle is
/// a thin stroked path with slightly wobbly curves so it reads as pen-drawn.

enum PaperDoodleKind { star, book, bulb, sprout, heart }

extension PaperDoodleKindX on PaperDoodleKind {
  /// Deterministic sketch cycle — the same item seed always gets the same
  /// doodle.
  static const _cycle = [
    PaperDoodleKind.star,
    PaperDoodleKind.book,
    PaperDoodleKind.bulb,
    PaperDoodleKind.sprout,
    PaperDoodleKind.heart,
  ];

  static PaperDoodleKind forSeed(int seed) =>
      _cycle[seed.abs() % _cycle.length];

  static int get cycleLength => _cycle.length;
}

class PaperDoodle extends StatelessWidget {
  final PaperDoodleKind kind;

  /// Ink color of the sketch stroke.
  final Color color;

  /// Box the doodle is drawn in.
  final double size;

  const PaperDoodle({
    super.key,
    required this.kind,
    required this.color,
    this.size = 22,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _DoodlePainter(kind, color),
    );
  }
}

class _DoodlePainter extends CustomPainter {
  final PaperDoodleKind kind;
  final Color color;

  _DoodlePainter(this.kind, this.color);

  static final _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.7
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    _stroke.color = color;
    final s = size.width / 24; // sketches are authored on a 24x24 grid
    canvas.scale(s, s);

    switch (kind) {
      case PaperDoodleKind.star:
        _star(canvas);
      case PaperDoodleKind.book:
        _book(canvas);
      case PaperDoodleKind.bulb:
        _bulb(canvas);
      case PaperDoodleKind.sprout:
        _sprout(canvas);
      case PaperDoodleKind.heart:
        _heart(canvas);
    }
  }

  /// Five-point star outline with a hand-drawn wobble (points drift a
  /// little off the ideal radius, and the outer stroke overshoots corners).
  void _star(Canvas canvas) {
    const cx = 12.0, cy = 13.0;
    const outer = [9.5, 8.8, 9.8, 9.2, 9.0];
    const inner = [4.4, 4.1, 4.5, 4.2];
    final path = Path();
    for (var i = 0; i < 5; i++) {
      final aOut = -1.5708 + i * 1.2566 + (i.isEven ? -0.04 : 0.05);
      final aIn = aOut + 0.6283;
      final ox = cx + outer[i] * _wob(i * 7) * 0.06 + outer[i] * 0.02;
      final px = cx + math.cos(aOut) * ox, py = cy + math.sin(aOut) * ox;
      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
      final rIn = inner[i % inner.length] * _wob(i * 11);
      path.lineTo(cx + math.cos(aIn) * rIn, cy + math.sin(aIn) * rIn);
    }
    path.close();
    canvas.drawPath(path, _stroke);
  }

  /// Open book: two gently curved pages meeting at the spine.
  void _book(Canvas canvas) {
    final path = Path()
      ..moveTo(3.5, 6.5)
      ..cubicTo(7, 4.8, 10.5, 5.2, 12, 7)
      ..cubicTo(13.5, 5.2, 17, 4.8, 20.5, 6.5)
      ..lineTo(20.5, 17.5)
      ..cubicTo(17, 15.8, 13.5, 16.2, 12, 18)
      ..cubicTo(10.5, 16.2, 7, 15.8, 3.5, 17.5)
      ..close();
    canvas.drawPath(path, _stroke);
    canvas.drawLine(const Offset(12, 7), const Offset(12, 18), _stroke);
    // A couple of text lines on the right page.
    canvas.drawLine(const Offset(14.5, 9.5), const Offset(18, 9), _stroke);
    canvas.drawLine(const Offset(14.5, 12), const Offset(18, 11.5), _stroke);
  }

  /// Light bulb sketch: rounded bulb, small base, filament squiggle, rays.
  void _bulb(Canvas canvas) {
    final path = Path()
      ..moveTo(12, 4)
      ..cubicTo(7.5, 4, 6, 7.5, 7, 10.2)
      ..cubicTo(7.7, 12, 9.2, 12.8, 9.6, 14.6)
      ..lineTo(14.4, 14.6)
      ..cubicTo(14.8, 12.8, 16.3, 12, 17, 10.2)
      ..cubicTo(18, 7.5, 16.5, 4, 12, 4)
      ..close();
    canvas.drawPath(path, _stroke);
    canvas
      ..drawLine(const Offset(9.8, 16.4), const Offset(14.2, 16.4), _stroke)
      ..drawLine(const Offset(10.4, 18.6), const Offset(13.6, 18.6), _stroke)
      // filament squiggle
      ..drawPath(
        Path()
          ..moveTo(10.6, 12.6)
          ..quadraticBezierTo(11.4, 11.2, 12, 12.6)
          ..quadraticBezierTo(12.6, 14, 13.4, 12.6),
        _stroke,
      )
      // rays
      ..drawLine(const Offset(4.5, 7.5), const Offset(6.2, 8.2), _stroke)
      ..drawLine(const Offset(19.5, 7.5), const Offset(17.8, 8.2), _stroke)
      ..drawLine(const Offset(12, 1.8), const Offset(12, 3.2), _stroke);
  }

  /// Sprout: curved stem with two leaves (Plant care vibes).
  void _sprout(Canvas canvas) {
    canvas
      ..drawPath(
        Path()
          ..moveTo(12, 21)
          ..cubicTo(12, 16, 12, 12, 12, 9),
        _stroke,
      )
      ..drawPath(
        Path()
          ..moveTo(12, 11)
          ..cubicTo(11.5, 7, 8.5, 5, 4.5, 5.5)
          ..cubicTo(5, 9.5, 8, 11.6, 12, 11),
        _stroke,
      )
      ..drawPath(
        Path()
          ..moveTo(12, 9)
          ..cubicTo(12.5, 5.5, 15, 3.8, 19, 4.2)
          ..cubicTo(18.5, 7.8, 16, 9.6, 12, 9),
        _stroke,
      );
  }

  /// Heart outline drawn as two lobes with a soft bottom point.
  void _heart(Canvas canvas) {
    final path = Path()
      ..moveTo(12, 20)
      ..cubicTo(5, 15, 3, 10.5, 4.6, 7.4)
      ..cubicTo(6, 4.8, 10, 4.6, 12, 8)
      ..cubicTo(14, 4.6, 18, 4.8, 19.4, 7.4)
      ..cubicTo(21, 10.5, 19, 15, 12, 20)
      ..close();
    canvas.drawPath(path, _stroke);
  }

  /// Deterministic pseudo-wobble in [-1, 1] so strokes look hand-drawn but
  /// render identically every frame.
  static double _wob(int seed) => ((seed * 37 % 17) / 8.0) - 1.0;

  @override
  bool shouldRepaint(_DoodlePainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.color != color;
}
