import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted sidebar visibility state for desktop layouts.
///
/// The sidebar is visible by default on desktop. The user can toggle it via
/// the View menu, keyboard shortcut (Ctrl/Cmd+B), or the navigation rail.
final sidebarVisibleProvider =
    StateNotifierProvider<SidebarVisibilityNotifier, bool>((ref) {
  return SidebarVisibilityNotifier();
});

/// Notifier that persists sidebar visibility to SharedPreferences.
class SidebarVisibilityNotifier extends StateNotifier<bool> {
  static const _key = 'sidebar_visible';

  SidebarVisibilityNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool(_key);
    if (saved != null) {
      state = saved;
    }
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, state);
  }

  Future<void> setVisible(bool visible) async {
    state = visible;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, visible);
  }
}
