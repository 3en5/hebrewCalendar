import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/firestore_event_repository.dart';
import '../../../data/in_memory_event_repository.dart';
import '../../../domain/auth/app_user.dart';
import '../../../domain/event/demo_events.dart';
import '../../../domain/event/event_repository.dart';
import '../../../domain/hebrew_date/hebrew_date.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/application/demo_mode_provider.dart';
import '../../calendar/application/hebrew_date_engine_provider.dart';

/// The app-wide [EventRepository]: a [FirestoreEventRepository] scoped to
/// the signed-in uid once authenticated; otherwise, in demo mode (task
/// brief #5), an [InMemoryEventRepository] pre-seeded with
/// `buildDemoEvents` so a Play Store reviewer sees real content
/// immediately without ever calling Firestore; otherwise a plain empty
/// [InMemoryEventRepository] (the app is behind the auth gate in that case
/// anyway — RULES.md §5.1 — so this last branch mainly protects providers
/// that get built before the gate settles). Overridden in widget tests with
/// a fresh [InMemoryEventRepository] via `ProviderScope(overrides: [...])`
/// so no test ever touches real Firestore (task brief M2b §5).
///
/// Deliberately NOT `autoDispose`: a repository is a data store, not
/// screen-scoped UI state (RULES.md §6.3 scopes *state management*, not
/// data) — it must outlive the screens that read from it, otherwise
/// navigating away from the calendar and back would silently drop every
/// in-memory event. It does, however, rebuild (a fresh repository instance)
/// whenever [currentUserProvider]/[demoModeProvider] changes, so a
/// sign-out/sign-in or demo-mode toggle never keeps serving the previous
/// repository.
final Provider<EventRepository> eventRepositoryProvider =
    Provider<EventRepository>((Ref ref) {
      final AppUser? user = ref.watch(currentUserProvider);
      if (user != null) {
        final FirestoreEventRepository repository = FirestoreEventRepository(
          ownerUid: user.uid,
        );
        ref.onDispose(repository.dispose);
        return repository;
      }
      final bool demoMode = ref.watch(demoModeProvider);
      if (!demoMode) {
        return InMemoryEventRepository();
      }
      final DateTime now = DateTime.now();
      final HebrewDate today = ref
          .watch(hebrewDateEngineProvider)
          .fromGregorian(now);
      final InMemoryEventRepository repository = InMemoryEventRepository();
      repository.seedForDemo(
        buildDemoEvents(
          today: today,
          now: now,
          engine: ref.watch(hebrewDateEngineProvider),
        ),
      );
      return repository;
    });
