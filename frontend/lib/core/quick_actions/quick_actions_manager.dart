import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quick_actions/quick_actions.dart';

import '../../l10n/app_localizations.dart';

/// Manages home screen quick actions (app shortcuts) for Android and iOS.
///
/// Defines 3 quick actions for the home screen long-press menu:
/// 1. "New Note" -- opens quick capture with blank template
/// 2. "New Checklist" -- opens quick capture with checklist template
/// 3. "Daily Note" -- opens today's daily note (or navigates to daily notes)
///
/// On desktop and web this class is a no-op -- [register] and [unregister]
/// return immediately without calling platform APIs.
class QuickActionsManager {
  /// Shortcut type identifiers matching platform-specific configuration.
  static const String _newNoteType = 'new_note';
  static const String _newChecklistType = 'new_checklist';
  static const String _dailyNoteType = 'daily_note';

  /// The singleton instance of the platform QuickActions plugin.
  /// Cached so that [unregister] can clear the same instance.
  static const QuickActions _quickActions = QuickActions();

  /// Whether quick actions have been registered this session.
  static bool _registered = false;

  /// Register quick actions. Call once during app initialization.
  ///
  /// This method is safe to call on any platform; it no-ops on web and
  /// desktop where the quick_actions plugin is not supported.
  static void register(BuildContext context) {
    // Quick actions are only available on iOS and Android.
    if (kIsWeb) return;
    if (_registered) return;

    final l10n = AppLocalizations.of(context);
    if (l10n == null) return;

    _quickActions.initialize((String actionType) {
      // The callback fires outside the normal build cycle, so we need to
      // find a valid context from the root navigator key.
      final navContext = _findContext();
      if (navContext != null && navContext.mounted) {
        handleLaunch(actionType, navContext);
      }
    });

    final items = shortcutItems(l10n);
    _quickActions.setShortcutItems(
      items
          .map(
            (item) => ShortcutItem(
              type: item['type']!,
              localizedTitle: item['localizedTitle']!,
              icon: item['icon'],
            ),
          )
          .toList(),
    );

    _registered = true;
  }

  /// Unregister quick actions by clearing the shortcut items list.
  /// Call when the app is being disposed or during logout.
  static void unregister() {
    if (kIsWeb || !_registered) return;
    _quickActions.clearShortcutItems();
    _registered = false;
  }

  /// Handle a quick action launch by navigating to the appropriate screen.
  ///
  /// Call this from the app's main widget when a quick action is triggered.
  /// Returns true if the action was handled, false otherwise.
  static bool handleLaunch(String actionType, BuildContext context) {
    switch (actionType) {
      case _newNoteType:
        _navigateToQuickCapture(context, template: null);
        return true;
      case _newChecklistType:
        _navigateToQuickCapture(context, template: 'checklist');
        return true;
      case _dailyNoteType:
        _navigateToDailyNote(context);
        return true;
      default:
        return false;
    }
  }

  /// Navigate to the quick capture screen.
  static void _navigateToQuickCapture(
    BuildContext context, {
    String? template,
  }) {
    final uri = Uri(
      path: '/quick-capture',
      queryParameters: template != null ? {'template': template} : null,
    );
    context.push(uri.toString());
  }

  /// Navigate to the daily notes screen.
  static void _navigateToDailyNote(BuildContext context) {
    context.push('/notes/daily');
  }

  /// Find a usable [BuildContext] from the root navigator key.
  static BuildContext? _findContext() {
    final getter = _rootNavigatorKeyGetter;
    if (getter == null) return null;
    try {
      final key = getter();
      return key.currentContext;
    } catch (_) {
      return null;
    }
  }

  /// Late-binding for the root navigator key.  Set by [setNavigatorKeyGetter]
  /// during app startup (before [register] is called).
  static GlobalKey<NavigatorState> Function()? _rootNavigatorKeyGetter;

  /// Wire the navigator key lookup to the app's root key.
  /// Must be called before [register].
  static void setNavigatorKeyGetter(
    GlobalKey<NavigatorState> Function() getter,
  ) {
    _rootNavigatorKeyGetter = getter;
  }

  /// Build the shortcut items configuration for the quick_actions package.
  /// Returns a list of descriptor maps with type, localizedTitle, and icon.
  static List<Map<String, String>> shortcutItems(AppLocalizations l10n) {
    return [
      {
        'type': _newNoteType,
        'localizedTitle': l10n.quickNote,
        'icon': 'ic_shortcut_note',
      },
      {
        'type': _newChecklistType,
        'localizedTitle': l10n.quickChecklist,
        'icon': 'ic_shortcut_checklist',
      },
      {
        'type': _dailyNoteType,
        'localizedTitle': l10n.quickDailyNote,
        'icon': 'ic_shortcut_daily',
      },
    ];
  }
}
