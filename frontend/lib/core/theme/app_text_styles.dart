import 'package:flutter/material.dart';

import '../platform/platform_utils.dart';

/// Typography tokens for the warm design system.
///
/// Strong hierarchy: display > headline > title > body > caption.
/// Font family resolves to SF Pro Display on iOS, Inter elsewhere.
///
/// Use named base styles for direct usage or [textTheme] for ThemeData:
///
/// ```dart
/// // Direct usage in screens:
/// Text('Title', style: AppTextStyles.title);
///
/// // In ThemeData:
/// ThemeData(textTheme: AppTextStyles.textTheme);
/// ```
class AppTextStyles {
  AppTextStyles._();

  static final String fontFamily =
      PlatformUtils.isIOS ? 'SF Pro Display' : 'Inter';

  // ---------------------------------------------------------------------------
  // Base named styles (use these directly in screen code)
  // ---------------------------------------------------------------------------

  static final TextStyle display = TextStyle(
    fontFamily: fontFamily,
    fontSize: 36,
    fontWeight: FontWeight.w800,
    height: 1.21,
    letterSpacing: -0.8,
  );

  /// Hero display for brand moments (login, onboarding, empty states).
  static final TextStyle displayWarm = TextStyle(
    fontFamily: fontFamily,
    fontSize: 40,
    fontWeight: FontWeight.w800,
    height: 1.15,
    letterSpacing: -1.0,
  );

  static final TextStyle headline = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.27,
    letterSpacing: -0.3,
  );

  static final TextStyle title = TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.29,
    letterSpacing: -0.2,
  );

  static final TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.47,
    letterSpacing: -0.1,
  );

  static final TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.38,
  );

  // -- Additional named styles for specific UI elements -----------------------

  static final TextStyle filterChip = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );

  /// Inline code / monospace snippets.
  static final TextStyle mono = TextStyle(
    fontFamily: 'RobotoMono',
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.5,
    letterSpacing: 0,
  );

  /// Link text (underlined, accent color applied at usage site).
  static final TextStyle link = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.47,
    letterSpacing: -0.1,
    decoration: TextDecoration.underline,
  );

  /// Overline / section label (small caps feel).
  static final TextStyle overline = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    height: 1.36,
    letterSpacing: 0.8,
  );

  // ---------------------------------------------------------------------------
  // Material TextTheme mapping
  // ---------------------------------------------------------------------------

  static TextTheme get textTheme => TextTheme(
        displayLarge: displayWarm,
        displayMedium: display,
        displaySmall: display.copyWith(fontSize: 28),
        headlineLarge: headline.copyWith(fontSize: 26),
        headlineMedium: headline,
        headlineSmall: headline.copyWith(fontSize: 18),
        titleLarge: title,
        titleMedium:
            title.copyWith(fontSize: 15, fontWeight: FontWeight.w500),
        titleSmall:
            title.copyWith(fontSize: 13, fontWeight: FontWeight.w500),
        bodyLarge: body,
        bodyMedium: body.copyWith(fontSize: 14),
        bodySmall: caption,
        labelLarge:
            caption.copyWith(fontWeight: FontWeight.w500, fontSize: 14),
        labelMedium: caption,
        labelSmall: caption.copyWith(fontSize: 11),
      );
}
