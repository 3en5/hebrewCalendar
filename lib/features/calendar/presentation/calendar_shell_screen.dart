import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/dimens.dart';
import '../../../domain/hebrew_date/hebrew_date.dart';
import '../../../domain/hebrew_date/hebrew_date_engine.dart';
import '../../../domain/hebrew_date/hebrew_numerals.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/application/demo_mode_provider.dart';
import '../../event_editor/application/event_editor_controller.dart';
import '../../event_editor/presentation/event_editor_screen.dart';
import '../../notifications/application/reminder_providers.dart';
import '../../../domain/sync/sync_run_result.dart';
import '../../../domain/sync/sync_state.dart';
import '../../settings/application/google_sync_providers.dart';
import '../../settings/application/google_sync_settings_state.dart';
import '../../settings/application/google_sync_trigger_service.dart';
import '../../settings/presentation/settings_screen.dart';
import '../application/calendar_view_provider.dart';
import '../application/hebrew_date_engine_provider.dart';
import 'agenda_view_screen.dart';
import 'day_view_screen.dart';
import 'event_search_screen.dart';
import 'month_view_body.dart';
import 'week_view_screen.dart';
import 'widgets/go_to_date_sheet.dart';

enum _OverflowAction { signOut }

/// The app's single home screen (M3b — replaces the old month-only
/// `MonthViewScreen`): a shared app bar (title, view switcher, "today"
/// button, overflow menu) and FAB, with the body switching between
/// [MonthViewBody]/[WeekViewScreen]/[DayViewScreen]/[AgendaViewScreen]
/// per [calendarViewProvider]'s [CalendarViewType].
///
/// Deliberately has no explicit previous/next chevrons: paging is by swipe
/// in the month/week/day bodies (matching how Google Calendar's own mobile
/// app works — it has no chevrons either, just swipe + a "today" action +
/// a view switcher), which also sidesteps needing the shell to reach into
/// whichever body is currently mounted to trigger its `PageController`.
class CalendarShellScreen extends ConsumerWidget {
  const CalendarShellScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CalendarViewState state = ref.watch(calendarViewProvider);
    final HebrewDateEngine engine = ref.watch(hebrewDateEngineProvider);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool demoMode = ref.watch(demoModeProvider);

    // Task brief #5 (demo mode): none of the background services below may
    // start while in demo mode — no notification permission prompt, no
    // Google/Firestore sync trigger at all, matching "no Firestore/Google
    // calls at all in demo mode". Skipping `ref.watch`/`ref.listen`
    // entirely (rather than starting and immediately no-op-ing) means the
    // underlying `autoDispose` providers are never even built.
    if (!demoMode) {
      // M4: keeps `ReminderSyncService` alive (subscribed + scheduling) for
      // as long as this screen — the only one shown while signed in — is on
      // screen; `autoDispose` tears it down (subscription + every scheduled
      // notification cancelled) once it isn't, i.e. on sign-out.
      ref.watch(reminderSyncServiceProvider);
      // M5a: same lifecycle for the Google Calendar sync trigger service —
      // keeps its app-open/post-edit-debounce triggers alive whenever the
      // calendar shell is on screen (not just while the settings screen
      // itself is open), torn down on sign-out.
      ref.watch(googleSyncTriggerServiceProvider);
      // Requests notification permission once ever (persisted flag); shows a
      // Hebrew rationale snackbar only if it was denied.
      ref.listen<AsyncValue<bool>>(reminderPermissionProvider, (
        AsyncValue<bool>? previous,
        AsyncValue<bool> next,
      ) {
        next.whenData((bool granted) {
          if (!granted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.notificationsPermissionDeniedMessage),
              ),
            );
          }
        });
      });
    }

    final String? gregorianSubtitle = _gregorianSubtitle(state, engine);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(_title(state, engine, l10n)),
            // Device feedback: the day cells show the secondary Gregorian
            // day number, but the app bar showed no Gregorian context at
            // all — add the Gregorian month/year range the displayed Hebrew
            // month spans (e.g. "יוני–יולי 2026").
            if (gregorianSubtitle != null)
              Text(
                gregorianSubtitle,
                style: TextStyle(
                  fontSize: captionRem,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: l10n.searchTooltip,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const EventSearchScreen(),
              ),
            ),
          ),
          // M12: today, or jump to any Hebrew/Gregorian date.
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: l10n.goToDateTooltip,
            onPressed: () => openGoToDateSheet(context, ref),
          ),
          _ViewSwitcher(current: state.viewType, l10n: l10n),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: l10n.settingsTooltip,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
          PopupMenuButton<_OverflowAction>(
            onSelected: (_OverflowAction action) {
              switch (action) {
                case _OverflowAction.signOut:
                  if (demoMode) {
                    // Task brief #5: leaving demo mode just clears the flag
                    // — there is no real session to sign out of, and the
                    // auth gate immediately swaps back to `SignInScreen`.
                    ref.read(demoModeProvider.notifier).disable();
                  } else {
                    unawaited(_confirmSignOut(context, ref, l10n));
                  }
              }
            },
            itemBuilder: (BuildContext context) =>
                <PopupMenuEntry<_OverflowAction>>[
                  PopupMenuItem<_OverflowAction>(
                    value: _OverflowAction.signOut,
                    child: Text(
                      demoMode
                          ? l10n.signInReturnToSignInAction
                          : l10n.signOutAction,
                    ),
                  ),
                ],
          ),
        ],
      ),
      // Device feedback: pulling any view down runs a Google sync. Only
      // vertical scrolls count (the views page horizontally), from any
      // depth, so the pull works on the month page and its agenda alike.
      body: RefreshIndicator(
        notificationPredicate: (ScrollNotification notification) =>
            notification.metrics.axis == Axis.vertical,
        onRefresh: () => _pullToSync(context, ref, l10n, demoMode: demoMode),
        child: switch (state.viewType) {
          CalendarViewType.month => const MonthViewBody(),
          CalendarViewType.week => const WeekViewScreen(),
          CalendarViewType.day => const DayViewScreen(),
          CalendarViewType.agenda => const AgendaViewScreen(),
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditorForNewEvent(context, state),
        tooltip: l10n.addEventTooltip,
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Pull-to-refresh: runs a Google sync and reports the outcome in a
  /// snackbar (done / sync is off / the real error).
  Future<void> _pullToSync(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n, {
    required bool demoMode,
  }) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    void show(String message, {SnackBarAction? action}) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message), action: action));
    }

    if (demoMode) {
      show(l10n.settingsGoogleSyncDisabledDemoMessage);
      return;
    }
    final GoogleSyncTriggerService service = ref.read(
      googleSyncTriggerServiceProvider,
    );
    if (!service.state.enabled) {
      show(
        l10n.calendarPullSyncDisabledMessage,
        action: SnackBarAction(
          label: l10n.settingsScreenTitle,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
          ),
        ),
      );
      return;
    }
    final SyncRunResult? result = await service.syncNow();
    final GoogleSyncSettingsState after = service.state;
    if (result != null && result.wasConcurrentSkip) {
      show(l10n.calendarPullSyncAlreadyRunningMessage);
    } else if (after.status == SyncStatus.error) {
      show(
        l10n.settingsGoogleSyncActionFailedMessage(after.errorMessage ?? ''),
      );
    } else {
      show(l10n.calendarPullSyncDoneMessage);
    }
  }

  String _title(
    CalendarViewState state,
    HebrewDateEngine engine,
    AppLocalizations l10n,
  ) {
    if (state.viewType == CalendarViewType.agenda) {
      return l10n.calendarViewAgenda;
    }
    // Month/week/day all show the focused date's Hebrew month/year in the
    // app bar, matching Google Calendar's own top bar.
    return '${engine.monthName(state.focusedDate.month)} '
        '${hebrewYearNumeral(state.focusedDate.year)}';
  }

  /// The Gregorian month/year range the focused Hebrew month spans, in the
  /// app locale (e.g. "יוני 2026", "יוני–יולי 2026", "דצמבר 2026–ינואר 2027").
  /// Null for the agenda view, whose title is not month-scoped.
  String? _gregorianSubtitle(CalendarViewState state, HebrewDateEngine engine) {
    if (state.viewType == CalendarViewType.agenda) {
      return null;
    }
    final HebrewDate focused = state.focusedDate;
    final DateTime first = engine.toGregorian(
      HebrewDate(year: focused.year, month: focused.month, day: 1),
    );
    final DateTime last = engine.toGregorian(
      HebrewDate(
        year: focused.year,
        month: focused.month,
        day: engine.daysInMonth(focused.year, focused.month),
      ),
    );
    final DateFormat monthFormat = DateFormat.MMMM('he');
    if (first.year == last.year) {
      return first.month == last.month
          ? '${monthFormat.format(first)} ${first.year}'
          : '${monthFormat.format(first)}–${monthFormat.format(last)} '
                '${first.year}';
    }
    return '${monthFormat.format(first)} ${first.year}–'
        '${monthFormat.format(last)} ${last.year}';
  }

  Future<void> _confirmSignOut(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(l10n.signOutConfirmTitle),
        content: Text(l10n.signOutConfirmMessage),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.signOutAction),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(authRepositoryProvider).signOut();
    }
  }

  /// The FAB always creates a new event on [CalendarViewState.focusedDate]
  /// (task brief M3b §4) — whichever specific day that is depends on the
  /// currently-visible body (month view preserves day-of-month across
  /// swipes; week view focuses that week's Sunday; day/agenda focus an
  /// exact day), so no per-view special-casing is needed here.
  void _openEditorForNewEvent(BuildContext context, CalendarViewState state) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EventEditorScreen(
          args: EventEditorArgs(initialDate: state.focusedDate, existing: null),
        ),
      ),
    );
  }
}

class _ViewSwitcher extends ConsumerWidget {
  const _ViewSwitcher({required this.current, required this.l10n});

  final CalendarViewType current;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<CalendarViewType>(
      tooltip: l10n.calendarViewSwitcherTooltip,
      onSelected: (CalendarViewType type) =>
          ref.read(calendarViewProvider.notifier).setViewType(type),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<CalendarViewType>>[
        for (final CalendarViewType type in CalendarViewType.values)
          PopupMenuItem<CalendarViewType>(
            value: type,
            child: Text(_label(type)),
          ),
      ],
      child: Padding(
        padding: EdgeInsetsDirectional.symmetric(horizontal: spacingSm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(_label(current)),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  String _label(CalendarViewType type) => switch (type) {
    CalendarViewType.month => l10n.calendarViewMonth,
    CalendarViewType.week => l10n.calendarViewWeek,
    CalendarViewType.day => l10n.calendarViewDay,
    CalendarViewType.agenda => l10n.calendarViewAgenda,
  };
}
