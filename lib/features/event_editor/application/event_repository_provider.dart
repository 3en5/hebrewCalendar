import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/firestore_event_repository.dart';
import '../../../data/in_memory_event_repository.dart';
import '../../../domain/auth/app_user.dart';
import '../../../domain/event/event_repository.dart';
import '../../auth/application/auth_providers.dart';

/// The app-wide [EventRepository]: a [FirestoreEventRepository] scoped to
/// the signed-in uid once authenticated, otherwise an
/// [InMemoryEventRepository] (the app is behind the auth gate in that case
/// anyway — RULES.md §5.1 — so this branch mainly protects providers that
/// get built before the gate settles). Overridden in widget tests with a
/// fresh [InMemoryEventRepository] via `ProviderScope(overrides: [...])` so
/// no test ever touches real Firestore (task brief M2b §5).
///
/// Deliberately NOT `autoDispose`: a repository is a data store, not
/// screen-scoped UI state (RULES.md §6.3 scopes *state management*, not
/// data) — it must outlive the screens that read from it, otherwise
/// navigating away from the calendar and back would silently drop every
/// in-memory event. It does, however, rebuild (a fresh repository instance)
/// whenever [currentUserProvider] changes, so a sign-out/sign-in never keeps
/// serving the previous user's Firestore-scoped repository.
final Provider<EventRepository> eventRepositoryProvider =
    Provider<EventRepository>((Ref ref) {
      final AppUser? user = ref.watch(currentUserProvider);
      if (user == null) {
        return InMemoryEventRepository();
      }
      return FirestoreEventRepository(ownerUid: user.uid);
    });
