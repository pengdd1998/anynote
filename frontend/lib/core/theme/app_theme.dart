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
  static const _lightTextTertiary = Color(0xFF7A6E62); // Warm muted grey (WCAG AA 4.5:1 on _lightSurface)
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
  static const _darkTextSecondary = Color(0xFFA3988E); // Warm medium grey (WCAG AA 4.5:1 on _darkSurface)
  static const _darkTextTertiary = Color(0xFF9E9288); // Warm dark muted (WCAG AA 4.5:1 on _darkSurface)
  static const darkInputFill = Color(0xFF2C2826); // Warm dark fill
  static const darkBorder = Color(0xFF3D3835); // Warm dark border
  static const _darkDivider = Color(0xFF332E2B); // Warm dark divider
  static const _darkDisabled = Color(0xFF4A4340); // Warm dark disabled

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
        labelLarge: _caption.copyWith(fontWeight: FontWeight.w500, fontSize: 14),
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusLarge)),
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
        labelLarge: _caption.copyWith(fontWeight: FontWeight.w500, fontSize: 14),
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusLarge)),
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
  // Border radius constants
  // ---------------------------------------------------------------------------
  static const double radiusSmall = 8;
  static const double radiusMedium = 12;
  static const double radiusLarge = 16;
  static const double radiusXLarge = 24;
}
