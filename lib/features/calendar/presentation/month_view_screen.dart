import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/hebrew_date/hebrew_date.dart';
import '../../../domain/hebrew_date/hebrew_date_engine.dart';
import '../../../domain/hebrew_date/hebrew_numerals.dart';
import '../../../l10n/app_localizations.dart';
import '../application/displayed_month_provider.dart';
import '../application/hebrew_date_engine_provider.dart';
import 'widgets/month_grid.dart';

/// The Hebrew month view: a Google-Calendar-like grid the user swipes
/// through (or steps through with chevron buttons) to move between Hebrew
/// months. This is the app's home screen as of M1.
///
/// The [PageView] is backed by a fixed window of pages centered on the
/// month the screen was first built with; each page index maps to a
/// Hebrew month via `HebrewDateEngine.addMonths` from that anchor. Paging
/// (by gesture or by the chevron buttons animating the controller) is the
/// single source of truth, propagated to [displayedMonthProvider] via
/// `onPageChanged` so the app bar title always matches what's on screen.
/// RTL swipe direction falls out of the ambient Hebrew [Directionality]
/// that Flutter's scrollables already respect — no special-casing needed.
class MonthViewScreen extends ConsumerStatefulWidget {
  const MonthViewScreen({super.key});

  @override
  ConsumerState<MonthViewScreen> createState() => _MonthViewScreenState();
}

class _MonthViewScreenState extends ConsumerState<MonthViewScreen> {
  /// Number of pages available on either side of the anchor month
  /// (~50 years), comfortably beyond any realistic browsing range.
  static const int _pageWindow = 600;
  static const int _centerPage = _pageWindow;
  static const Duration _pageAnimationDuration = Duration(milliseconds: 250);

  late final PageController _pageController;
  late final HebrewDate _anchorMonth;

  @override
  void initState() {
    super.initState();
    _anchorMonth = ref.read(displayedMonthProvider);
    _pageController = PageController(initialPage: _centerPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  HebrewDate _monthForPage(int page) {
    final HebrewDateEngine engine = ref.read(hebrewDateEngineProvider);
    return engine.addMonths(_anchorMonth, page - _centerPage);
  }

  void _onPageChanged(int page) {
    ref.read(displayedMonthProvider.notifier).goToMonth(_monthForPage(page));
  }

  void _stepPage(int delta) {
    final int currentPage = (_pageController.page ?? _centerPage.toDouble())
        .round();
    unawaited(
      _pageController.animateToPage(
        currentPage + delta,
        duration: _pageAnimationDuration,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final HebrewDate displayedMonth = ref.watch(displayedMonthProvider);
    final HebrewDateEngine engine = ref.watch(hebrewDateEngineProvider);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String title =
        '${engine.monthName(displayedMonth.month)} '
        '${hebrewYearNumeral(displayedMonth.year)}';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: <Widget>[
          IconButton(
            // Icons.arrow_back/arrow_forward carry IconData.matchTextDirection
            // = true, so they mirror automatically under RTL Directionality —
            // no manual left/right logic needed (RULES.md §4.4).
            icon: const Icon(Icons.arrow_back),
            tooltip: l10n.calendarPreviousMonth,
            onPressed: () => _stepPage(-1),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            tooltip: l10n.calendarNextMonth,
            onPressed: () => _stepPage(1),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: _pageWindow * 2 + 1,
        onPageChanged: _onPageChanged,
        itemBuilder: (BuildContext context, int index) {
          return MonthGrid(displayedMonth: _monthForPage(index));
        },
      ),
    );
  }
}
