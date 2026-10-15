import 'package:flutter/material.dart';

import 'dimens.dart';

/// Material 3 theming for the app.
///
/// Everything under [TextTheme] is built exclusively from the relative
/// sizes in `dimens.dart` (RULES.md §4.1) — no numeric font-size literal
/// appears in this file.
class AppTheme {
  const AppTheme._();

  /// Seed color: the KALFAPP family blue (same as PowerWatch's
  /// `Colors.blue`; owner-approved rebrand, ARCHITECTURE.md §13).
  static const Color _seedColor = Color(0xFF2196F3);

  /// The add button's accent (owner choice 2026-10-15, sketch 39): a deep
  /// orange, the complement of the brand blue, used on that button only so
  /// the main action stands out in both light and dark mode.
  static const Color addButtonColor = Color(0xFFE8833A);

  /// The KALFAPP family font, bundled under `assets/fonts` (OFL).
  static const String fontFamily = 'Rubik';

  /// Light theme.
  static ThemeData get light => _buildTheme(Brightness.light);

  /// Dark theme.
  static ThemeData get dark => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      fontFamily: fontFamily,
      textTheme: _textTheme,
      // KALFAPP style: a centered title in the brand blue.
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.primary,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: titleLargeRem,
          fontWeight: FontWeight.w600,
          color: colorScheme.primary,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: addButtonColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  static TextTheme get _textTheme => TextTheme(
    displayLarge: TextStyle(fontSize: displayRem, fontWeight: FontWeight.w400),
    displayMedium: TextStyle(fontSize: rem(2.25), fontWeight: FontWeight.w400),
    displaySmall: TextStyle(fontSize: rem(2.0), fontWeight: FontWeight.w400),
    headlineLarge: TextStyle(
      fontSize: headlineRem,
      fontWeight: FontWeight.w500,
    ),
    headlineMedium: TextStyle(
      fontSize: rem(1.625),
      fontWeight: FontWeight.w500,
    ),
    headlineSmall: TextStyle(
      fontSize: titleLargeRem,
      fontWeight: FontWeight.w500,
    ),
    titleLarge: TextStyle(fontSize: titleLargeRem, fontWeight: FontWeight.w500),
    titleMedium: TextStyle(fontSize: titleRem, fontWeight: FontWeight.w500),
    titleSmall: TextStyle(fontSize: bodyLargeRem, fontWeight: FontWeight.w500),
    bodyLarge: TextStyle(fontSize: bodyLargeRem, fontWeight: FontWeight.w400),
    bodyMedium: TextStyle(fontSize: bodyRem, fontWeight: FontWeight.w400),
    bodySmall: TextStyle(fontSize: bodySmallRem, fontWeight: FontWeight.w400),
    labelLarge: TextStyle(fontSize: bodySmallRem, fontWeight: FontWeight.w500),
    labelMedium: TextStyle(fontSize: captionRem, fontWeight: FontWeight.w500),
    labelSmall: TextStyle(fontSize: captionRem, fontWeight: FontWeight.w400),
  );
}
