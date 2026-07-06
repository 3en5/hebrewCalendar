import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/hebrew_date/hebrew_date.dart';
import '../../../domain/hebrew_date/hebrew_date_engine.dart';
import 'hebrew_date_engine_provider.dart';

/// Holds the Hebrew month currently displayed in the month view (the [day]
/// field is always 1 — this represents a month, not a specific date).
///
/// `autoDispose` (RULES.md §6.3): this state is only meaningful while the
/// month view is on screen, so it is discarded once the last widget
/// watching it is removed.
class DisplayedMonthNotifier extends Notifier<HebrewDate> {
  @override
  HebrewDate build() {
    final HebrewDateEngine engine = ref.watch(hebrewDateEngineProvider);
    final HebrewDate today = engine.fromGregorian(DateTime.now());
    return HebrewDate(year: today.year, month: today.month, day: 1);
  }

  /// Moves the displayed month forward by one Hebrew month.
  void goToNextMonth() {
    final HebrewDateEngine engine = ref.read(hebrewDateEngineProvider);
    state = engine.nextMonth(state);
  }

  /// Moves the displayed month back by one Hebrew month.
  void goToPreviousMonth() {
    final HebrewDateEngine engine = ref.read(hebrewDateEngineProvider);
    state = engine.previousMonth(state);
  }

  /// Jumps directly to the given month (day is normalized to 1).
  void goToMonth(HebrewDate month) {
    state = HebrewDate(year: month.year, month: month.month, day: 1);
  }
}

/// The Hebrew month currently displayed in the month view.
final NotifierProvider<DisplayedMonthNotifier, HebrewDate>
displayedMonthProvider =
    NotifierProvider.autoDispose<DisplayedMonthNotifier, HebrewDate>(
      DisplayedMonthNotifier.new,
    );
