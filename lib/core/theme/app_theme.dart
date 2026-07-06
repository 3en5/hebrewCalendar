import 'package:flutter/material.dart';

import 'dimens.dart';

/// Material 3 theming for the app.
///
/// Everything under [TextTheme] is built exclusively from the relative
/// sizes in `dimens.dart` (RULES.md §4.1) — no numeric font-size literal
/// appears in this file.
class AppTheme {
  const AppTheme._();

  /// Seed color: Google-Calendar-like blue.
  static const Color _seedColor = Color(0xFF1A73E8);

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
      textTheme: _textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: TextStyle(
          fontSize: titleLargeRem,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
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
