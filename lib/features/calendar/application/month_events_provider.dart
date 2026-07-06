import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show StreamProviderFamily;

import '../../../domain/event/event.dart';
import '../../../domain/hebrew_date/hebrew_date.dart';
import '../../event_editor/application/event_repository_provider.dart';

/// Streams the events for the Hebrew month identified by [month].
///
/// Only `month.year`/`month.month` are used — `month.day` is ignored, by
/// the same convention [displayedMonthProvider] uses (always 1).
///
/// `autoDispose.family`: a fresh, focused subscription per month page
/// actually on screen, closed once that page scrolls out of view
/// (RULES.md §6.2 — no unbounded/global collection listeners).
final StreamProviderFamily<List<Event>, HebrewDate> monthEventsProvider =
    StreamProvider.autoDispose.family<List<Event>, HebrewDate>((
      Ref ref,
      HebrewDate month,
    ) {
      final repository = ref.watch(eventRepositoryProvider);
      return repository.watchEventsForHebrewMonth(month.year, month.month);
    });
