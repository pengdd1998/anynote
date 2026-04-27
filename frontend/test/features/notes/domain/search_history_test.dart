// Tests for the SearchHistory domain service.
//
// Tests cover:
// - entries returns empty list when no history
// - add prepends query
// - add deduplicates (existing query moves to front)
// - add trims to 20 max entries
// - add skips empty/whitespace queries
// - remove specific query
// - clear removes all
//
// Uses a fake SharedPreferences implementation to avoid platform dependencies.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:anynote/features/notes/domain/search_history.dart';

/// Minimal fake SharedPreferences for testing SearchHistory.
/// Only implements the methods used by SearchHistory: getStringList,
/// setStringList, and remove.
class FakeSharedPreferences implements SharedPreferences {
  final Map<String, dynamic> _data = {};

  @override
  List<String>? getStringList(String key) {
    final value = _data[key];
    if (value is List) {
      return value.cast<String>();
    }
    return null;
  }

  @override
  Future<bool> setStringList(String key, List<String> value) async {
    _data[key] = List<String>.from(value);
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    _data.remove(key);
    return true;
  }

  @override
  Future<bool> clear() async {
    _data.clear();
    return true;
  }

  @override
  Future<bool> commit() async => true;

  @override
  bool containsKey(String key) => _data.containsKey(key);

  @override
  Object? get(String key) => _data[key];

  @override
  bool getBool(String? key) => throw UnimplementedError();

  @override
  double getDouble(String? key) => throw UnimplementedError();

  @override
  int getInt(String? key) => throw UnimplementedError();

  @override
  String? getString(String? key) => throw UnimplementedError();

  @override
  Future<bool> setBool(String? key, bool? value) async => true;

  @override
  Future<bool> setDouble(String? key, double? value) async => true;

  @override
  Future<bool> setInt(String? key, int? value) async => true;

  @override
  Future<bool> setString(String? key, String? value) async => true;

  @override
  Set<String> getKeys() => _data.keys.toSet();

  @override
  Future<void> reload() async {}
}

void main() {
  late FakeSharedPreferences prefs;
  late SearchHistory history;

  setUp(() {
    prefs = FakeSharedPreferences();
    history = SearchHistory(prefs);
  });

  group('SearchHistory', () {
    test('entries returns empty list when no history stored', () {
      expect(history.entries, isEmpty);
    });

    test('add prepends query to the front', () async {
      await history.add('first');
      await history.add('second');

      final entries = history.entries;
      expect(entries.length, equals(2));
      expect(entries[0], equals('second'));
      expect(entries[1], equals('first'));
    });

    test('add deduplicates by moving existing query to front', () async {
      await history.add('alpha');
      await history.add('beta');
      await history.add('alpha'); // Move alpha to front.

      final entries = history.entries;
      expect(entries.length, equals(2));
      expect(entries[0], equals('alpha'));
      expect(entries[1], equals('beta'));
    });

    test('add trims to maxSearchHistoryEntries (20)', () async {
      // Add 25 entries.
      for (var i = 1; i <= 25; i++) {
        await history.add('query $i');
      }

      final entries = history.entries;
      expect(entries.length, equals(maxSearchHistoryEntries));
      // Most recent should be first: 'query 25'.
      expect(entries.first, equals('query 25'));
      // Oldest kept should be 'query 6' (25-20+1=6).
      expect(entries.last, equals('query 6'));
    });

    test('add skips empty query', () async {
      await history.add('');
      expect(history.entries, isEmpty);
    });

    test('add skips whitespace-only query', () async {
      await history.add('   ');
      expect(history.entries, isEmpty);
    });

    test('remove specific query from history', () async {
      await history.add('keep');
      await history.add('remove-me');
      await history.add('also-keep');

      await history.remove('remove-me');

      final entries = history.entries;
      expect(entries, containsAll(['keep', 'also-keep']));
      expect(entries, isNot(contains('remove-me')));
      expect(entries.length, equals(2));
    });

    test('remove non-existent query is a no-op', () async {
      await history.add('existing');
      await history.remove('nonexistent');

      expect(history.entries.length, equals(1));
      expect(history.entries, contains('existing'));
    });

    test('clear removes all entries', () async {
      await history.add('a');
      await history.add('b');
      await history.add('c');

      await history.clear();

      expect(history.entries, isEmpty);
    });
  });
}
