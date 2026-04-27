// Tests for the search query parser.
//
// Tests cover:
// - Empty string -> all fields null/empty
// - Plain text only -> fullTextQuery set, no operators
// - tag: operator
// - Multiple tag: operators
// - status: operator normalization
// - priority: operator normalization (including abbreviations)
// - date: operator with various formats and directions
// - collection: operator
// - links: boolean operator
// - color: named and hex color
// - Mixed operators and plain text
// - Unknown operators treated as plain text
// - hasOperatorFilters predicate

import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/notes/domain/search_query_parser.dart';

void main() {
  group('parseSearchQuery', () {
    test('empty string returns default query with no filters', () {
      final query = parseSearchQuery('');
      expect(query.fullTextQuery, isEmpty);
      expect(query.tagFilters, isEmpty);
      expect(query.statusFilter, isNull);
      expect(query.priorityFilter, isNull);
      expect(query.dateFilter, isNull);
      expect(query.collectionFilters, isEmpty);
      expect(query.hasLinks, isNull);
      expect(query.colorFilter, isNull);
      expect(query.hasOperatorFilters, isFalse);
    });

    test('whitespace-only string returns default query', () {
      final query = parseSearchQuery('   \t  ');
      expect(query.fullTextQuery, isEmpty);
      expect(query.hasOperatorFilters, isFalse);
    });

    test('plain text only sets fullTextQuery with no operators', () {
      final query = parseSearchQuery('meeting notes');
      expect(query.fullTextQuery, equals('meeting notes'));
      expect(query.tagFilters, isEmpty);
      expect(query.hasOperatorFilters, isFalse);
    });

    test('tag:work adds to tagFilters', () {
      final query = parseSearchQuery('tag:work');
      expect(query.tagFilters, contains('work'));
      expect(query.fullTextQuery, isEmpty);
      expect(query.hasOperatorFilters, isTrue);
    });

    test('multiple tag: operators accumulate', () {
      final query = parseSearchQuery('tag:work tag:important tag:review');
      expect(query.tagFilters, containsAll(['work', 'important', 'review']));
      expect(query.tagFilters.length, equals(3));
    });

    test('status:todo normalizes to Todo', () {
      final query = parseSearchQuery('status:todo');
      expect(query.statusFilter, equals('Todo'));
    });

    test('status:in_progress normalizes to In Progress', () {
      final query = parseSearchQuery('status:in_progress');
      expect(query.statusFilter, equals('In Progress'));
    });

    test('status:in-progress normalizes to In Progress', () {
      final query = parseSearchQuery('status:in-progress');
      expect(query.statusFilter, equals('In Progress'));
    });

    test('status:done normalizes to Done', () {
      final query = parseSearchQuery('status:done');
      expect(query.statusFilter, equals('Done'));
    });

    test('priority:high normalizes to High', () {
      final query = parseSearchQuery('priority:high');
      expect(query.priorityFilter, equals('High'));
    });

    test('priority:h abbreviation normalizes to High', () {
      final query = parseSearchQuery('priority:h');
      expect(query.priorityFilter, equals('High'));
    });

    test('priority:medium normalizes to Medium', () {
      final query = parseSearchQuery('priority:medium');
      expect(query.priorityFilter, equals('Medium'));
    });

    test('priority:m abbreviation normalizes to Medium', () {
      final query = parseSearchQuery('priority:m');
      expect(query.priorityFilter, equals('Medium'));
    });

    test('priority:low normalizes to Low', () {
      final query = parseSearchQuery('priority:low');
      expect(query.priorityFilter, equals('Low'));
    });

    test('priority:l abbreviation normalizes to Low', () {
      final query = parseSearchQuery('priority:l');
      expect(query.priorityFilter, equals('Low'));
    });

    test('date:2024-01 produces DateFilter with month granularity', () {
      final query = parseSearchQuery('date:2024-01');
      expect(query.dateFilter, isNotNull);
      expect(query.dateFilter!.granularity, equals('month'));
      expect(query.dateFilter!.value.year, equals(2024));
      expect(query.dateFilter!.value.month, equals(1));
      expect(query.dateFilter!.isAfter, isFalse);
      expect(query.dateFilter!.isBefore, isFalse);
    });

    test('date:>2024-01-15 produces isAfter DateFilter', () {
      final query = parseSearchQuery('date:>2024-01-15');
      expect(query.dateFilter, isNotNull);
      expect(query.dateFilter!.isAfter, isTrue);
      expect(query.dateFilter!.granularity, equals('day'));
    });

    test('date:<2024-06 produces isBefore DateFilter with month granularity',
        () {
      final query = parseSearchQuery('date:<2024-06');
      expect(query.dateFilter, isNotNull);
      expect(query.dateFilter!.isBefore, isTrue);
      expect(query.dateFilter!.granularity, equals('month'));
    });

    test('date:2024 produces year granularity', () {
      final query = parseSearchQuery('date:2024');
      expect(query.dateFilter, isNotNull);
      expect(query.dateFilter!.granularity, equals('year'));
      expect(query.dateFilter!.value.year, equals(2024));
    });

    test('collection:MyFolder adds to collectionFilters', () {
      final query = parseSearchQuery('collection:MyFolder');
      expect(query.collectionFilters, contains('MyFolder'));
    });

    test('links:true sets hasLinks to true', () {
      final query = parseSearchQuery('links:true');
      expect(query.hasLinks, isTrue);
    });

    test('links:false sets hasLinks to false', () {
      final query = parseSearchQuery('links:false');
      expect(query.hasLinks, isFalse);
    });

    test('color:red normalizes named color to hex', () {
      final query = parseSearchQuery('color:red');
      expect(query.colorFilter, isNotNull);
      // Named color 'red' maps to '#F44336' uppercased.
      expect(query.colorFilter, equals('#F44336'));
    });

    test('color:#FF0000 preserves hex color uppercased', () {
      final query = parseSearchQuery('color:#FF0000');
      expect(query.colorFilter, equals('#FF0000'));
    });

    test('color:#ff0000 normalizes hex to uppercase', () {
      final query = parseSearchQuery('color:#ff0000');
      expect(query.colorFilter, equals('#FF0000'));
    });

    test('mixed operators and plain text parse correctly', () {
      final query = parseSearchQuery('meeting notes tag:work priority:high');
      expect(query.fullTextQuery, equals('meeting notes'));
      expect(query.tagFilters, equals(['work']));
      expect(query.priorityFilter, equals('High'));
      expect(query.hasOperatorFilters, isTrue);
    });

    test('unknown operator treated as plain text', () {
      final query = parseSearchQuery('foo:bar');
      // 'foo' is not a recognized operator key, so the whole token is plain text.
      expect(query.fullTextQuery, equals('foo:bar'));
      expect(query.hasOperatorFilters, isFalse);
    });

    test('hasOperatorFilters returns false for plain text only', () {
      final query = parseSearchQuery('just some text here');
      expect(query.hasOperatorFilters, isFalse);
    });

    test('hasOperatorFilters returns true when tag operator present', () {
      final query = parseSearchQuery('tag:review');
      expect(query.hasOperatorFilters, isTrue);
    });

    test('hasOperatorFilters returns true when color operator present', () {
      final query = parseSearchQuery('color:blue');
      expect(query.hasOperatorFilters, isTrue);
    });
  });

  group('DateFilter', () {
    test('endDate for month granularity covers the entire month', () {
      final filter = DateFilter(
        value: DateTime(2024, 2),
        granularity: 'month',
      );
      // February 2024 -> end of Feb 29, 2024 (leap year).
      expect(filter.endDate.year, equals(2024));
      expect(filter.endDate.month, equals(2));
      expect(filter.endDate.day, equals(29));
      expect(filter.endDate.hour, equals(23));
      expect(filter.endDate.minute, equals(59));
      expect(filter.endDate.second, equals(59));
    });

    test('startDate for isAfter shifts one day forward', () {
      final filter = DateFilter(
        value: DateTime(2024, 1, 15),
        isAfter: true,
        granularity: 'day',
      );
      expect(filter.startDate.year, equals(2024));
      expect(filter.startDate.month, equals(1));
      expect(filter.startDate.day, equals(16));
    });

    test('endDate for isBefore shifts one day back', () {
      final filter = DateFilter(
        value: DateTime(2024, 3, 10),
        isBefore: true,
        granularity: 'day',
      );
      expect(filter.endDate.year, equals(2024));
      expect(filter.endDate.month, equals(3));
      expect(filter.endDate.day, equals(9));
    });

    test('endDate for year granularity covers Dec 31', () {
      final filter = DateFilter(
        value: DateTime(2024),
        granularity: 'year',
      );
      expect(filter.endDate.year, equals(2024));
      expect(filter.endDate.month, equals(12));
      expect(filter.endDate.day, equals(31));
    });
  });
}
