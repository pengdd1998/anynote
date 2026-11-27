import 'package:flutter/material.dart';

/// How many scrims are up over the app's navigators — the dimming under a
/// bottom sheet or a dialog — so that the status bar can turn its icons
/// while one is (see `systemBarsStyle`).
///
/// Give an [observer] to each navigator: the root one, and the shell's. They
/// all count here. The count is of routes, not of events, and a route that
/// has left its navigator is dropped at the next change: a navigator taken
/// down with a sheet still open reports nothing, and that sheet must not
/// hold the status bar for the rest of the session.
class ScrimDepth {
  final _scrims = <Route<dynamic>>{};
  final _count = ValueNotifier<int>(0);

  /// How many scrims are up.
  Listenable get listenable => _count;

  /// How many are up.
  int get count => _count.value;

  /// Whether any scrim is up.
  bool get up => _count.value > 0;

  /// An observer for one navigator.
  NavigatorObserver observer() => _ScrimObserver(this);

  void _added(Route<dynamic> route) {
    if (_dims(route)) _scrims.add(route);
    _recount();
  }

  void _gone(Route<dynamic>? route) {
    _scrims.remove(route);
    _recount();
  }

  void _recount() {
    // Self-healing: whatever was missed, a route that is no longer on a
    // navigator is not holding a scrim.
    _scrims.removeWhere((route) => !route.isActive);
    _count.value = _scrims.length;
  }
}

/// A modal route that paints a scrim. A popup menu's barrier is transparent:
/// it leaves the status bar as it is and is not counted.
bool _dims(Route<dynamic> route) {
  final color = route is ModalRoute<dynamic> ? route.barrierColor : null;
  return color != null && color.a > 0;
}

class _ScrimObserver extends NavigatorObserver {
  _ScrimObserver(this.depth);

  final ScrimDepth depth;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      depth._added(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      depth._gone(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      depth._gone(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    depth._gone(oldRoute);
    if (newRoute != null) depth._added(newRoute);
  }
}
