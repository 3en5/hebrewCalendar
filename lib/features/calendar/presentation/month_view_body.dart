import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/hebrew_date/hebrew_date.dart';
import '../../../domain/hebrew_date/hebrew_date_engine.dart';
import '../application/calendar_display_mode_provider.dart';
import '../application/calendar_view_provider.dart';
import '../application/hebrew_date_engine_provider.dart';
import 'paged_focus_sync.dart';
import 'widgets/month_grid.dart';
import 'widgets/month_grid_data.dart' show addGregorianMonths;

/// The Hebrew month body (M3b): a Google-Calendar-like grid the user swipes
/// through to move between Hebrew months. `CalendarShellScreen`'s body when
/// `CalendarViewType.month` is selected — this widget owns no
/// `Scaffold`/app bar/FAB of its own; those are shared by the shell (this
/// used to be `MonthViewScreen`, the app's whole home screen, before the
/// M3b shell restructuring introduced week/day/agenda siblings).
///
/// Paging preserves the focused date's day-of-month across months (clamped
/// when a month is shorter — the same behavior `HebrewDateEngine.addMonths`
/// already gives every other month-stepping call site), so switching to the
/// day/week view, or creating an event via the shell's FAB, after paging a
/// few months still lands on the day the user was actually looking at.
///
/// M23: in the Gregorian display the pages are Gregorian months. Switching
/// the display rebuilds the pager around the focused day (the owner's
/// "pivot"), so the selected day stays selected.
class MonthViewBody extends ConsumerWidget {
  const MonthViewBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CalendarDisplayMode mode = ref.watch(calendarDisplayModeProvider);
    return _MonthPager(
      key: ValueKey<CalendarDisplayMode>(mode),
      gregorian: mode == CalendarDisplayMode.gregorian,
    );
  }
}

class _MonthPager extends ConsumerStatefulWidget {
  const _MonthPager({required this.gregorian, super.key});

  final bool gregorian;

  @override
  ConsumerState<_MonthPager> createState() => _MonthPagerState();
}

class _MonthPagerState extends ConsumerState<_MonthPager> {
  late final PagedFocusSync _sync;

  @override
  void initState() {
    super.initState();
    final HebrewDateEngine engine = ref.read(hebrewDateEngineProvider);
    _sync = PagedFocusSync(
      initialFocus: ref.read(calendarViewProvider).focusedDate,
      roundToGranularity: (HebrewDate date) => date,
      stepDate: (HebrewDate anchor, int delta) => widget.gregorian
          ? addGregorianMonths(engine, anchor, delta)
          : engine.addMonths(anchor, delta),
      onPageDateChanged: (HebrewDate date) =>
          ref.read(calendarViewProvider.notifier).setFocusedDate(date),
      onAnchorChangedExternally: () => setState(() {}),
    );
  }

  @override
  void dispose() {
    _sync.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<CalendarViewState>(calendarViewProvider, (previous, next) {
      _sync.syncExternalFocus(next.focusedDate);
    });

    return PageView.builder(
      controller: _sync.pageController,
      itemCount: PagedFocusSync.pageWindow * 2 + 1,
      onPageChanged: _sync.onPageChanged,
      itemBuilder: (BuildContext context, int index) {
        return MonthGrid(
          displayedMonth: _sync.dateForPage(index),
          gregorian: widget.gregorian,
        );
      },
    );
  }
}
