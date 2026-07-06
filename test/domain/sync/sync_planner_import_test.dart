// Unit tests for sync_planner.dart (M5a — the core of this milestone):
// every conflict-resolution decision the Google Calendar sync engine
// relies on, fully exercised with no I/O.

import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/domain/event/event.dart';
import 'package:hebrew_calendar/domain/event/recurrence_rule.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date.dart';
import 'package:hebrew_calendar/domain/sync/occurrence_key.dart';
import 'package:hebrew_calendar/domain/sync/remote_event_snapshot.dart';
import 'package:hebrew_calendar/domain/sync/sync_action.dart';
import 'package:hebrew_calendar/domain/sync/sync_planner.dart';
import 'package:hebrew_calendar/domain/sync/sync_state.dart';

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

RemoteEventSnapshot _remote({
  String googleEventId = 'remote-1',
  String etag = 'etag-1',
  DateTime? updatedAt,
  bool isCancelled = false,
  String? hebcalEventId,
  String? hebcalOccurrence,
}) => RemoteEventSnapshot(
  googleEventId: googleEventId,
  etag: etag,
  updatedAt: updatedAt ?? DateTime(2026, 6, 1, 12),
  isCancelled: isCancelled,
  hebcalEventId: hebcalEventId,
  hebcalOccurrence: hebcalOccurrence,
);

void main() {
  group('planImportActions', () {
    test('a brand-new remote event with no local match -> createLocal', () {
      final RemoteEventSnapshot remote = _remote();
      final List<SyncAction> actions = planImportActions(
        remoteEvents: <RemoteEventSnapshot>[remote],
        localEventsByGoogleId: const <String, Event>{},
      );
      expect(actions.single, isA<CreateLocalAction>());
      expect((actions.single as CreateLocalAction).remote, remote);
    });

    test('remote updated after local -> updateLocal (last-write-wins)', () {
      final Event local = _event(updatedAt: DateTime(2026, 6, 1, 8));
      final RemoteEventSnapshot remote = _remote(
        googleEventId: 'remote-1',
        updatedAt: DateTime(2026, 6, 1, 9),
      );
      final List<SyncAction> actions = planImportActions(
        remoteEvents: <RemoteEventSnapshot>[remote],
        localEventsByGoogleId: <String, Event>{'remote-1': local},
      );
      expect(actions.single, isA<UpdateLocalAction>());
      final UpdateLocalAction action = actions.single as UpdateLocalAction;
      expect(action.existingEventId, local.id);
      expect(action.remote, remote);
    });

    test(
      'local updated at/after remote -> skip (localIsNewer): export side pushes it instead',
      () {
        final Event local = _event(updatedAt: DateTime(2026, 6, 1, 12));
        final RemoteEventSnapshot remote = _remote(
          googleEventId: 'remote-1',
          updatedAt: DateTime(2026, 6, 1, 9),
        );
        final List<SyncAction> actions = planImportActions(
          remoteEvents: <RemoteEventSnapshot>[remote],
          localEventsByGoogleId: <String, Event>{'remote-1': local},
        );
        expect(actions.single, isA<SkipAction>());
        expect((actions.single as SkipAction).reason, SkipReason.localIsNewer);
      },
    );

    test(
      'local updated exactly at the remote timestamp -> skip (not strictly after)',
      () {
        final DateTime same = DateTime(2026, 6, 1, 9);
        final Event local = _event(updatedAt: same);
        final RemoteEventSnapshot remote = _remote(
          googleEventId: 'remote-1',
          updatedAt: same,
        );
        final List<SyncAction> actions = planImportActions(
          remoteEvents: <RemoteEventSnapshot>[remote],
          localEventsByGoogleId: <String, Event>{'remote-1': local},
        );
        expect((actions.single as SkipAction).reason, SkipReason.localIsNewer);
      },
    );

    test(
      'a cancelled remote event with a known local match -> deleteLocal',
      () {
        final Event local = _event();
        final RemoteEventSnapshot remote = _remote(
          googleEventId: 'remote-1',
          isCancelled: true,
        );
        final List<SyncAction> actions = planImportActions(
          remoteEvents: <RemoteEventSnapshot>[remote],
          localEventsByGoogleId: <String, Event>{'remote-1': local},
        );
        expect(actions.single, isA<DeleteLocalAction>());
        expect((actions.single as DeleteLocalAction).existingEventId, local.id);
      },
    );

    test(
      'a cancelled remote event with no local match -> skip (deletedWithNoLocalMatch)',
      () {
        final RemoteEventSnapshot remote = _remote(isCancelled: true);
        final List<SyncAction> actions = planImportActions(
          remoteEvents: <RemoteEventSnapshot>[remote],
          localEventsByGoogleId: const <String, Event>{},
        );
        expect(actions.single, isA<SkipAction>());
        expect(
          (actions.single as SkipAction).reason,
          SkipReason.deletedWithNoLocalMatch,
        );
      },
    );

    test(
      'a remote event carrying our own extendedProperties -> skip (ownExportEcho), never imported',
      () {
        final RemoteEventSnapshot ownExport = _remote(
          hebcalEventId: 'event-1',
          hebcalOccurrence: '5786-tevet-10',
        );
        final List<SyncAction> actions = planImportActions(
          remoteEvents: <RemoteEventSnapshot>[ownExport],
          localEventsByGoogleId: const <String, Event>{},
        );
        expect(actions.single, isA<SkipAction>());
        expect((actions.single as SkipAction).reason, SkipReason.ownExportEcho);
      },
    );
  });

  group('resolveConflict (post-412 re-resolution)', () {
    test('remote is newer than local -> updateLocal (remote wins)', () {
      final Event local = _event(updatedAt: DateTime(2026, 6, 1, 8));
      final RemoteEventSnapshot remote = _remote(
        updatedAt: DateTime(2026, 6, 1, 9),
      );
      final SyncAction action = resolveConflict(
        local: local,
        remote: remote,
        occurrenceDate: local.hebrewDate,
        occurrenceKey: occurrenceKeyFor(local.hebrewDate),
      );
      expect(action, isA<UpdateLocalAction>());
      expect((action as UpdateLocalAction).remote, remote);
    });

    test(
      'local is newer than (or equal to) remote -> updateRemote (local wins), retried with the fresh etag',
      () {
        final Event local = _event(updatedAt: DateTime(2026, 6, 1, 12));
        final RemoteEventSnapshot remote = _remote(
          etag: 'fresh-etag',
          updatedAt: DateTime(2026, 6, 1, 9),
        );
        final SyncAction action = resolveConflict(
          local: local,
          remote: remote,
          occurrenceDate: local.hebrewDate,
          occurrenceKey: occurrenceKeyFor(local.hebrewDate),
        );
        expect(action, isA<UpdateRemoteAction>());
        final UpdateRemoteAction update = action as UpdateRemoteAction;
        expect(update.etag, 'fresh-etag');
        expect(update.googleEventId, remote.googleEventId);
      },
    );

    test('remote was cancelled in the meantime -> deleteLocal', () {
      final Event local = _event();
      final RemoteEventSnapshot remote = _remote(isCancelled: true);
      final SyncAction action = resolveConflict(
        local: local,
        remote: remote,
        occurrenceDate: local.hebrewDate,
        occurrenceKey: occurrenceKeyFor(local.hebrewDate),
      );
      expect(action, isA<DeleteLocalAction>());
    });
  });
}
