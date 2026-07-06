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

import '../../domain/event/event_repository.dart';
import '../../domain/hebrew_date/hebrew_date_engine.dart';
import '../../domain/sync/sync_run_result.dart';
import '../../domain/sync/sync_settings_store.dart';
import 'google_calendar_api.dart';
import 'sync_export_pass.dart';
import 'sync_import_pass.dart';

class SyncEngine {
  SyncEngine({
    required EventRepository repository,
    required GoogleCalendarApi api,
    required SyncSettingsStore settingsStore,
    required HebrewDateEngine engine,
    DateTime Function() now = DateTime.now,
    Duration exportWindow = const Duration(days: 730),
  }) : _settingsStore = settingsStore,
       _importPass = SyncImportPass(api: api, repository: repository, now: now),
       _exportPass = SyncExportPass(
         api: api,
         repository: repository,
         engine: engine,
         now: now,
         exportWindow: exportWindow,
       ),
       _now = now;

  final SyncSettingsStore _settingsStore;
  final SyncImportPass _importPass;
  final SyncExportPass _exportPass;
  final DateTime Function() _now;

  /// Runs one full sync pass. Safe to call repeatedly/concurrently-triggered
  /// (the settings screen's manual button, the app-open/post-edit
  /// triggers) — each call independently loads the latest persisted
  /// settings/token, so overlapping calls just do redundant work rather
  /// than corrupting state.
  Future<SyncRunResult> runSync() async {
    final SyncSettings settings = await _settingsStore.load();
    if (!settings.enabled) {
      return const SyncRunResult.disabled();
    }
    try {
      final SyncImportPassResult importResult = await _importPass.run(
        syncToken: settings.syncToken,
      );
      await _settingsStore.saveSyncToken(importResult.nextSyncToken);
      await _exportPass.run(ownExportsLookup: importResult.ownExportsLookup);
      await _settingsStore.saveLastSyncedAt(_now());
      return const SyncRunResult.success();
    } catch (error) {
      return SyncRunResult.failure(error.toString());
    }
  }
}
