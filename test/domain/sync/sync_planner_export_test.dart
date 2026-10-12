// Unit tests for sync_planner.dart (M5a — the core of this milestone):
// every conflict-resolution decision the Google Calendar sync engine
// relies on, fully exercised with no I/O.

import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/domain/event/event.dart';
import 'package:hebrew_calendar/domain/event/event_occurrence.dart';
import 'package:hebrew_calendar/domain/event/recurrence_expander.dart';
import 'package:hebrew_calendar/domain/event/recurrence_rule.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date_engine.dart';
import 'package:hebrew_calendar/domain/sync/export_candidate.dart';
import 'package:hebrew_calendar/domain/sync/occurrence_key.dart';
import 'package:hebrew_calendar/domain/sync/sync_action.dart';
import 'package:hebrew_calendar/domain/sync/sync_planner.dart';
import 'package:hebrew_calendar/domain/sync/sync_state.dart';

const HebrewDateEngine _engine = HebrewDateEngine();

Event _event({
  String id = 'event-1',
  HebrewDate? hebrewDate,
  RecurrenceRule recurrence = const RecurrenceRule(),
  GoogleSyncState googleSync = const GoogleSyncState(),
  Map<String, GoogleSyncState> googleInstanceSync =
      const <String, GoogleSyncState>{},
  DateTime? updatedAt,
}) {
  final DateTime timestamp = updatedAt ?? DateTime(2026, 6, 1, 10);
  return Event(
    id: id,
    ownerUid: 'uid-1',
    calendarId: 'default',
    title: 'אירוע',
    hebrewDate:
        hebrewDate ??
        const HebrewDate(year: 5786, month: HebrewMonth.tevet, day: 10),
    recurrence: recurrence,
    createdAt: timestamp,
    updatedAt: timestamp,
    googleSync: googleSync,
    googleInstanceSync: googleInstanceSync,
  );
}

void main() {
  group('planExportActions — single (non-recurring) candidates', () {
    test(
      'a brand-new local event (no known googleEventId) -> createRemote',
      () {
        final Event event = _event(
          googleSync: const GoogleSyncState(dirty: true),
        );
        final List<SyncAction> actions = planExportActions(
          candidates: <ExportCandidate>[
            ExportCandidate(
              event: event,
              occurrenceDate: event.hebrewDate,
              occurrenceKey: occurrenceKeyFor(event.hebrewDate),
            ),
          ],
          staleInstances: const <StaleExportInstance>[],
        );
        expect(actions, hasLength(1));
        expect(actions.single, isA<CreateRemoteAction>());
        final CreateRemoteAction action = actions.single as CreateRemoteAction;
        expect(action.event.id, event.id);
        expect(action.occurrenceDate, event.hebrewDate);
      },
    );

    test(
      'a dirty local edit with a known googleEventId -> updateRemote with the known etag',
      () {
        final Event event = _event(
          googleSync: const GoogleSyncState(
            googleEventId: 'remote-9',
            etag: 'etag-9',
            dirty: true,
          ),
        );
        final List<SyncAction> actions = planExportActions(
          candidates: <ExportCandidate>[
            ExportCandidate(
              event: event,
              occurrenceDate: event.hebrewDate,
              occurrenceKey: occurrenceKeyFor(event.hebrewDate),
              knownState: event.googleSync,
            ),
          ],
          staleInstances: const <StaleExportInstance>[],
        );
        expect(actions.single, isA<UpdateRemoteAction>());
        final UpdateRemoteAction action = actions.single as UpdateRemoteAction;
        expect(action.googleEventId, 'remote-9');
        expect(action.etag, 'etag-9');
      },
    );

    test('an already-synced, non-dirty event -> skip (upToDate)', () {
      final Event event = _event(
        googleSync: const GoogleSyncState(
          googleEventId: 'remote-9',
          etag: 'etag-9',
        ),
      );
      final List<SyncAction> actions = planExportActions(
        candidates: <ExportCandidate>[
          ExportCandidate(
            event: event,
            occurrenceDate: event.hebrewDate,
            occurrenceKey: occurrenceKeyFor(event.hebrewDate),
            knownState: event.googleSync,
          ),
        ],
        staleInstances: const <StaleExportInstance>[],
      );
      expect(actions.single, isA<SkipAction>());
      expect((actions.single as SkipAction).reason, SkipReason.upToDate);
    });
  });

  group('planExportActions — deletion (stale instances)', () {
    test(
      'a previously-exported instance no longer among the candidates -> deleteRemote',
      () {
        final List<SyncAction> actions = planExportActions(
          candidates: const <ExportCandidate>[],
          staleInstances: <StaleExportInstance>[
            const StaleExportInstance(
              eventId: 'event-1',
              occurrenceKey: '5786-tevet-10',
              state: GoogleSyncState(googleEventId: 'remote-9', etag: 'etag-9'),
            ),
          ],
        );
        expect(actions.single, isA<DeleteRemoteAction>());
        final DeleteRemoteAction action = actions.single as DeleteRemoteAction;
        expect(action.googleEventId, 'remote-9');
        expect(action.etag, 'etag-9');
        expect(action.eventId, 'event-1');
      },
    );
  });

  group(
    'recurring events materialize the correct instances (reusing recurrence_expander)',
    () {
      test(
        'a yearly event anchored on Adar (non-leap base) exports one instance per relevant year, mapping Adar correctly',
        () {
          // 5786 is not a leap year (single plain Adar); 5787 is a leap year
          // (Adar I/Adar II) — ARCHITECTURE.md §4 Adar-mapping policy.
          final Event event = _event(
            hebrewDate: const HebrewDate(
              year: 5786,
              month: HebrewMonth.adar,
              day: 14,
            ),
            recurrence: const RecurrenceRule(type: RecurrenceType.hebrewYearly),
            googleSync: const GoogleSyncState(dirty: true),
          );
          final HebrewDate from = const HebrewDate(
            year: 5786,
            month: HebrewMonth.tishrei,
            day: 1,
          );
          final HebrewDate to = const HebrewDate(
            year: 5788,
            month: HebrewMonth.elul,
            day: 29,
          );
          final List<EventOccurrence> occurrences = occurrencesForEventInRange(
            event: event,
            from: from,
            to: to,
            engine: _engine,
          );
          // Expect exactly 3 occurrences: 5786 (plain Adar), 5787 (leap -> Adar II, the M15 default), 5788.
          expect(occurrences, hasLength(3));
          final List<ExportCandidate> candidates = <ExportCandidate>[
            for (final EventOccurrence occurrence in occurrences)
              ExportCandidate(
                event: event,
                occurrenceDate: occurrence.occurrenceDate,
                occurrenceKey: occurrenceKeyFor(occurrence.occurrenceDate),
              ),
          ];
          final List<SyncAction> actions = planExportActions(
            candidates: candidates,
            staleInstances: const <StaleExportInstance>[],
          );
          expect(actions, hasLength(3));
          expect(actions, everyElement(isA<CreateRemoteAction>()));
          final Set<String> keys = actions
              .map((SyncAction a) => (a as CreateRemoteAction).occurrenceKey)
              .toSet();
          expect(keys, <String>{
            occurrenceKeyFor(
              const HebrewDate(year: 5786, month: HebrewMonth.adar, day: 14),
            ),
            occurrenceKeyFor(
              const HebrewDate(year: 5787, month: HebrewMonth.adarII, day: 14),
            ),
            occurrenceKeyFor(
              const HebrewDate(year: 5788, month: HebrewMonth.adar, day: 14),
            ),
          });
        },
      );

      test(
        'a monthly event anchored on day 30 exports at most one instance per month, clamped in short months (no duplicates)',
        () {
          // Cheshvan/Kislev alternate between 29 and 30 days depending on the
          // year (ARCHITECTURE.md §4 day-30 policy) — whichever months in this
          // window are short clamp to day 29 instead of firing twice or being
          // skipped; the key invariant under test is "no duplicate occurrence
          // keys, at most one per month", not the exact count (already
          // exhaustively covered by recurrence_expander_monthly_test.dart).
          final Event event = _event(
            hebrewDate: const HebrewDate(
              year: 5786,
              month: HebrewMonth.cheshvan,
              day: 30,
            ),
            recurrence: const RecurrenceRule(
              type: RecurrenceType.hebrewMonthly,
            ),
            googleSync: const GoogleSyncState(dirty: true),
          );
          final HebrewDate from = const HebrewDate(
            year: 5786,
            month: HebrewMonth.cheshvan,
            day: 1,
          );
          final HebrewDate to = const HebrewDate(
            year: 5786,
            month: HebrewMonth.shvat,
            day: 30,
          );
          final List<EventOccurrence> occurrences = occurrencesForEventInRange(
            event: event,
            from: from,
            to: to,
            engine: _engine,
          );
          expect(occurrences.length, lessThanOrEqualTo(4));
          final List<ExportCandidate> candidates = <ExportCandidate>[
            for (final EventOccurrence occurrence in occurrences)
              ExportCandidate(
                event: event,
                occurrenceDate: occurrence.occurrenceDate,
                occurrenceKey: occurrenceKeyFor(occurrence.occurrenceDate),
              ),
          ];
          final List<SyncAction> actions = planExportActions(
            candidates: candidates,
            staleInstances: const <StaleExportInstance>[],
          );
          expect(actions, everyElement(isA<CreateRemoteAction>()));
          final Set<String> keys = actions
              .map((SyncAction a) => (a as CreateRemoteAction).occurrenceKey)
              .toSet();
          expect(
            keys,
            hasLength(actions.length),
            reason: 'no duplicate occurrence keys',
          );
          final Set<HebrewMonth> months = occurrences
              .map((EventOccurrence o) => o.occurrenceDate.month)
              .toSet();
          expect(
            months.length,
            occurrences.length,
            reason: 'at most one occurrence per month',
          );
        },
      );

      test(
        'a recurring event with a mix of new, already-synced and stale instances plans create/skip/delete correctly',
        () {
          final Event event = _event(
            hebrewDate: const HebrewDate(
              year: 5786,
              month: HebrewMonth.tevet,
              day: 1,
            ),
            recurrence: const RecurrenceRule(type: RecurrenceType.weekly),
            googleSync: const GoogleSyncState(dirty: true),
            googleInstanceSync: <String, GoogleSyncState>{
              // Already synced, not dirty content-wise for this instance (the
              // planner only looks at the event-level dirty flag, so an
              // already-known instance with the event dirty still updates).
              occurrenceKeyFor(
                const HebrewDate(year: 5786, month: HebrewMonth.tevet, day: 1),
              ): const GoogleSyncState(
                googleEventId: 'remote-a',
                etag: 'etag-a',
              ),
              // No longer produced by the expander for the window below ->
              // stale, should be deleted.
              '5786-tevet-99-stale': const GoogleSyncState(
                googleEventId: 'remote-stale',
                etag: 'etag-stale',
              ),
            },
          );
          final HebrewDate from = const HebrewDate(
            year: 5786,
            month: HebrewMonth.tevet,
            day: 1,
          );
          final HebrewDate to = const HebrewDate(
            year: 5786,
            month: HebrewMonth.tevet,
            day: 15,
          );
          final List<EventOccurrence> occurrences = occurrencesForEventInRange(
            event: event,
            from: from,
            to: to,
            engine: _engine,
          );
          // Weekly from day 1 within a 15-day window -> 3 occurrences (1, 8, 15).
          expect(occurrences, hasLength(3));

          final Set<String> currentKeys = occurrences
              .map((EventOccurrence o) => occurrenceKeyFor(o.occurrenceDate))
              .toSet();
          final List<ExportCandidate> candidates = <ExportCandidate>[
            for (final EventOccurrence occurrence in occurrences)
              ExportCandidate(
                event: event,
                occurrenceDate: occurrence.occurrenceDate,
                occurrenceKey: occurrenceKeyFor(occurrence.occurrenceDate),
                knownState:
                    event.googleInstanceSync[occurrenceKeyFor(
                      occurrence.occurrenceDate,
                    )],
              ),
          ];
          final List<StaleExportInstance> stale = <StaleExportInstance>[
            for (final MapEntry<String, GoogleSyncState> entry
                in event.googleInstanceSync.entries)
              if (!currentKeys.contains(entry.key))
                StaleExportInstance(
                  eventId: event.id,
                  occurrenceKey: entry.key,
                  state: entry.value,
                ),
          ];
          final List<SyncAction> actions = planExportActions(
            candidates: candidates,
            staleInstances: stale,
          );

          final List<CreateRemoteAction> creates = actions
              .whereType<CreateRemoteAction>()
              .toList();
          final List<UpdateRemoteAction> updates = actions
              .whereType<UpdateRemoteAction>()
              .toList();
          final List<DeleteRemoteAction> deletes = actions
              .whereType<DeleteRemoteAction>()
              .toList();

          expect(
            creates,
            hasLength(2),
            reason: 'the two never-synced occurrences (day 8, 15)',
          );
          expect(
            updates,
            hasLength(1),
            reason: 'the one already-known occurrence (day 1)',
          );
          expect(
            deletes,
            hasLength(1),
            reason: 'the stale instance no longer in range',
          );
          expect(deletes.single.googleEventId, 'remote-stale');
          expect(updates.single.googleEventId, 'remote-a');
        },
      );
    },
  );
}
