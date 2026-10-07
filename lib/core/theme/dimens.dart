// Central sizing scale for the whole app.
//
// RULES.md §4.1: there is exactly ONE hard-coded base font size in the
// project. Every other text size, spacing value and breakpoint is derived
// from it as a relative multiplier (the Flutter equivalent of CSS `rem`).
// No widget outside this file may declare a numeric font size literal.

/// The single base font size the whole typography scale is derived from.
const double kBaseFontSize = 16.0;

/// Returns [kBaseFontSize] multiplied by [factor], analogous to CSS `rem`.
double rem(double factor) => kBaseFontSize * factor;

/// Extra-small text: captions, hints, timestamps.
double get captionRem => rem(0.75);

/// Small body text: secondary labels.
double get bodySmallRem => rem(0.875);

/// Default body/paragraph text.
double get bodyRem => rem(1.0);

/// Slightly larger body text used for emphasized content.
double get bodyLargeRem => rem(1.125);

/// Titles inside cards, list tiles, dialogs.
double get titleRem => rem(1.25);

/// Large titles: app bar titles, section headers.
double get titleLargeRem => rem(1.5);

/// Headline text: screen headers.
double get headlineRem => rem(1.75);

/// Display text: hero/splash text, large numerals.
double get displayRem => rem(2.5);

/// Spacing scale — also derived from [kBaseFontSize] so the whole layout
/// rhythm scales together with typography.
double spacing(double factor) => kBaseFontSize * factor;

/// Extra-small spacing (tight gaps, icon padding).
double get spacingXs => spacing(0.25);

/// Small spacing (between related inline elements).
double get spacingSm => spacing(0.5);

/// Medium spacing (default gap between widgets).
double get spacingMd => spacing(1.0);

/// Large spacing (section separation).
double get spacingLg => spacing(1.5);

/// Extra-large spacing (screen padding, major sections).
double get spacingXl => spacing(2.0);

/// Extra-extra-large spacing (page-level top/bottom breathing room).
double get spacingXxl => spacing(3.0);

/// Height of one hour row in the week/day hour grid (M3b), derived from
/// [kBaseFontSize] like every other layout constant in this file — not a
/// font size, but RULES.md §4.1's "single base, everything relative"
/// principle applies to layout rhythm just as much as typography.
double get hourRowHeight => spacing(4.0);

/// Width of the leading hour-label gutter in the week/day hour grid (M3b).
double get hourLabelWidth => spacing(3.0);

/// Minimum visual height of a timed event block in the hour grid (M3b), so
/// a very short (or zero-duration) event stays legible/tappable.
double get eventBlockMinHeight => spacing(1.5);

/// Height of a single all-day event chip row above the hour grid (M3b).
double get allDayChipHeight => spacing(1.75);

/// Responsive breakpoints per Material 3 window size classes, expressed in
/// logical pixels (dp). Widths below [breakpointCompactMax] are "compact",
/// widths below [breakpointMediumMax] are "medium", everything above is
/// "expanded".
const double breakpointCompactMax = 600.0;
const double breakpointMediumMax = 840.0;

/// Material 3 window size classes used for responsive layout decisions.
enum WindowSizeClass { compact, medium, expanded }

/// Maps a raw width in logical pixels to a [WindowSizeClass].
WindowSizeClass windowSizeClassForWidth(double width) {
  if (width < breakpointCompactMax) {
    return WindowSizeClass.compact;
  }
  if (width < breakpointMediumMax) {
    return WindowSizeClass.medium;
  }
  return WindowSizeClass.expanded;
}
