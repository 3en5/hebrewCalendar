// Unit tests for GoogleSyncState (M5a): equality and copyWith, including
// the clearGoogleEventId/clearEtag flags.

import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/domain/sync/sync_state.dart';

void main() {
  group('GoogleSyncState equality', () {
    test('two default states are equal', () {
      expect(const GoogleSyncState(), const GoogleSyncState());
    });

    test('differing dirty flag makes states unequal', () {
      expect(
        const GoogleSyncState(dirty: true),
        isNot(const GoogleSyncState(dirty: false)),
      );
    });

    test('differing googleEventId makes states unequal', () {
      expect(
        const GoogleSyncState(googleEventId: 'a'),
        isNot(const GoogleSyncState(googleEventId: 'b')),
      );
    });
  });

  group('GoogleSyncState copyWith', () {
    test('leaves fields unchanged when no argument given', () {
      const GoogleSyncState original = GoogleSyncState(
        googleEventId: 'g-1',
        etag: 'etag-1',
        dirty: true,
      );
      expect(original.copyWith(), original);
    });

    test('overwrites dirty only', () {
      const GoogleSyncState original = GoogleSyncState(dirty: true);
      final GoogleSyncState updated = original.copyWith(dirty: false);
      expect(updated.dirty, isFalse);
      expect(updated.googleEventId, original.googleEventId);
    });

    test(
      'clearGoogleEventId nulls it out even though passing null would be ignored',
      () {
        const GoogleSyncState original = GoogleSyncState(googleEventId: 'g-1');
        final GoogleSyncState cleared = original.copyWith(
          clearGoogleEventId: true,
        );
        expect(cleared.googleEventId, isNull);
      },
    );

    test(
      'clearEtag nulls it out even though passing null would be ignored',
      () {
        const GoogleSyncState original = GoogleSyncState(etag: 'etag-1');
        final GoogleSyncState cleared = original.copyWith(clearEtag: true);
        expect(cleared.etag, isNull);
      },
    );
  });
}
