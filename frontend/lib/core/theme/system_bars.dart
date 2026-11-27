import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

/// The style of the phone's own bars under the app: the status bar's icons
/// and the navigation bar's colour.
///
/// Both follow the app's theme. Read from the system alone, a dark app on a
/// light phone kept a white strip under every dark screen.
///
/// And while a scrim is up, the status bar takes light icons whatever the
/// theme. A scrim dims the strip behind the status bar and leaves the icons
/// as they were; in the light theme they were dark grey on mid grey, 2.83:1,
/// under every bottom sheet and dialog. The phone's own design says the same:
/// over a dimmed screen, its icons are light.
SystemUiOverlayStyle systemBarsStyle({
  required Brightness brightness,
  required bool scrimUp,
}) {
  final dark = brightness == Brightness.dark;
  final lightIcons = dark || scrimUp;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: lightIcons ? Brightness.light : Brightness.dark,
    // The same fact in the words of the other platform: the brightness of
    // the bar behind the icons.
    statusBarBrightness: lightIcons ? Brightness.dark : Brightness.light,
    systemNavigationBarColor:
        dark ? AppColors.darkSurface : AppColors.lightSurface,
    systemNavigationBarIconBrightness:
        dark ? Brightness.light : Brightness.dark,
  );
}

/// The region the system bars' style lives in, above the whole app. Tests
/// find it by this key: pages carry regions of their own.
const systemBarsRegionKey = Key('system-bars');
