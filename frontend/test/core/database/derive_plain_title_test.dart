import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/database/app_database.dart';

void main() {
  group('AppDatabase.derivePlainTitle', () {
    test('uses the first non-empty line', () {
      expect(
        AppDatabase.derivePlainTitle('\n  \nsecond line first\nother'),
        'second line first',
      );
    });

    test('strips markdown heading markers', () {
      expect(AppDatabase.derivePlainTitle('## Groceries'), 'Groceries');
      expect(AppDatabase.derivePlainTitle('#Deep heading'), 'Deep heading');
      expect(AppDatabase.derivePlainTitle('###   spaced'), 'spaced');
    });

    test('caps the title at 80 characters', () {
      final long = 'a' * 200;
      final title = AppDatabase.derivePlainTitle(long);
      expect(title, isNotNull);
      expect(title!.length, 80);
    });

    test('returns null for blank content', () {
      expect(AppDatabase.derivePlainTitle(''), isNull);
      expect(AppDatabase.derivePlainTitle('  \n \n'), isNull);
    });

    test('plain whitespace-only first line falls to next line', () {
      expect(AppDatabase.derivePlainTitle('   \nreal title'), 'real title');
    });
  });
}
