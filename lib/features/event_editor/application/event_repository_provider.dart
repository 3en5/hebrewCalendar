import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/in_memory_event_repository.dart';
import '../../../domain/event/event_repository.dart';

/// The app-wide [EventRepository]. Defaults to an [InMemoryEventRepository]
/// until Firebase wiring lands in M2b; overridden in widget tests with a
/// fresh instance via `ProviderScope(overrides: [...])` so each test starts
/// from an empty, isolated store.
///
/// Deliberately NOT `autoDispose`: a repository is a data store, not
/// screen-scoped UI state (RULES.md §6.3 scopes *state management*, not
/// data) — it must outlive the screens that read from it, otherwise
/// navigating away from the calendar and back would silently drop every
/// in-memory event.
final Provider<EventRepository> eventRepositoryProvider =
    Provider<EventRepository>((Ref ref) => InMemoryEventRepository());
