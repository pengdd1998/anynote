import 'package:anynote/core/navigation/nav_guard.dart';
import 'package:flutter_test/flutter_test.dart';

// Note: NavGuard keeps global static state, so each test uses distinct target
// strings to stay independent from the others. fake_async is not usable here
// because the guard reads DateTime.now(), which fake_async does not fake;
// short windows with real time keep these tests fast and deterministic enough.
void main() {
  group('NavGuard.canNavigate', () {
    test('rejects the same target within the window', () {
      const target = '/nav-guard/dup';
      expect(
        NavGuard.canNavigate(target, window: const Duration(seconds: 5)),
        isTrue,
        reason: 'first tap on a target must be allowed',
      );
      expect(
        NavGuard.canNavigate(target, window: const Duration(seconds: 5)),
        isFalse,
        reason: 'duplicate tap on the same target inside the window '
            'must be rejected',
      );
    });

    test('allows a different target immediately', () {
      const first = '/nav-guard/first';
      const second = '/nav-guard/second';
      expect(
        NavGuard.canNavigate(first, window: const Duration(seconds: 5)),
        isTrue,
      );
      expect(
        NavGuard.canNavigate(second, window: const Duration(seconds: 5)),
        isTrue,
        reason: 'a different target must not be blocked by the previous one',
      );
    });

    test('allows the same target again after the window elapsed', () async {
      const target = '/nav-guard/elapsed';
      expect(
        NavGuard.canNavigate(target, window: const Duration(milliseconds: 50)),
        isTrue,
      );
      expect(
        NavGuard.canNavigate(target, window: const Duration(milliseconds: 50)),
        isFalse,
      );
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(
        NavGuard.canNavigate(target, window: const Duration(milliseconds: 50)),
        isTrue,
        reason: 'after the window elapsed, the same target must be allowed',
      );
    });
  });
}
