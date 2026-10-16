import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/hebrew_date/hebrew_date.dart';

/// The day at the top of the agenda list (owner request 2026-10-16), so
/// the app bar's title shows that day's month and follows the scroll, as
/// the other views show theirs. Null until the agenda reports one.
class AgendaTopDateNotifier extends Notifier<HebrewDate?> {
  @override
  HebrewDate? build() => null;

  void set(HebrewDate? date) {
    if (date != state) {
      state = date;
    }
  }
}

final NotifierProvider<AgendaTopDateNotifier, HebrewDate?>
agendaTopDateProvider = NotifierProvider<AgendaTopDateNotifier, HebrewDate?>(
  AgendaTopDateNotifier.new,
);
