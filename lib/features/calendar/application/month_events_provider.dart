import 'dart:async' show Timer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart'
    show KeepAliveLink, StreamProviderFamily;

import '../../../domain/event/event_occurrence.dart';
import '../../../domain/hebrew_date/hebrew_date.dart';
import '../../event_editor/application/event_repository_provider.dart';

/// Streams the event occurrences (see [EventOccurrence] — recurring events
/// are expanded, M3a) for the Hebrew month identified by [month].
///
/// Only `month.year`/`month.month` are used — `month.day` is ignored.
///
/// `autoDispose.family`: a fresh, focused subscription per month page
/// actually on screen, closed once that page scrolls out of view
/// (RULES.md §6.2 — no unbounded/global collection listeners).
/// How long a month nobody watches keeps its subscription.
const Duration _kKeepAlive = Duration(minutes: 2);

final StreamProviderFamily<List<EventOccurrence>, HebrewDate>
monthEventsProvider = StreamProvider.autoDispose
    .family<List<EventOccurrence>, HebrewDate>((Ref ref, HebrewDate month) {
      // Round #10: keep a month's subscription for a short while after its
      // page scrolls away, so paging back and forth doesn't re-run the
      // queries every time. Still released (RULES.md §6.2) once idle.
      final KeepAliveLink link = ref.keepAlive();
      Timer? release;
      ref.onCancel(() => release = Timer(_kKeepAlive, link.close));
      ref.onResume(() => release?.cancel());
      ref.onDispose(() => release?.cancel());
      final repository = ref.watch(eventRepositoryProvider);
      return repository.watchEventsForHebrewMonth(month.year, month.month);
    });
