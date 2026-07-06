import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/hebrew_date/hebrew_date.dart';
import '../../../domain/hebrew_date/hebrew_date_engine.dart';
import 'hebrew_date_engine_provider.dart';

/// Which of the four calendar layouts (M3b) is currently shown by
/// `CalendarShellScreen`.
enum CalendarViewType { month, week, day, agenda }

/// The calendar shell's navigation state: which [viewType] is on screen and
/// which [focusedDate] it's centered on.
///
/// A single [focusedDate] (rather than one per view) is deliberate: it's
/// carried over when the user switches views (task brief M3b §4 — the shell
/// is one screen with a switching body, not four independent screens), so
/// switching from month to day view lands on the day the user was actually
/// looking at, not some unrelated remembered day. Each view interprets
/// [focusedDate] at its own granularity (month view only reads
/// year/month; week view finds the containing week via
/// `HebrewDateEngine.startOfWeek`; day/agenda use it exactly).
class CalendarViewState {
  const CalendarViewState({required this.viewType, required this.focusedDate});

  final CalendarViewType viewType;
  final HebrewDate focusedDate;

  CalendarViewState copyWith({
    CalendarViewType? viewType,
    HebrewDate? focusedDate,
  }) => CalendarViewState(
    viewType: viewType ?? this.viewType,
    focusedDate: focusedDate ?? this.focusedDate,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CalendarViewState &&
          other.viewType == viewType &&
          other.focusedDate == focusedDate);

  @override
  int get hashCode => Object.hash(viewType, focusedDate);
}

/// Holds and mutates [CalendarViewState].
///
/// `autoDispose` (RULES.md §6.3): this is screen-scoped navigation state for
/// `CalendarShellScreen`, the app's single home screen while signed in —
/// discarded like `DisplayedMonthNotifier` was before it once nothing is
/// watching (e.g. on sign-out).
class CalendarViewNotifier extends Notifier<CalendarViewState> {
  @override
  CalendarViewState build() {
    final HebrewDateEngine engine = ref.watch(hebrewDateEngineProvider);
    return CalendarViewState(
      viewType: CalendarViewType.month,
      focusedDate: engine.fromGregorian(DateTime.now()),
    );
  }

  /// Switches the visible body, keeping [CalendarViewState.focusedDate].
  void setViewType(CalendarViewType type) =>
      state = state.copyWith(viewType: type);

  /// Moves the focus to [date] (e.g. a page swipe landed on a new
  /// month/week/day, or the user tapped a specific day).
  void setFocusedDate(HebrewDate date) =>
      state = state.copyWith(focusedDate: date);

  /// The "היום" (today) app bar action: refocuses on today without
  /// changing which view is shown.
  void goToToday() {
    final HebrewDateEngine engine = ref.read(hebrewDateEngineProvider);
    state = state.copyWith(focusedDate: engine.fromGregorian(DateTime.now()));
  }
}

/// The calendar shell's navigation state, shared by all four views and the
/// app bar's view switcher/today button.
final NotifierProvider<CalendarViewNotifier, CalendarViewState>
calendarViewProvider =
    NotifierProvider.autoDispose<CalendarViewNotifier, CalendarViewState>(
      CalendarViewNotifier.new,
    );
