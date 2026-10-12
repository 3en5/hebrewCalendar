/// The M5a Google Calendar sync orchestrator (ARCHITECTURE.md §5): runs one
/// full pull-then-push pass. Depends only on the abstract [EventRepository]
/// (domain), [GoogleCalendarApi] (this directory) and [SyncSettingsStore]
/// (domain) — so it is fully testable with `FakeGoogleCalendarApi` +
/// `InMemoryEventRepository` + an in-memory `SyncSettingsStore` fake, no
/// network or Firebase involved (task brief §5's `sync_engine` tests).
///
/// The actual pull/push logic lives in [SyncImportPass]/[SyncExportPass]
/// (RULES.md §2 — combined into one file, this would exceed 500 lines);
/// this file is just the glue: load settings, skip entirely if sync is
/// disabled, run pull, persist the sync token, run push (handing it the
/// pull's dedup-by-extendedProperties lookup), persist the last-synced
/// timestamp, and turn any thrown exception into a [SyncRunResult.failure]
/// rather than letting it propagate to a foreground trigger caller.
library;

import 'package:flutter/foundation.dart' show debugPrint;

import '../../domain/event/event_repository.dart';
import '../../domain/hebrew_date/hebrew_date_engine.dart';
import '../../domain/sync/sync_run_result.dart';
import '../../domain/sync/sync_settings_store.dart';
import 'google_calendar_api.dart';
import 'full_resync_flag.dart';
import 'sync_export_pass.dart';
import 'sync_import_pass.dart';

class SyncEngine {
  SyncEngine({
    required EventRepository repository,
    required GoogleCalendarApi api,
    required SyncSettingsStore settingsStore,
    required HebrewDateEngine engine,
    DateTime Function() now = DateTime.now,
    Duration exportWindow = kShortExportWindow,
    Duration longExportWindow = kLongExportWindow,
    FullResyncFlag? fullResync,
  }) : _settingsStore = settingsStore,
       _fullResync = fullResync,
       _importPass = SyncImportPass(
         api: api,
         repository: repository,
         engine: engine,
         now: now,
       ),
       _exportPass = SyncExportPass(
         api: api,
         repository: repository,
         engine: engine,
         now: now,
         exportWindow: exportWindow,
         longExportWindow: longExportWindow,
       ),
       _now = now;

  final SyncSettingsStore _settingsStore;
  final FullResyncFlag? _fullResync;
  final SyncImportPass _importPass;
  final SyncExportPass _exportPass;
  final DateTime Function() _now;

  /// M5b reliability polish: guards against two passes actually doing work
  /// concurrently *within this one engine instance/isolate* — e.g. the
  /// settings screen's manual "סנכרן עכשיו" button firing while the
  /// app-open trigger's pass is still in flight. This is an ordinary
  /// instance flag, not a cross-isolate lock: WorkManager runs
  /// `background_sync_bootstrap.dart`'s periodic task in a *separate*
  /// headless engine/isolate with its own fresh `SyncEngine` instance, so
  /// this flag cannot by itself prevent that background pass from
  /// overlapping a foreground one. Two other things make that acceptable:
  /// `runSync()` was already documented as safe to call
  /// repeatedly/concurrently (each call reloads settings/token fresh, so
  /// overlap just means redundant work, not corruption), and
  /// `existingWorkPolicy: keep` (`background_sync_scheduler.dart`) means
  /// WorkManager itself never runs two *background* passes concurrently.
  bool _inFlight = false;

  /// Runs one full sync pass. Safe to call repeatedly/concurrently-triggered
  /// (the settings screen's manual button, the app-open/post-edit
  /// triggers) — each call independently loads the latest persisted
  /// settings/token, so overlapping calls just do redundant work rather
  /// than corrupting state. A second call while one is already in flight
  /// (see [_inFlight]) is a no-op that returns immediately instead.
  Future<SyncRunResult> runSync() async {
    if (_inFlight) {
      return const SyncRunResult.concurrentSkip();
    }
    _inFlight = true;
    try {
      final SyncSettings settings;
      try {
        settings = await _settingsStore.load();
      } catch (error) {
        return SyncRunResult.failure(error.toString(), permanent: false);
      }
      if (!settings.enabled) {
        return const SyncRunResult.disabled();
      }
      try {
        final bool fullResync = await _fullResync?.isPending() ?? false;
        final SyncImportPassResult importResult = await _importPass.run(
          syncToken: fullResync ? null : settings.syncToken,
        );
        await _settingsStore.saveSyncToken(importResult.nextSyncToken);
        await _exportPass.run(ownExportsLookup: importResult.ownExportsLookup);
        await _settingsStore.saveLastSyncedAt(_now());
        await _settingsStore.saveLastError(null);
        if (fullResync) {
          await _fullResync?.markDone();
        }
        return const SyncRunResult.success();
      } catch (error) {
        final bool permanent = _isPermanentFailure(error);
        try {
          await _settingsStore.saveLastError(error.toString());
        } catch (saveError) {
          // Never let a failed bookkeeping write hide the real failure (or
          // escape as an exception that leaves the UI on "syncing").
          debugPrint('[sync] saving the last error failed: $saveError');
        }
        return SyncRunResult.failure(error.toString(), permanent: permanent);
      }
    } finally {
      _inFlight = false;
    }
  }

  /// M5b: classifies a caught sync failure as "permanent" — retrying
  /// immediately would fail identically, so `BackgroundSyncRunner` should
  /// not ask WorkManager to retry — vs transient (network hiccups, or
  /// anything unrecognized, which defaults to "not permanent": asking
  /// WorkManager to retry a genuinely permanent failure wastes a little
  /// battery, but treating a genuinely transient failure as permanent would
  /// silently stop background sync until the next foreground trigger).
  /// Permanent: an HTTP 401/403 from the Calendar API (grant revoked), or
  /// the `StateError`s `GoogleCalendarApiImpl._authHeaders` throws when
  /// there is no signed-in account or the `calendar.events` scope was never
  /// granted.
  bool _isPermanentFailure(Object error) {
    if (error is GoogleCalendarApiException) {
      return error.statusCode == 401 || error.statusCode == 403;
    }
    return error is StateError;
  }
}
