/// Per-event and overall Google Calendar sync state (ARCHITECTURE.md §4/§5,
/// M5a). Pure value types — no Flutter/Firebase/googleapis — so
/// `sync_planner.dart` can decide actions from them without any I/O.
library;

/// The Google Calendar sync bookkeeping for a single exported "thing":
/// either the one remote counterpart of a non-recurring [Event]
/// (`Event.googleSync`), or one entry of a recurring [Event]'s materialized
/// instances (`Event.googleInstanceSync`, keyed by
/// `occurrence_key.dart`'s `occurrenceKeyFor`).
///
/// [dirty] means "a local edit happened since this was last pushed to
/// Google" — set by the repository on every `create`/`update` (RULES.md §6:
/// kept in the repository layer, not the UI) and cleared by the sync engine
/// once the push succeeds.
class GoogleSyncState {
  const GoogleSyncState({
    this.googleEventId,
    this.etag,
    this.lastSyncedAt,
    this.dirty = false,
  });

  /// The Google Calendar event id this local thing maps to, or null if it
  /// has never been exported (and dedup-by-extendedProperties hasn't
  /// discovered a pre-existing remote copy either).
  final String? googleEventId;

  /// The remote event's ETag as of [lastSyncedAt], used as an `If-Match`
  /// precondition on updates (conflict detection — ARCHITECTURE.md §5).
  final String? etag;

  /// When this was last successfully synced (pushed or pulled).
  final DateTime? lastSyncedAt;

  /// Whether a local edit is pending export.
  final bool dirty;

  GoogleSyncState copyWith({
    String? googleEventId,
    bool clearGoogleEventId = false,
    String? etag,
    bool clearEtag = false,
    DateTime? lastSyncedAt,
    bool? dirty,
  }) => GoogleSyncState(
    googleEventId: clearGoogleEventId
        ? null
        : (googleEventId ?? this.googleEventId),
    etag: clearEtag ? null : (etag ?? this.etag),
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    dirty: dirty ?? this.dirty,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GoogleSyncState &&
          other.googleEventId == googleEventId &&
          other.etag == etag &&
          other.lastSyncedAt == lastSyncedAt &&
          other.dirty == dirty);

  @override
  int get hashCode => Object.hash(googleEventId, etag, lastSyncedAt, dirty);

  @override
  String toString() =>
      'GoogleSyncState(googleEventId: $googleEventId, etag: $etag, '
      'lastSyncedAt: $lastSyncedAt, dirty: $dirty)';
}

/// The overall state of the Google Calendar sync feature, surfaced by the
/// settings screen (M5a task brief §3).
enum SyncStatus {
  /// Sync is disabled, or idle after a successful run (or has never run).
  idle,

  /// A sync pass is currently in progress.
  syncing,

  /// The most recent sync pass failed; see the accompanying error message.
  error,
}
