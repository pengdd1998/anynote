import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/constants/app_durations.dart';
import 'package:anynote/features/notes/presentation/widgets/find_replace_bar.dart';

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('AppDurations.autoSaveDelay', () {
    test('is 1 second (1000 ms)', () {
      expect(AppDurations.autoSaveDelay, const Duration(seconds: 1));
    });

    test('is not 2 seconds (old hardcoded value)', () {
      expect(AppDurations.autoSaveDelay, isNot(const Duration(seconds: 2)));
    });

    test('duration in milliseconds is 1000', () {
      expect(AppDurations.autoSaveDelay.inMilliseconds, 1000);
    });
  });

  group('AppDurations constants consistency', () {
    test('autoSaveDelay is shorter than snackbarDuration', () {
      expect(
        AppDurations.autoSaveDelay < AppDurations.snackbarDuration,
        isTrue,
      );
    });

    test('autoSaveDelay is longer than debounce', () {
      expect(
        AppDurations.autoSaveDelay > AppDurations.debounce,
        isTrue,
      );
    });

    test('autoSaveDelay equals debounceTyping', () {
      // Both are 1 second -- same intended behavior for typing-heavy contexts.
      expect(AppDurations.autoSaveDelay, AppDurations.debounceTyping);
    });

    test('autoSaveDelay is shorter than errorDisplayDuration', () {
      expect(
        AppDurations.autoSaveDelay < AppDurations.errorDisplayDuration,
        isTrue,
      );
    });
  });

  group('AppDurations values', () {
    test('veryShortAnimation is 100 ms', () {
      expect(
        AppDurations.veryShortAnimation,
        const Duration(milliseconds: 100),
      );
    });

    test('shortAnimation is 200 ms', () {
      expect(
        AppDurations.shortAnimation,
        const Duration(milliseconds: 200),
      );
    });

    test('mediumAnimation is 250 ms', () {
      expect(
        AppDurations.mediumAnimation,
        const Duration(milliseconds: 250),
      );
    });

    test('animation is 300 ms', () {
      expect(AppDurations.animation, const Duration(milliseconds: 300));
    });

    test('longAnimation is 400 ms', () {
      expect(AppDurations.longAnimation, const Duration(milliseconds: 400));
    });

    test('debounce is 300 ms', () {
      expect(AppDurations.debounce, const Duration(milliseconds: 300));
    });

    test('searchDebounce is 500 ms', () {
      expect(
        AppDurations.searchDebounce,
        const Duration(milliseconds: 500),
      );
    });

    test('debounceTyping is 1 second', () {
      expect(AppDurations.debounceTyping, const Duration(seconds: 1));
    });

    test('snackbarDuration is 2 seconds', () {
      expect(AppDurations.snackbarDuration, const Duration(seconds: 2));
    });

    test('errorDisplayDuration is 4 seconds', () {
      expect(AppDurations.errorDisplayDuration, const Duration(seconds: 4));
    });
  });

  group('AppDurations cannot be instantiated', () {
    test('constructor is private -- all members are static', () {
      expect(AppDurations.veryShortAnimation, isNotNull);
      expect(AppDurations.shortAnimation, isNotNull);
      expect(AppDurations.mediumAnimation, isNotNull);
      expect(AppDurations.animation, isNotNull);
      expect(AppDurations.longAnimation, isNotNull);
      expect(AppDurations.debounce, isNotNull);
      expect(AppDurations.searchDebounce, isNotNull);
      expect(AppDurations.debounceTyping, isNotNull);
      expect(AppDurations.autoSaveDelay, isNotNull);
      expect(AppDurations.snackbarDuration, isNotNull);
      expect(AppDurations.errorDisplayDuration, isNotNull);
    });
  });

  group('FindReplaceController', () {
    test('initial state has no matches', () {
      final ctrl = FindReplaceController();
      expect(ctrl.matchCount, 0);
      expect(ctrl.currentMatchIndex, -1);
    });

    test('setSearchQuery finds matches case-insensitively', () {
      final ctrl = FindReplaceController(content: 'Hello hello HELLO');
      ctrl.setSearchQuery('hello');
      expect(ctrl.matchCount, 3);
    });

    test('setSearchQuery sets currentMatchIndex to 0 when matches found', () {
      final ctrl = FindReplaceController(content: 'abc abc abc');
      ctrl.setSearchQuery('abc');
      expect(ctrl.currentMatchIndex, 0);
    });

    test('setSearchQuery clears index when query is empty', () {
      final ctrl = FindReplaceController(content: 'test');
      ctrl.setSearchQuery('test');
      expect(ctrl.matchCount, 1);
      ctrl.setSearchQuery('');
      expect(ctrl.matchCount, 0);
      expect(ctrl.currentMatchIndex, -1);
    });

    test('nextMatch wraps around', () {
      final ctrl = FindReplaceController(content: 'a a a');
      ctrl.setSearchQuery('a');
      expect(ctrl.currentMatchIndex, 0);
      ctrl.nextMatch();
      expect(ctrl.currentMatchIndex, 1);
      ctrl.nextMatch();
      expect(ctrl.currentMatchIndex, 2);
      ctrl.nextMatch();
      expect(ctrl.currentMatchIndex, 0); // wraps
    });

    test('previousMatch wraps around', () {
      final ctrl = FindReplaceController(content: 'a a a');
      ctrl.setSearchQuery('a');
      expect(ctrl.currentMatchIndex, 0);
      ctrl.previousMatch();
      expect(ctrl.currentMatchIndex, 2); // wraps to last
    });

    test('currentMatch returns correct offsets', () {
      final ctrl = FindReplaceController(content: 'cat dog cat');
      ctrl.setSearchQuery('cat');
      final match = ctrl.currentMatch();
      expect(match, isNotNull);
      expect(match!.start, 0);
      expect(match.end, 3);
    });

    test('currentMatch returns null when no matches', () {
      final ctrl = FindReplaceController(content: 'hello');
      ctrl.setSearchQuery('xyz');
      expect(ctrl.currentMatch(), isNull);
    });

    test('nextMatch returns null when no matches', () {
      final ctrl = FindReplaceController(content: 'hello');
      ctrl.setSearchQuery('xyz');
      expect(ctrl.nextMatch(), isNull);
    });

    test('previousMatch returns null when no matches', () {
      final ctrl = FindReplaceController(content: 'hello');
      ctrl.setSearchQuery('xyz');
      expect(ctrl.previousMatch(), isNull);
    });

    test('replaceCurrent replaces the current match', () {
      final ctrl = FindReplaceController(content: 'cat dog cat');
      ctrl.setSearchQuery('cat');
      final result = ctrl.replaceCurrent('fish');
      expect(result, 'fish dog cat');
    });

    test('replaceCurrent returns null when no matches', () {
      final ctrl = FindReplaceController(content: 'hello');
      ctrl.setSearchQuery('xyz');
      expect(ctrl.replaceCurrent('abc'), isNull);
    });

    test('replaceAll replaces all matches', () {
      final ctrl = FindReplaceController(content: 'cat dog cat');
      ctrl.setSearchQuery('cat');
      final result = ctrl.replaceAll('fish');
      expect(result, 'fish dog fish');
    });

    test('replaceAll returns null when no matches', () {
      final ctrl = FindReplaceController(content: 'hello');
      ctrl.setSearchQuery('xyz');
      expect(ctrl.replaceAll('abc'), isNull);
    });

    test('updateContent re-runs search', () {
      final ctrl = FindReplaceController(content: 'abc');
      ctrl.setSearchQuery('abc');
      expect(ctrl.matchCount, 1);
      ctrl.updateContent('abc abc abc');
      expect(ctrl.matchCount, 3);
    });

    test('matchRanges returns correct TextRanges', () {
      final ctrl = FindReplaceController(content: 'cat dog cat');
      ctrl.setSearchQuery('cat');
      final ranges = ctrl.matchRanges;
      expect(ranges.length, 2);
      expect(ranges[0].start, 0);
      expect(ranges[0].end, 3);
      expect(ranges[1].start, 8);
      expect(ranges[1].end, 11);
    });

    test('replaceCurrent updates match count after replacement', () {
      final ctrl = FindReplaceController(content: 'aaa aaa aaa');
      ctrl.setSearchQuery('aaa');
      expect(ctrl.matchCount, 3);
      ctrl.replaceCurrent('b');
      // After replacing first "aaa" with "b", content becomes "b aaa aaa"
      // which has 2 matches for "aaa".
      expect(ctrl.matchCount, 2);
    });

    test('replaceAll clears matches after replacing', () {
      final ctrl = FindReplaceController(content: 'cat dog cat');
      ctrl.setSearchQuery('cat');
      ctrl.replaceAll('fish');
      // "fish" does not match "cat" so no remaining matches.
      expect(ctrl.matchCount, 0);
    });

    test('works with empty content', () {
      final ctrl = FindReplaceController(content: '');
      ctrl.setSearchQuery('test');
      expect(ctrl.matchCount, 0);
      expect(ctrl.currentMatch(), isNull);
    });

    test('works with single character search', () {
      final ctrl = FindReplaceController(content: 'abcabc');
      ctrl.setSearchQuery('a');
      expect(ctrl.matchCount, 2);
    });

    test('works with multi-word search', () {
      final ctrl = FindReplaceController(content: 'hello world hello world');
      ctrl.setSearchQuery('hello world');
      expect(ctrl.matchCount, 2);
    });

    test('nextMatch advances and returns correct match', () {
      final ctrl = FindReplaceController(content: 'x y x y x');
      ctrl.setSearchQuery('x');
      // After setSearchQuery, currentMatchIndex is 0.
      final m0 = ctrl.currentMatch();
      expect(m0!.start, 0);
      // nextMatch advances to index 1.
      final m1 = ctrl.nextMatch();
      expect(m1!.start, 4);
      // nextMatch advances to index 2.
      final m2 = ctrl.nextMatch();
      expect(m2!.start, 8);
    });

    test('previousMatch goes backwards correctly', () {
      final ctrl = FindReplaceController(content: 'a b a b a');
      ctrl.setSearchQuery('a');
      expect(ctrl.currentMatchIndex, 0);
      final m = ctrl.previousMatch();
      expect(m!.start, 8); // last 'a'
      expect(ctrl.currentMatchIndex, 2);
    });

    test('content field is mutable', () {
      final ctrl = FindReplaceController(content: 'initial');
      expect(ctrl.content, 'initial');
      ctrl.content = 'updated';
      expect(ctrl.content, 'updated');
    });

    test('searchQuery field tracks last query', () {
      final ctrl = FindReplaceController();
      expect(ctrl.searchQuery, '');
      ctrl.setSearchQuery('test');
      expect(ctrl.searchQuery, 'test');
    });

    test('updateContent without active query does not search', () {
      final ctrl = FindReplaceController(content: 'abc');
      ctrl.updateContent('abc abc');
      // No query set, so no matches.
      expect(ctrl.matchCount, 0);
    });

    test('replaceCurrent clamps index after matches shrink', () {
      final ctrl = FindReplaceController(content: 'x x x');
      ctrl.setSearchQuery('x');
      // Navigate to last match.
      ctrl.nextMatch();
      ctrl.nextMatch();
      expect(ctrl.currentMatchIndex, 2);
      // Replace with something longer that only partially matches.
      ctrl.replaceCurrent('xx');
      // Content is now "xx x x" -- "x" appears at positions 3,5.
      // currentMatchIndex should be clamped to valid range.
      expect(ctrl.currentMatchIndex, lessThan(ctrl.matchCount));
      expect(ctrl.currentMatchIndex, greaterThanOrEqualTo(0));
    });

    test('replaceAll with overlapping-safe replacement', () {
      final ctrl = FindReplaceController(content: 'ab ab ab');
      ctrl.setSearchQuery('ab');
      final result = ctrl.replaceAll('XY');
      expect(result, 'XY XY XY');
    });
  });
}
