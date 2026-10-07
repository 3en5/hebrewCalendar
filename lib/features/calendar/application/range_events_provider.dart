import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show StreamProviderFamily;

import '../../../domain/event/event_occurrence.dart';
import '../../../domain/hebrew_date/hebrew_date.dart';
import '../../event_editor/application/event_repository_provider.dart';

/// An arbitrary, inclusive Hebrew-date range: the family key for
/// [rangeEventsProvider]. A record gets free structural equality (both
/// fields are [HebrewDate], which already implements `==`), exactly what a
/// `.family` provider needs to key/reuse subscriptions.
typedef HebrewDateRange = ({HebrewDate from, HebrewDate to});

/// Streams the event occurrences (see [EventOccurrence] — recurring events
/// are expanded, M3a) within [range], inclusive of both ends.
///
/// Used by the week/day/agenda views (M3b) via
/// `EventRepository.watchOccurrencesInRange`, instead of
/// [monthEventsProvider]'s month-shaped `watchEventsForHebrewMonth`: a week
/// or single day rarely aligns with Hebrew month boundaries, and the agenda
/// view's rolling window spans several months.
///
/// `autoDispose.family`: a fresh, focused subscription per range actually on
/// screen (one week page, one day page, or the agenda's current window),
/// closed once that page/window is no longer watched (RULES.md §6.2).
final StreamProviderFamily<List<EventOccurrence>, HebrewDateRange>
rangeEventsProvider = StreamProvider.autoDispose
    .family<List<EventOccurrence>, HebrewDateRange>((
      Ref ref,
      HebrewDateRange range,
    ) {
      final repository = ref.watch(eventRepositoryProvider);
      return repository.watchOccurrencesInRange(range.from, range.to);
    });
