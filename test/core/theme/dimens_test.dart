// Unit tests for the rem/spacing math in lib/core/theme/dimens.dart.
// RULES.md §4.1: all text sizes must be derived from kBaseFontSize, so we
// pin down the exact multipliers here as a regression guard.

import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/core/theme/dimens.dart';

void main() {
  group('rem', () {
    test('rem(1.0) equals the base font size', () {
      expect(rem(1.0), kBaseFontSize);
    });

    test('rem scales linearly with the base font size', () {
      expect(rem(2.0), kBaseFontSize * 2);
      expect(rem(0.5), kBaseFontSize * 0.5);
    });

    test('named text sizes are correct multiples of the base size', () {
      expect(captionRem, kBaseFontSize * 0.75);
      expect(bodySmallRem, kBaseFontSize * 0.875);
      expect(bodyRem, kBaseFontSize * 1.0);
      expect(bodyLargeRem, kBaseFontSize * 1.125);
      expect(titleRem, kBaseFontSize * 1.25);
      expect(titleLargeRem, kBaseFontSize * 1.5);
      expect(headlineRem, kBaseFontSize * 1.75);
      expect(displayRem, kBaseFontSize * 2.5);
    });

    test('named sizes are in ascending order', () {
      final List<double> sizes = <double>[
        captionRem,
        bodySmallRem,
        bodyRem,
        bodyLargeRem,
        titleRem,
        titleLargeRem,
        headlineRem,
        displayRem,
      ];
      for (int i = 1; i < sizes.length; i++) {
        expect(sizes[i], greaterThan(sizes[i - 1]));
      }
    });
  });

  group('spacing', () {
    test('spacing(1.0) equals the base font size', () {
      expect(spacing(1.0), kBaseFontSize);
    });

    test('named spacing values are correct multiples of the base size', () {
      expect(spacingXs, kBaseFontSize * 0.25);
      expect(spacingSm, kBaseFontSize * 0.5);
      expect(spacingMd, kBaseFontSize * 1.0);
      expect(spacingLg, kBaseFontSize * 1.5);
      expect(spacingXl, kBaseFontSize * 2.0);
      expect(spacingXxl, kBaseFontSize * 3.0);
    });
  });

  group('windowSizeClassForWidth', () {
    test('widths below the compact breakpoint are compact', () {
      expect(windowSizeClassForWidth(0), WindowSizeClass.compact);
      expect(
        windowSizeClassForWidth(breakpointCompactMax - 1),
        WindowSizeClass.compact,
      );
    });

    test('widths between the breakpoints are medium', () {
      expect(
        windowSizeClassForWidth(breakpointCompactMax),
        WindowSizeClass.medium,
      );
      expect(
        windowSizeClassForWidth(breakpointMediumMax - 1),
        WindowSizeClass.medium,
      );
    });

    test('widths at or above the medium breakpoint are expanded', () {
      expect(
        windowSizeClassForWidth(breakpointMediumMax),
        WindowSizeClass.expanded,
      );
      expect(
        windowSizeClassForWidth(breakpointMediumMax + 100),
        WindowSizeClass.expanded,
      );
    });
  });
}
