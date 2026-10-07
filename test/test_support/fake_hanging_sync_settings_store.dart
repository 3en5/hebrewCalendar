import 'dart:async';

import 'package:hebrew_calendar/domain/sync/sync_settings_store.dart';

/// A [SyncSettingsStore] whose [load] never completes — simulates the
/// real-device failure mode behind report #2 ("endless spinner above the
/// backup section"): a Firestore read that hangs (no network, or a rules
/// mismatch that never resolves to either data or a fast error). Used to
/// prove `GoogleSyncTriggerService.start()`'s timeout (not the absence of a
/// bug) is what eventually surfaces a retryable error state instead of
/// leaving the settings screen's spinner running forever.
class FakeHangingSyncSettingsStore implements SyncSettingsStore {
  final Completer<SyncSettings> _neverCompletes = Completer<SyncSettings>();

  @override
  Future<SyncSettings> load() => _neverCompletes.future;

  @override
  Future<void> setEnabled(bool enabled) async {}

  @override
  Future<void> saveSyncToken(String? token) async {}

  @override
  Future<void> saveLastSyncedAt(DateTime at) async {}

  @override
  Future<void> saveLastError(String? message) async {}
}
