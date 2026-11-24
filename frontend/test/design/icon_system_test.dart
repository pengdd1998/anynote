import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The icon system, kept honest: one family, drawn through `AppIcons`.
/// The rules are in the header of `lib/core/theme/app_icons.dart`.
void main() {
  const iconsFile = 'lib/core/theme/app_icons.dart';
  final entry = RegExp(r'static const (\w+) = PhosphorIcons(Regular|Fill|Bold)\.(\w+);');

  /// name -> [cut, glyph], read from the table's source.
  Map<String, List<String>> entries() {
    final found = <String, List<String>>{};
    for (final line in File(iconsFile).readAsLinesSync()) {
      final match = entry.firstMatch(line);
      if (match != null) found[match.group(1)!] = [match.group(2)!, match.group(3)!];
    }
    return found;
  }

  Iterable<File> dartFiles() {
    bool generated(File file) =>
        file.path.endsWith('.g.dart') || file.path.endsWith('.freezed.dart');
    return Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) => !generated(file))
        .where((file) => !file.path.contains('local_packages'))
        .where((file) => file.path != iconsFile);
  }

  test('no icon is drawn from an icon set outside AppIcons', () {
    // Material's `Icons.x`, Phosphor's `PhosphorIconsRegular.x` / `PhosphorIcon`.
    final outside = RegExp(r'\bIcons\.\w+|\bPhosphorIcon\w*\.');
    final offenders = [
      for (final file in dartFiles())
        for (final (index, line) in file.readAsLinesSync().indexed)
          if (outside.hasMatch(line)) '${file.path}:${index + 1}: ${line.trim()}',
    ];
    expect(
      offenders,
      isEmpty,
      reason: 'Draw icons through AppIcons ($iconsFile), not an icon set directly',
    );
  });

  test('every filled mark has a regular pair with the same glyph', () {
    final table = entries();
    final orphans = [
      for (final name in table.keys)
        if (name.endsWith('Filled') &&
            table[name.replaceFirst(RegExp(r'Filled$'), '')]?[1] !=
                table[name]![1])
          name,
    ];
    expect(orphans, isEmpty, reason: 'A filled icon is the on-state of a toggle');
  });

  test('the filled cut is only used for names ending in Filled', () {
    final table = entries();
    final misnamed = [
      for (final name in table.keys)
        if (table[name]![0] == 'Fill' && !name.endsWith('Filled')) name,
    ];
    expect(misnamed, isEmpty, reason: 'Line icons by default; fill marks a state');
  });

  test('the bold cut is reserved for the high-contrast theme choices', () {
    final table = entries();
    final heavy = [
      for (final name in table.keys)
        if (table[name]![0] == 'Bold' && !name.startsWith('highContrast')) name,
    ];
    expect(heavy, isEmpty, reason: 'Bold is a meaning (contrast), not a style');
  });
}
