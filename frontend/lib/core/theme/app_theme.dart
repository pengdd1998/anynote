import 'package:flutter/material.dart';

import '../platform/platform_utils.dart';
import 'app_colors.dart';
import 'app_radius.dart';
import 'app_text_styles.dart';

/// Design system for AnyNote — warm, soft, modern UI.
///
/// Light mode: warm off-white surfaces with soft indigo-purple accents
/// and warm accent palette (lavender, yellow, mint, peach).
/// Dark mode: deep navy with muted highlights.
///
/// All text tiers meet WCAG AA 4.5:1 contrast on their respective surfaces.
class AppTheme {
  AppTheme._();

  // ---------------------------------------------------------------------------
  // Seed color -- soft indigo-purple (matching design mockup)
  // ---------------------------------------------------------------------------
  static const _seed = AppColors.primary;

  // ---------------------------------------------------------------------------
  // Backward-compatible radius constants
  // Now delegate to AppRadius so all radius definitions are centralized.
  // ---------------------------------------------------------------------------
  static const double radiusSmall = AppRadius.xs; // 12
  static const double radiusMedium = AppRadius.sm; // 16
  static const double radiusLarge = AppRadius.md; // 20
  static const double radiusXLarge = AppRadius.lg; // 24

  // ---------------------------------------------------------------------------
  // Backward-compatible surface references
  // ---------------------------------------------------------------------------
  static const lightCardBg = AppColors.lightCardBg;
  static const darkCardBg = AppColors.darkCardBg;
  static const lightInputFill = AppColors.lightInputFill;
  static const lightBorder = AppColors.lightBorder;
  static const lightDivider = AppColors.lightDivider;
  static const darkInputFill = AppColors.darkInputFill;
  static const darkBorder = AppColors.darkBorder;

  // ---------------------------------------------------------------------------
  // Font family
  // ---------------------------------------------------------------------------
  static final String _fontFamily =
      PlatformUtils.isIOS ? 'SF Pro Display' : 'Inter';

  // ---------------------------------------------------------------------------
  // Light theme (cached)
  // ---------------------------------------------------------------------------
  static final ThemeData light = _buildLightTheme();

  static ThemeData lightTheme() => light;

  static ThemeData _buildLightTheme() {
    var colorScheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.light,
      surface: AppColors.lightSurface,
    );
    // Pin the brand roles to the design tokens so themed widgets (buttons,
    // switches, FABs) use the exact mockup purple instead of a derived tone.
    colorScheme = colorScheme.copyWith(
      onPrimary: const Color(0xFFFFFFFF),
      primary: AppColors.primary,
      secondary: AppColors.primaryDark,
      onSecondary: const Color(0xFFFFFFFF),
      primaryContainer: AppColors.primarySoft,
      onPrimaryContainer: AppColors.primaryText,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.light,
      fontFamily: _fontFamily,
      scaffoldBackgroundColor: AppColors.lightSurface,

      // -- Typography --------------------------------------------------------
      textTheme: AppTextStyles.textTheme,

      // -- App Bar -----------------------------------------------------------
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: AppColors.lightSurface,
        foregroundColor: AppColors.lightTextPrimary,
        titleTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.lightTextPrimary,
        ),
      ),

      // -- Cards (soft shadow, no hard border) --------------------------------
      cardTheme: CardThemeData(
        elevation: 1,
        color: lightCardBg,
        shadowColor: AppColors.shadowLight,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mdBorder,
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      // -- Floating Action Button --------------------------------------------
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 2,
        highlightElevation: 4,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgBorder,
        ),
      ),

      // -- Input Decoration --------------------------------------------------
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightInputFill,
        hintStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 15,
          color: AppColors.lightTextTertiary,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.smBorder,
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.smBorder,
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.smBorder,
          borderSide: BorderSide(
            color: colorScheme.primary.withAlpha(120),
            width: 2.0,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.smBorder,
          borderSide: BorderSide(color: colorScheme.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.smBorder,
          borderSide: BorderSide(color: colorScheme.error, width: 2.0),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      // -- Buttons -----------------------------------------------------------
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          disabledBackgroundColor: AppColors.lightDisabled,
          disabledForegroundColor: AppColors.lightTextTertiary,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.smBorder,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: TextStyle(
            fontFamily: _fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.xsBorder,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: TextStyle(
            fontFamily: _fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.xsBorder,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: TextStyle(
            fontFamily: _fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // -- Chips -------------------------------------------------------------
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.slate100,
        selectedColor: colorScheme.primaryContainer,
        labelStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.lightTextPrimary,
        ),
        secondaryLabelStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: colorScheme.onPrimaryContainer,
        ),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.pillBorder,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),

      // -- Bottom Navigation -------------------------------------------------
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: lightCardBg,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: AppColors.lightTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w400,
        ),
      ),

      // -- Navigation Bar (Material 3) ---------------------------------------
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: lightCardBg,
        indicatorColor: colorScheme.primaryContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 56,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontFamily: _fontFamily,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
            );
          }
          return TextStyle(
            fontFamily: _fontFamily,
            fontSize: 10,
            fontWeight: FontWeight.w400,
            color: AppColors.lightTextSecondary,
          );
        }),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.lightDivider,
        thickness: 1,
        space: 1,
      ),

      // -- Snack Bar ---------------------------------------------------------
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.darkCardBg,
        contentTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 14,
          color: AppColors.darkTextPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.xsBorder,
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // -- Dialog ------------------------------------------------------------
      dialogTheme: DialogThemeData(
        backgroundColor: lightCardBg,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgBorder,
        ),
        titleTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.lightTextPrimary,
        ),
      ),

      // -- Bottom Sheet ------------------------------------------------------
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: lightCardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.topXl,
        ),
      ),

      // -- Switches ----------------------------------------------------------
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return AppColors.lightDisabled;
          }
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return lightCardBg;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return AppColors.lightBorder;
          }
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary.withValues(alpha: 0.4);
          }
          return AppColors.lightBorder;
        }),
      ),

      // -- Tab Bar -----------------------------------------------------------
      tabBarTheme: TabBarThemeData(
        labelColor: colorScheme.primary,
        unselectedLabelColor: AppColors.lightTextSecondary,
        indicatorColor: colorScheme.primary,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),

      // -- Icon Theme --------------------------------------------------------
      iconTheme: const IconThemeData(
        color: AppColors.lightTextSecondary,
        size: 24,
      ),
      primaryIconTheme: IconThemeData(
        color: colorScheme.primary,
        size: 24,
      ),

      // -- List Tile ---------------------------------------------------------
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdBorder),
        minVerticalPadding: 8,
      ),

      // -- Progress Indicator ------------------------------------------------
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: AppColors.lightBorder,
        circularTrackColor: Colors.transparent,
      ),

      // -- Drawer ------------------------------------------------------------
      drawerTheme: DrawerThemeData(
        backgroundColor: lightCardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(
            right: Radius.circular(AppRadius.lg),
          ),
        ),
      ),

      // -- Tooltip -----------------------------------------------------------
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: AppRadius.xsBorder,
        ),
        textStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 12,
          color: AppColors.darkTextPrimary,
        ),
        waitDuration: const Duration(milliseconds: 500),
      ),

      // -- Popup Menu --------------------------------------------------------
      popupMenuTheme: PopupMenuThemeData(
        color: lightCardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdBorder),
        elevation: 4,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Dark theme (cached)
  // ---------------------------------------------------------------------------
  static final ThemeData dark = _buildDarkTheme();

  static ThemeData darkTheme() => dark;

  static ThemeData _buildDarkTheme() {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
      surface: AppColors.darkSurface,
    );
    // Pin the brand roles to light periwinkle so accents glow on deep navy.
    final colorScheme = baseScheme.copyWith(
      primary: AppColors.secondary,
      onPrimary: AppColors.darkSurface,
      secondary: AppColors.secondary,
      onSecondary: AppColors.darkSurface,
      primaryContainer: const Color(0xFF463D6B),
      onPrimaryContainer: const Color(0xFFDCD5FA),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.dark,
      fontFamily: _fontFamily,
      scaffoldBackgroundColor: AppColors.darkSurface,

      // -- Typography --------------------------------------------------------
      textTheme: AppTextStyles.textTheme,

      // -- App Bar -----------------------------------------------------------
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: AppColors.darkSurface,
        foregroundColor: AppColors.darkTextPrimary,
        titleTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.darkTextPrimary,
        ),
      ),

      // -- Cards (soft shadow, no hard border) --------------------------------
      cardTheme: CardThemeData(
        elevation: 1,
        color: AppColors.darkCardBg,
        shadowColor: AppColors.shadowDark,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mdBorder,
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      // -- Floating Action Button --------------------------------------------
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 2,
        highlightElevation: 4,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgBorder,
        ),
      ),

      // -- Input Decoration --------------------------------------------------
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkInputFill,
        hintStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 15,
          color: AppColors.darkTextTertiary,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.smBorder,
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.smBorder,
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.smBorder,
          borderSide: BorderSide(
            color: colorScheme.primary.withAlpha(150),
            width: 2.0,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.smBorder,
          borderSide: BorderSide(color: colorScheme.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.smBorder,
          borderSide: BorderSide(color: colorScheme.error, width: 2.0),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      // -- Buttons -----------------------------------------------------------
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          disabledBackgroundColor: AppColors.darkDisabled,
          disabledForegroundColor: AppColors.darkTextTertiary,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.smBorder,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: TextStyle(
            fontFamily: _fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.xsBorder,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: TextStyle(
            fontFamily: _fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.xsBorder,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: TextStyle(
            fontFamily: _fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // -- Chips -------------------------------------------------------------
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.darkInputFill,
        selectedColor: colorScheme.primaryContainer,
        labelStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.darkTextPrimary,
        ),
        secondaryLabelStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: colorScheme.onPrimaryContainer,
        ),
        side: const BorderSide(color: AppColors.darkBorder),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.xsBorder,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),

      // -- Bottom Navigation -------------------------------------------------
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkCardBg,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: AppColors.darkTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w400,
        ),
      ),

      // -- Navigation Bar (Material 3) ---------------------------------------
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.darkCardBg,
        indicatorColor: colorScheme.primaryContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontFamily: _fontFamily,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
            );
          }
          return TextStyle(
            fontFamily: _fontFamily,
            fontSize: 11,
            fontWeight: FontWeight.w400,
            color: AppColors.darkTextSecondary,
          );
        }),
      ),

      // -- Dividers ----------------------------------------------------------
      dividerTheme: const DividerThemeData(
        color: AppColors.darkDivider,
        thickness: 1,
        space: 1,
      ),

      // -- Snack Bar ---------------------------------------------------------
      snackBarTheme: SnackBarThemeData(
        backgroundColor: lightCardBg,
        contentTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 14,
          color: AppColors.lightTextPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.xsBorder,
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // -- Dialog ------------------------------------------------------------
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.darkCardBg,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgBorder,
        ),
        titleTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.darkTextPrimary,
        ),
      ),

      // -- Bottom Sheet ------------------------------------------------------
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.darkCardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.topXl,
        ),
      ),

      // -- Switches ----------------------------------------------------------
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return AppColors.darkDisabled;
          }
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return AppColors.darkCardBg;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return AppColors.darkBorder;
          }
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary.withValues(alpha: 0.4);
          }
          return AppColors.darkBorder;
        }),
      ),

      // -- Tab Bar -----------------------------------------------------------
      tabBarTheme: TabBarThemeData(
        labelColor: colorScheme.primary,
        unselectedLabelColor: AppColors.darkTextSecondary,
        indicatorColor: colorScheme.primary,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),

      // -- Icon Theme --------------------------------------------------------
      iconTheme: const IconThemeData(
        color: AppColors.darkTextSecondary,
        size: 24,
      ),
      primaryIconTheme: IconThemeData(
        color: colorScheme.primary,
        size: 24,
      ),

      // -- List Tile ---------------------------------------------------------
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdBorder),
        minVerticalPadding: 8,
      ),

      // -- Progress Indicator ------------------------------------------------
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: AppColors.darkBorder,
        circularTrackColor: Colors.transparent,
      ),

      // -- Drawer ------------------------------------------------------------
      drawerTheme: DrawerThemeData(
        backgroundColor: AppColors.darkCardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(
            right: Radius.circular(AppRadius.lg),
          ),
        ),
      ),

      // -- Tooltip -----------------------------------------------------------
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.lightSurface,
          borderRadius: AppRadius.xsBorder,
        ),
        textStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 12,
          color: AppColors.lightTextPrimary,
        ),
        waitDuration: const Duration(milliseconds: 500),
      ),

      // -- Popup Menu --------------------------------------------------------
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.darkCardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdBorder),
        elevation: 4,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // High contrast themes (WCAG AAA 7:1 contrast, cached)
  // ---------------------------------------------------------------------------

  static final ThemeData highContrastLight = _buildHighContrastLightTheme();

  static final ThemeData highContrastDark = _buildHighContrastDarkTheme();

  /// High contrast light theme with pure black on white for maximum readability.
  ///
  /// All color pairs meet or exceed WCAG AAA (7:1) contrast ratio.
  /// Pure black (#000000) on pure white (#FFFFFF) provides 21:1 contrast.
  static ThemeData highContrastLightTheme() => highContrastLight;

  static ThemeData _buildHighContrastLightTheme() {
    const surfaceWhite = Color(0xFFFFFFFF);
    const pureBlack = Color(0xFF000000);
    const primaryCoral = AppColors.hcPrimary;
    const errorRed = Color(0xFFCC0000);

    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: primaryCoral,
      onPrimary: surfaceWhite,
      primaryContainer: primaryCoral.withValues(alpha: 0.15),
      onPrimaryContainer: primaryCoral,
      secondary: primaryCoral,
      onSecondary: surfaceWhite,
      secondaryContainer: primaryCoral.withValues(alpha: 0.15),
      onSecondaryContainer: primaryCoral,
      tertiary: primaryCoral,
      onTertiary: surfaceWhite,
      tertiaryContainer: primaryCoral.withValues(alpha: 0.15),
      onTertiaryContainer: primaryCoral,
      error: errorRed,
      onError: surfaceWhite,
      errorContainer: errorRed.withValues(alpha: 0.15),
      onErrorContainer: errorRed,
      surface: surfaceWhite,
      onSurface: pureBlack,
      surfaceContainerHighest: const Color(0xFFE0E0E0),
      onSurfaceVariant: pureBlack,
      outline: pureBlack,
      outlineVariant: const Color(0xFF333333),
      shadow: pureBlack,
      scrim: pureBlack.withValues(alpha: 0.5),
      inverseSurface: pureBlack,
      onInverseSurface: surfaceWhite,
      inversePrimary: const Color(0xFF8080FF),
    );

    return _buildHighContrastTheme(
      colorScheme: colorScheme,
      scaffoldBg: surfaceWhite,
      cardBg: surfaceWhite,
      border: pureBlack,
      divider: const Color(0xFFE0E0E0),
      textPrimary: pureBlack,
      textSecondary: const Color(0xFF333333),
      inputFill: const Color(0xFFF5F5F5),
    );
  }

  /// High contrast dark theme with pure white on black for maximum readability.
  ///
  /// All color pairs meet or exceed WCAG AAA (7:1) contrast ratio.
  /// Pure white (#FFFFFF) on pure black (#000000) provides 21:1 contrast.
  static ThemeData highContrastDarkTheme() => highContrastDark;

  static ThemeData _buildHighContrastDarkTheme() {
    const surfaceBlack = Color(0xFF000000);
    const pureWhite = Color(0xFFFFFFFF);
    const primaryCoral = AppColors.hcDarkPrimary;
    const errorRed = Color(0xFFFF6666);

    final colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: primaryCoral,
      onPrimary: surfaceBlack,
      primaryContainer: primaryCoral.withValues(alpha: 0.2),
      onPrimaryContainer: pureWhite,
      secondary: primaryCoral,
      onSecondary: surfaceBlack,
      secondaryContainer: primaryCoral.withValues(alpha: 0.2),
      onSecondaryContainer: pureWhite,
      tertiary: primaryCoral,
      onTertiary: surfaceBlack,
      tertiaryContainer: primaryCoral.withValues(alpha: 0.2),
      onTertiaryContainer: pureWhite,
      error: errorRed,
      onError: surfaceBlack,
      errorContainer: errorRed.withValues(alpha: 0.2),
      onErrorContainer: errorRed,
      surface: surfaceBlack,
      onSurface: pureWhite,
      surfaceContainerHighest: const Color(0xFF1A1A1A),
      onSurfaceVariant: pureWhite,
      outline: pureWhite,
      outlineVariant: const Color(0xFFCCCCCC),
      shadow: surfaceBlack,
      scrim: pureWhite.withValues(alpha: 0.5),
      inverseSurface: pureWhite,
      onInverseSurface: surfaceBlack,
      inversePrimary: const Color(0xFF0033CC),
    );

    return _buildHighContrastTheme(
      colorScheme: colorScheme,
      scaffoldBg: surfaceBlack,
      cardBg: surfaceBlack,
      border: pureWhite,
      divider: const Color(0xFF333333),
      textPrimary: pureWhite,
      textSecondary: const Color(0xFFCCCCCC),
      inputFill: const Color(0xFF1A1A1A),
    );
  }

  static ThemeData _buildHighContrastTheme({
    required ColorScheme colorScheme,
    required Color scaffoldBg,
    required Color cardBg,
    required Color border,
    required Color divider,
    required Color textPrimary,
    required Color textSecondary,
    required Color inputFill,
  }) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: colorScheme.brightness,
      fontFamily: _fontFamily,
      scaffoldBackgroundColor: scaffoldBg,

      // -- Typography --------------------------------------------------------
      textTheme: AppTextStyles.textTheme.apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),

      // -- App Bar -----------------------------------------------------------
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: scaffoldBg,
        foregroundColor: textPrimary,
        titleTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),

      // -- Cards (thicker borders for HC visibility) -------------------------
      cardTheme: CardThemeData(
        elevation: 0,
        color: cardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mdBorder,
          side: BorderSide(color: border, width: 2),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      // -- Floating Action Button --------------------------------------------
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 2,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgBorder,
          side: BorderSide(color: border, width: 2),
        ),
      ),

      // -- Input Decoration --------------------------------------------------
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        hintStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 15,
          color: textSecondary,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.smBorder,
          borderSide: BorderSide(color: border, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.smBorder,
          borderSide: BorderSide(color: border, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.smBorder,
          borderSide: BorderSide(color: colorScheme.primary, width: 3),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.smBorder,
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.smBorder,
          borderSide: BorderSide(color: colorScheme.error, width: 3),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      // -- Buttons -----------------------------------------------------------
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          disabledBackgroundColor: textSecondary.withValues(alpha: 0.3),
          disabledForegroundColor: textSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.smBorder,
            side: BorderSide(color: border, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: TextStyle(
            fontFamily: _fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: border, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.xsBorder,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: TextStyle(
            fontFamily: _fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.xsBorder,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: TextStyle(
            fontFamily: _fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // -- Chips -------------------------------------------------------------
      chipTheme: ChipThemeData(
        backgroundColor: inputFill,
        selectedColor: colorScheme.primary.withValues(alpha: 0.2),
        labelStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        secondaryLabelStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: colorScheme.primary,
        ),
        side: BorderSide(color: border, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.xsBorder,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),

      // -- Bottom Navigation -------------------------------------------------
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: cardBg,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: textPrimary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),

      // -- Navigation Bar (Material 3) ---------------------------------------
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cardBg,
        indicatorColor: colorScheme.primary.withValues(alpha: 0.2),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontFamily: _fontFamily,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: colorScheme.primary,
            );
          }
          return TextStyle(
            fontFamily: _fontFamily,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          );
        }),
      ),

      // -- Dividers ----------------------------------------------------------
      dividerTheme: DividerThemeData(
        color: divider,
        thickness: 1,
        space: 1,
      ),

      // -- Snack Bar ---------------------------------------------------------
      snackBarTheme: SnackBarThemeData(
        backgroundColor:
            colorScheme.brightness == Brightness.light ? const Color(0xFF000000) : cardBg,
        contentTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 14,
          color: colorScheme.brightness == Brightness.light
              ? const Color(0xFFFFFFFF)
              : textPrimary,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.xsBorder,
          side: BorderSide(color: border, width: 1),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // -- Dialog ------------------------------------------------------------
      dialogTheme: DialogThemeData(
        backgroundColor: cardBg,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgBorder,
          side: BorderSide(color: border, width: 2),
        ),
        titleTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),

      // -- Bottom Sheet ------------------------------------------------------
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.topXl,
          side: BorderSide(color: border, width: 2),
        ),
      ),

      // -- Switches ----------------------------------------------------------
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return textSecondary;
          }
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return textPrimary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return textSecondary.withValues(alpha: 0.5);
          }
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary.withValues(alpha: 0.6);
          }
          return textSecondary.withValues(alpha: 0.6);
        }),
      ),

      // -- Tab Bar -----------------------------------------------------------
      tabBarTheme: TabBarThemeData(
        labelColor: colorScheme.primary,
        unselectedLabelColor: textPrimary,
        indicatorColor: colorScheme.primary,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),

      // -- Icon Theme --------------------------------------------------------
      iconTheme: IconThemeData(
        color: textPrimary,
        size: 24,
      ),
      primaryIconTheme: IconThemeData(
        color: colorScheme.primary,
        size: 24,
      ),
    );
  }
}
