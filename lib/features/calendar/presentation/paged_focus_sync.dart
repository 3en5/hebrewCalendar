import 'package:flutter/widgets.dart';

import '../../../domain/hebrew_date/hebrew_date.dart';

/// Shared paging/focus-sync bookkeeping for the month/week/day views
/// (M3b): each of those views is a `PageView` whose pages are computed as
/// `anchor + N steps` (months, weeks, or days), where `anchor` is fixed when
/// the view builds and only changes when the shared focused date is moved
/// from *outside* that view's own swiping — a chevron/"today" tap, or
/// switching in from another view.
///
/// The three views only differ in [roundToGranularity] (how a raw focused
/// date maps to this view's own anchor — e.g. the week view snaps to that
/// week's Sunday) and [stepDate] (how many calendar units one page
/// represents). Extracting this once avoids writing the same
/// `PageController` + external-change-detection dance three times.
class PagedFocusSync {
  PagedFocusSync({
    required HebrewDate initialFocus,
    required this.roundToGranularity,
    required this.stepDate,
    required this.onPageDateChanged,
    required this.onAnchorChangedExternally,
  }) : anchor = roundToGranularity(initialFocus),
       pageController = PageController(initialPage: centerPage);

  /// Pages available on either side of the anchor — comfortably beyond any
  /// realistic browsing range (mirrors the original month view's window).
  static const int pageWindow = 600;
  static const int centerPage = pageWindow;

  HebrewDate anchor;
  final PageController pageController;

  /// Maps an arbitrary focused date to this view's own granularity (e.g.
  /// identity for day/month, "start of week" for week).
  final HebrewDate Function(HebrewDate date) roundToGranularity;

  /// The date shown on [anchor] + [delta] steps (delta may be negative).
  final HebrewDate Function(HebrewDate anchor, int delta) stepDate;

  /// Called when a page change originates from *this* view (a swipe or
  /// programmatic page animation) — propagates the new focus outward.
  final void Function(HebrewDate date) onPageDateChanged;

  /// Called when [syncExternalFocus] re-anchors after an outside focus
  /// change, so the widget can `setState` and rebuild its currently visible
  /// page with the new [anchor].
  final VoidCallback onAnchorChangedExternally;

  HebrewDate dateForPage(int page) => stepDate(anchor, page - centerPage);

  int get _currentPage {
    if (!pageController.hasClients) {
      return centerPage;
    }
    return (pageController.page ?? centerPage.toDouble()).round();
  }

  void onPageChanged(int page) => onPageDateChanged(dateForPage(page));

  /// Reconciles an externally-changed focused date (from the app bar's
  /// "today" button, a chevron, or switching in from another view) with
  /// this view's paging. A no-op when [focusedDate] already matches what
  /// this view is currently showing — in particular, when the change
  /// actually originated from this view's own [onPageChanged] a moment ago.
  void syncExternalFocus(HebrewDate focusedDate) {
    final HebrewDate rounded = roundToGranularity(focusedDate);
    if (rounded == dateForPage(_currentPage)) {
      return;
    }
    final bool wasAtCenter = _currentPage == centerPage;
    anchor = rounded;
    onAnchorChangedExternally();
    if (pageController.hasClients && !wasAtCenter) {
      pageController.jumpToPage(centerPage);
    }
  }

  void dispose() => pageController.dispose();
}
