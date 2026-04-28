import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/constants/changelog.dart';

void main() {
  group('Changelog', () {
    test('kCurrentVersion is non-empty', () {
      expect(Changelog.kCurrentVersion, isNotEmpty);
    });

    test('kCurrentVersion matches semver pattern', () {
      expect(
        RegExp(r'^\d+\.\d+\.\d+$').hasMatch(Changelog.kCurrentVersion),
        isTrue,
      );
    });

    test('changelog contains current version', () {
      expect(Changelog.entries.containsKey(Changelog.kCurrentVersion), isTrue);
    });

    test('each version has at least one entry', () {
      for (final entry in Changelog.entries.entries) {
        expect(entry.value, isNotEmpty,
            reason: 'Version ${entry.key} has no entries');
      }
    });

    test('changelog contains expected versions', () {
      expect(Changelog.entries.containsKey('1.0.0'), isTrue);
      expect(Changelog.entries.containsKey('1.1.0'), isTrue);
      expect(Changelog.entries.containsKey('1.2.0'), isTrue);
      expect(Changelog.entries.containsKey('1.4.0'), isTrue);
      expect(Changelog.entries.containsKey('2.0.0'), isTrue);
    });
  });
}
