import 'package:flutter/material.dart';

/// Warm, elegant design system for AnyNote.
///
/// Brand personality: warm, private, elegant.
/// Light mode evokes high-quality cream paper; dark mode evokes lamplight.
/// Neutrals are always tinted warm -- no clinical whites or cold greys.
/// Accent color is used sparingly for interactive elements and status.
///
/// References: Bear Notes (warmth, simplicity), Day One (elegance, personal feel).
class AppTheme {
  AppTheme._();

  // ---------------------------------------------------------------------------
  // Seed color -- warm terracotta / caramel
  // ---------------------------------------------------------------------------
  static const _warmSeed = Color(0xFFC4956A);

  // ---------------------------------------------------------------------------
  // Light palette
  // ---------------------------------------------------------------------------
  static const _lightSurface = Color(0xFFFAF8F5); // Warm cream paper
  static const lightCardBg = Color(0xFFFFFDFB); // Warm white
  static const _lightTextPrimary = Color(0xFF2C2520); // Warm near-black
  static const _lightTextSecondary = Color(0xFF6B5E54); // Warm brown-grey
  static const _lightTextTertiary =
      Color(0xFF7A6E62); // Warm muted grey (WCAG AA 4.5:1 on _lightSurface)
  static const lightInputFill = Color(0xFFF5F0EB); // Warm beige
  static const lightBorder = Color(0xFFE8DFD5); // Warm border
  static const lightDivider = Color(0xFFF0E8DF); // Warm divider
  static const _lightDisabled = Color(0xFFC9BFB4); // Warm disabled

  // ---------------------------------------------------------------------------
  // Dark palette
  // ---------------------------------------------------------------------------
  static const _darkSurface = Color(0xFF1A1614); // Deep warm charcoal
  static const darkCardBg = Color(0xFF252220); // Warm dark grey
  static const _darkTextPrimary = Color(0xFFF5F0EB); // Warm white
  static const _darkTextSecondary =
      Color(0xFFA3988E); // Warm medium grey (WCAG AA 4.5:1 on _darkSurface)
  static const _darkTextTertiary =
      Color(0xFF9E9288); // Warm dark muted (WCAG AA 4.5:1 on _darkSurface)
  static const darkInputFill = Color(0xFF2C2826); // Warm dark fill
  static const darkBorder = Color(0xFF3D3835); // Warm dark border
  static const _darkDivider = Color(0xFF332E2B); // Warm dark divider
  static const _darkDisabled = Color(0xFF4A4340); // Warm dark disabled

  // ---------------------------------------------------------------------------
  // High contrast palette (WCAG AAA 7:1)
  // ---------------------------------------------------------------------------
  static const pureBlack = Color(0xFF000000); // Pure black
  static const pureWhite = Color(0xFFFFFFFF); // Pure white
  static const surfaceBlack = Color(0xFF000000); // Pure black for surfaces

  // ---------------------------------------------------------------------------
  // Typography scale
  // ---------------------------------------------------------------------------
  static const _fontFamily = 'SF Pro Display';

  static const TextStyle _display = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w700, // bold
    height: 1.21,
    letterSpacing: -0.5,
  );

  static const TextStyle _headline = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w600, // semibold
    height: 1.27,
    letterSpacing: -0.3,
  );

  static const TextStyle _title = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w600, // semibold
    height: 1.29,
    letterSpacing: -0.2,
  );

  static const TextStyle _body = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w400, // regular
    height: 1.47,
    letterSpacing: -0.1,
  );

  static const TextStyle _caption = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400, // regular
    height: 1.38,
    letterSpacing: 0.0,
  );

  // ---------------------------------------------------------------------------
  // Light theme
  // ---------------------------------------------------------------------------
  static ThemeData lightTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _warmSeed,
      brightness: Brightness.light,
      surface: _lightSurface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.light,
      fontFamily: _fontFamily,
      scaffoldBackgroundColor: _lightSurface,

      // -- Typography --------------------------------------------------------
      textTheme: TextTheme(
        displayLarge: _display,
        displayMedium: _display.copyWith(fontSize: 26),
        displaySmall: _display.copyWith(fontSize: 24),
        headlineLarge: _headline,
        headlineMedium: _headline.copyWith(fontSize: 20),
        headlineSmall: _headline.copyWith(fontSize: 18),
        titleLarge: _title,
        titleMedium: _title.copyWith(fontSize: 15, fontWeight: FontWeight.w500),
        titleSmall: _title.copyWith(fontSize: 13, fontWeight: FontWeight.w500),
        bodyLarge: _body,
        bodyMedium: _body.copyWith(fontSize: 14),
        bodySmall: _caption,
        labelLarge:
            _caption.copyWith(fontWeight: FontWeight.w500, fontSize: 14),
        labelMedium: _caption,
        labelSmall: _caption.copyWith(fontSize: 11),
      ),

      // -- App Bar -----------------------------------------------------------
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: _lightSurface,
        foregroundColor: _lightTextPrimary,
        titleTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: _lightTextPrimary,
        ),
      ),

      // -- Cards -------------------------------------------------------------
      cardTheme: CardThemeData(
        elevation: 0,
        color: lightCardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          side: const BorderSide(color: lightBorder),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),

      // -- Floating Action Button --------------------------------------------
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 1,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
        ),
      ),

      // -- Input Decoration --------------------------------------------------
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightInputFill,
        hintStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 15,
          color: _lightTextTertiary,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: colorScheme.primary, width: 2.0),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: colorScheme.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
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
          disabledBackgroundColor: _lightDisabled,
          disabledForegroundColor: _lightTextTertiary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSmall),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(
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
            borderRadius: BorderRadius.circular(radiusSmall),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(
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
            borderRadius: BorderRadius.circular(radiusSmall),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // -- Chips -------------------------------------------------------------
      chipTheme: ChipThemeData(
        backgroundColor: lightInputFill,
        selectedColor: colorScheme.primaryContainer,
        labelStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: _lightTextPrimary,
        ),
        secondaryLabelStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: colorScheme.onPrimaryContainer,
        ),
        side: const BorderSide(color: lightBorder),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),

      // -- Bottom Navigation -------------------------------------------------
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: lightCardBg,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: _lightTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
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
          return const TextStyle(
            fontFamily: _fontFamily,
            fontSize: 11,
            fontWeight: FontWeight.w400,
            color: _lightTextSecondary,
          );
        }),
      ),

      // -- Dividers ----------------------------------------------------------
      dividerTheme: const DividerThemeData(
        color: lightDivider,
        thickness: 1,
        space: 1,
      ),

      // -- Snack Bar ---------------------------------------------------------
      snackBarTheme: SnackBarThemeData(
        backgroundColor: darkCardBg,
        contentTextStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 14,
          color: _darkTextPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // -- Dialog ------------------------------------------------------------
      dialogTheme: DialogThemeData(
        backgroundColor: lightCardBg,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
        ),
        titleTextStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: _lightTextPrimary,
        ),
      ),

      // -- Bottom Sheet ------------------------------------------------------
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: lightCardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(radiusLarge)),
        ),
      ),

      // -- Switches ----------------------------------------------------------
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return _lightDisabled;
          }
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return lightCardBg;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return lightBorder;
          }
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary.withValues(alpha: 0.4);
          }
          return lightBorder;
        }),
      ),

      // -- Tab Bar -----------------------------------------------------------
      tabBarTheme: TabBarThemeData(
        labelColor: colorScheme.primary,
        unselectedLabelColor: _lightTextSecondary,
        indicatorColor: colorScheme.primary,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),

      // -- Icon Theme --------------------------------------------------------
      iconTheme: const IconThemeData(
        color: _lightTextSecondary,
        size: 24,
      ),
      primaryIconTheme: IconThemeData(
        color: colorScheme.primary,
        size: 24,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Dark theme
  // ---------------------------------------------------------------------------
  static ThemeData darkTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _warmSeed,
      brightness: Brightness.dark,
      surface: _darkSurface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.dark,
      fontFamily: _fontFamily,
      scaffoldBackgroundColor: _darkSurface,

      // -- Typography --------------------------------------------------------
      textTheme: TextTheme(
        displayLarge: _display,
        displayMedium: _display.copyWith(fontSize: 26),
        displaySmall: _display.copyWith(fontSize: 24),
        headlineLarge: _headline,
        headlineMedium: _headline.copyWith(fontSize: 20),
        headlineSmall: _headline.copyWith(fontSize: 18),
        titleLarge: _title,
        titleMedium: _title.copyWith(fontSize: 15, fontWeight: FontWeight.w500),
        titleSmall: _title.copyWith(fontSize: 13, fontWeight: FontWeight.w500),
        bodyLarge: _body,
        bodyMedium: _body.copyWith(fontSize: 14),
        bodySmall: _caption,
        labelLarge:
            _caption.copyWith(fontWeight: FontWeight.w500, fontSize: 14),
        labelMedium: _caption,
        labelSmall: _caption.copyWith(fontSize: 11),
      ),

      // -- App Bar -----------------------------------------------------------
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: _darkSurface,
        foregroundColor: _darkTextPrimary,
        titleTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: _darkTextPrimary,
        ),
      ),

      // -- Cards -------------------------------------------------------------
      cardTheme: CardThemeData(
        elevation: 0,
        color: darkCardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          side: const BorderSide(color: darkBorder),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),

      // -- Floating Action Button --------------------------------------------
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 1,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
        ),
      ),

      // -- Input Decoration --------------------------------------------------
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkInputFill,
        hintStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 15,
          color: _darkTextTertiary,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: colorScheme.primary, width: 2.0),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: colorScheme.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
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
          disabledBackgroundColor: _darkDisabled,
          disabledForegroundColor: _darkTextTertiary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSmall),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(
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
            borderRadius: BorderRadius.circular(radiusSmall),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(
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
            borderRadius: BorderRadius.circular(radiusSmall),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // -- Chips -------------------------------------------------------------
      chipTheme: ChipThemeData(
        backgroundColor: darkInputFill,
        selectedColor: colorScheme.primaryContainer,
        labelStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: _darkTextPrimary,
        ),
        secondaryLabelStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: colorScheme.onPrimaryContainer,
        ),
        side: const BorderSide(color: darkBorder),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),

      // -- Bottom Navigation -------------------------------------------------
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: darkCardBg,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: _darkTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w400,
        ),
      ),

      // -- Navigation Bar (Material 3) ---------------------------------------
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkCardBg,
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
          return const TextStyle(
            fontFamily: _fontFamily,
            fontSize: 11,
            fontWeight: FontWeight.w400,
            color: _darkTextSecondary,
          );
        }),
      ),

      // -- Dividers ----------------------------------------------------------
      dividerTheme: const DividerThemeData(
        color: _darkDivider,
        thickness: 1,
        space: 1,
      ),

      // -- Snack Bar ---------------------------------------------------------
      snackBarTheme: SnackBarThemeData(
        backgroundColor: lightCardBg,
        contentTextStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 14,
          color: _lightTextPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // -- Dialog ------------------------------------------------------------
      dialogTheme: DialogThemeData(
        backgroundColor: darkCardBg,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
        ),
        titleTextStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: _darkTextPrimary,
        ),
      ),

      // -- Bottom Sheet ------------------------------------------------------
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkCardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(radiusLarge)),
        ),
      ),

      // -- Switches ----------------------------------------------------------
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return _darkDisabled;
          }
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return darkCardBg;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return darkBorder;
          }
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary.withValues(alpha: 0.4);
          }
          return darkBorder;
        }),
      ),

      // -- Tab Bar -----------------------------------------------------------
      tabBarTheme: TabBarThemeData(
        labelColor: colorScheme.primary,
        unselectedLabelColor: _darkTextSecondary,
        indicatorColor: colorScheme.primary,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),

      // -- Icon Theme --------------------------------------------------------
      iconTheme: const IconThemeData(
        color: _darkTextSecondary,
        size: 24,
      ),
      primaryIconTheme: IconThemeData(
        color: colorScheme.primary,
        size: 24,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Spacing constants
  // ---------------------------------------------------------------------------
  static const double spacing4 = 4;
  static const double spacing8 = 8;
  static const double spacing12 = 12;
  static const double spacing16 = 16;
  static const double spacing24 = 24;
  static const double spacing32 = 32;

  // ---------------------------------------------------------------------------
  // High contrast themes (WCAG AAA 7:1 contrast)
  // ---------------------------------------------------------------------------

  /// High contrast light theme with pure black on white for maximum readability.
  ///
  /// All color pairs meet or exceed WCAG AAA (7:1) contrast ratio.
  /// Pure black (#000000) on pure white (#FFFFFF) provides 21:1 contrast.
  static ThemeData highContrastLightTheme() {
    const surfaceWhite = Color(0xFFFFFFFF);
    const pureBlack = Color(0xFF000000);
    const primaryBlue =
        Color(0xFF0000FF); // Standard blue for interactive elements
    const errorRed = Color(0xFFCC0000); // High contrast error

    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: primaryBlue,
      onPrimary: surfaceWhite,
      primaryContainer: primaryBlue.withValues(alpha: 0.15),
      onPrimaryContainer: primaryBlue,
      secondary: primaryBlue,
      onSecondary: surfaceWhite,
      secondaryContainer: primaryBlue.withValues(alpha: 0.15),
      onSecondaryContainer: primaryBlue,
      tertiary: primaryBlue,
      onTertiary: surfaceWhite,
      tertiaryContainer: primaryBlue.withValues(alpha: 0.15),
      onTertiaryContainer: primaryBlue,
      error: errorRed,
      onError: surfaceWhite,
      errorContainer: errorRed.withValues(alpha: 0.15),
      onErrorContainer: errorRed,
      background: surfaceWhite,
      onBackground: pureBlack,
      surface: surfaceWhite,
      onSurface: pureBlack,
      surfaceVariant: Color(0xFFE0E0E0),
      onSurfaceVariant: pureBlack,
      outline: pureBlack,
      outlineVariant: Color(0xFF333333),
      shadow: pureBlack,
      scrim: pureBlack.withValues(alpha: 0.5),
      inverseSurface: pureBlack,
      onInverseSurface: surfaceWhite,
      inversePrimary: Color(0xFF8080FF),
    );

    return _buildHighContrastTheme(
      colorScheme: colorScheme,
      scaffoldBg: surfaceWhite,
      cardBg: surfaceWhite,
      border: pureBlack,
      divider: Color(0xFFE0E0E0),
      textPrimary: pureBlack,
      textSecondary: Color(0xFF333333),
      inputFill: Color(0xFFF5F5F5),
    );
  }

  /// High contrast dark theme with pure white on black for maximum readability.
  ///
  /// All color pairs meet or exceed WCAG AAA (7:1) contrast ratio.
  /// Pure white (#FFFFFF) on pure black (#000000) provides 21:1 contrast.
  static ThemeData highContrastDarkTheme() {
    const surfaceBlack = Color(0xFF000000);
    const pureWhite = Color(0xFFFFFFFF);
    const primaryBlue =
        Color(0xFF6699FF); // Lighter blue for dark mode visibility
    const errorRed = Color(0xFFFF6666); // Lighter red for dark mode visibility

    final colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: primaryBlue,
      onPrimary: surfaceBlack,
      primaryContainer: primaryBlue.withValues(alpha: 0.2),
      onPrimaryContainer: pureWhite,
      secondary: primaryBlue,
      onSecondary: surfaceBlack,
      secondaryContainer: primaryBlue.withValues(alpha: 0.2),
      onSecondaryContainer: pureWhite,
      tertiary: primaryBlue,
      onTertiary: surfaceBlack,
      tertiaryContainer: primaryBlue.withValues(alpha: 0.2),
      onTertiaryContainer: pureWhite,
      error: errorRed,
      onError: surfaceBlack,
      errorContainer: errorRed.withValues(alpha: 0.2),
      onErrorContainer: errorRed,
      background: surfaceBlack,
      onBackground: pureWhite,
      surface: surfaceBlack,
      onSurface: pureWhite,
      surfaceVariant: Color(0xFF1A1A1A),
      onSurfaceVariant: pureWhite,
      outline: pureWhite,
      outlineVariant: Color(0xFFCCCCCC),
      shadow: pureBlack,
      scrim: pureWhite.withValues(alpha: 0.5),
      inverseSurface: pureWhite,
      onInverseSurface: surfaceBlack,
      inversePrimary: Color(0xFF0033CC),
    );

    return _buildHighContrastTheme(
      colorScheme: colorScheme,
      scaffoldBg: surfaceBlack,
      cardBg: surfaceBlack,
      border: pureWhite,
      divider: Color(0xFF333333),
      textPrimary: pureWhite,
      textSecondary: Color(0xFFCCCCCC),
      inputFill: Color(0xFF1A1A1A),
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
      textTheme: TextTheme(
        displayLarge: _display,
        displayMedium: _display.copyWith(fontSize: 26),
        displaySmall: _display.copyWith(fontSize: 24),
        headlineLarge: _headline,
        headlineMedium: _headline.copyWith(fontSize: 20),
        headlineSmall: _headline.copyWith(fontSize: 18),
        titleLarge: _title,
        titleMedium: _title.copyWith(fontSize: 15, fontWeight: FontWeight.w500),
        titleSmall: _title.copyWith(fontSize: 13, fontWeight: FontWeight.w500),
        bodyLarge: _body,
        bodyMedium: _body.copyWith(fontSize: 14),
        bodySmall: _caption,
        labelLarge:
            _caption.copyWith(fontWeight: FontWeight.w500, fontSize: 14),
        labelMedium: _caption,
        labelSmall: _caption.copyWith(fontSize: 11),
      ).apply(
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

      // -- Cards -------------------------------------------------------------
      cardTheme: CardThemeData(
        elevation: 0,
        color: cardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          side: BorderSide(color: border, width: 2), // Thicker borders for HC
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),

      // -- Floating Action Button --------------------------------------------
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 2,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
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
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: border, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: border, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: colorScheme.primary, width: 3),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
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
            borderRadius: BorderRadius.circular(radiusSmall),
            side: BorderSide(color: border, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(
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
            borderRadius: BorderRadius.circular(radiusSmall),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(
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
            borderRadius: BorderRadius.circular(radiusSmall),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: const TextStyle(
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
          borderRadius: BorderRadius.circular(radiusSmall),
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
            colorScheme.brightness == Brightness.light ? surfaceBlack : cardBg,
        contentTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 14,
          color: colorScheme.brightness == Brightness.light
              ? pureWhite
              : textPrimary,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
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
          borderRadius: BorderRadius.circular(radiusLarge),
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
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(radiusLarge)),
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
        labelStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: const TextStyle(
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

  // ---------------------------------------------------------------------------
  // Border radius constants
  // ---------------------------------------------------------------------------
  static const double radiusSmall = 8;
  static const double radiusMedium = 12;
  static const double radiusLarge = 16;
  static const double radiusXLarge = 24;
}
