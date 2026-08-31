/// Debounces navigation so duplicate taps cannot push the same route twice.
/// During main-thread jank, queued pointer-up events fire one per tap and each
/// would otherwise push a duplicate page, growing the route stack.
class NavGuard {
  NavGuard._();
  static DateTime _lastAt = DateTime.fromMillisecondsSinceEpoch(0);
  static String _lastTarget = '';
  static bool canNavigate(
    String target, {
    Duration window = const Duration(milliseconds: 800),
  }) {
    final now = DateTime.now();
    if (target == _lastTarget && now.difference(_lastAt) < window) {
      return false;
    }
    _lastAt = now;
    _lastTarget = target;
    return true;
  }
}
