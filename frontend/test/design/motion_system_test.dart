import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The motion system, kept honest. The rules are in the headers of
/// `lib/core/theme/app_animation.dart` and `animation_config.dart`.
void main() {
  Iterable<File> dartFiles() {
    bool generated(File file) =>
        file.path.endsWith('.g.dart') || file.path.endsWith('.freezed.dart');
    return Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) => !generated(file))
        .where((file) => !file.path.contains('local_packages'));
  }

  test('no curve is named outside the theme', () {
    // Easing is `context.motion.arrive` / `depart`, or `AppAnimation` where
    // the context is not available (a const constructor).
    final curve = RegExp(r'\bCurves\.');
    final offenders = [
      for (final file in dartFiles())
        if (!file.path.startsWith('lib/core/theme/'))
          for (final (index, line) in file.readAsLinesSync().indexed)
            if (curve.hasMatch(line)) '${file.path}:${index + 1}: ${line.trim()}',
    ];
    expect(offenders, isEmpty, reason: 'Ease with the motion tokens');
  });

  test('AppDurations times waiting, not movement', () {
    final animated = RegExp(r'static const \w*[Aa]nimation\w* ');
    final offenders = [
      for (final line in File('lib/core/constants/app_durations.dart').readAsLinesSync())
        if (animated.hasMatch(line)) line.trim(),
    ];
    expect(offenders, isEmpty, reason: 'Animation durations are AppAnimation\'s');
  });
}
