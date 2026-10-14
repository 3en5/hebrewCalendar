import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/dimens.dart';
import '../../../domain/event/event.dart';
import '../../../domain/event/event_repository.dart';
import '../../../domain/event/recurrence_rule.dart';
import '../../../domain/event/significant_date.dart';
import '../../../domain/hebrew_date/hebrew_date.dart';
import '../../../domain/hebrew_date/hebrew_date_engine.dart';
import '../../../domain/hebrew_date/hebrew_numerals.dart';
import '../../../l10n/app_localizations.dart';
import '../../calendar/application/hebrew_date_engine_provider.dart';
import '../application/event_editor_controller.dart';
import '../application/event_repository_provider.dart';
import 'widgets/gregorian_date_dropdowns.dart';

/// Whether the original moment was before or after sunset; unknown counts
/// as before.
enum _Sunset { before, after, unknown }

/// M24 (owner decision 2026-10-14): turns a Gregorian birth, death or
/// wedding date into a yearly Hebrew-date event in one step: the kind, a
/// name, the original Gregorian day and the sunset question, with a live
/// preview of the Hebrew date and its next occurrence. Optionally also
/// creates the yearly Gregorian event.
class SignificantDateScreen extends ConsumerStatefulWidget {
  const SignificantDateScreen({super.key});

  @override
  ConsumerState<SignificantDateScreen> createState() =>
      _SignificantDateScreenState();
}

class _SignificantDateScreenState extends ConsumerState<SignificantDateScreen> {
  final TextEditingController _name = TextEditingController();
  SignificantDateKind _kind = SignificantDateKind.birthday;
  DateTime? _day;
  _Sunset _sunset = _Sunset.unknown;
  bool _alsoGregorian = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(_onNameChanged);
  }

  void _onNameChanged() => setState(() {});

  @override
  void dispose() {
    _name
      ..removeListener(_onNameChanged)
      ..dispose();
    super.dispose();
  }

  bool get _canSave => !_saving && _day != null && _name.text.trim().isNotEmpty;

  Future<void> _save() async {
    final DateTime? day = _day;
    if (!_canSave || day == null) {
      return;
    }
    setState(() => _saving = true);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String name = _name.text.trim();
    final ({String hebrew, String gregorian}) titles = _titles(
      l10n,
      _kind,
      name,
    );
    final List<Event> events = buildSignificantDateEvents(
      engine: ref.read(hebrewDateEngineProvider),
      kind: _kind,
      day: day,
      afterSunset: _sunset == _Sunset.after,
      hebrewTitle: titles.hebrew,
      gregorianTitle: _alsoGregorian ? titles.gregorian : null,
      ownerUid: kLocalOwnerUid,
      now: DateTime.now(),
    );
    final EventRepository repository = ref.read(eventRepositoryProvider);
    for (final Event event in events) {
      await repository.create(event);
    }
    if (!mounted) {
      return;
    }
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.significantSaved(titles.hebrew))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final HebrewDateEngine engine = ref.watch(hebrewDateEngineProvider);
    final DateTime? day = _day;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.significantTitle)),
      body: ListView(
        // An explicit padding drops the ListView's automatic bottom inset,
        // so the last row went under the phone's navigation bar (owner
        // report 2026-10-14): add it back.
        padding: EdgeInsets.all(
          spacingMd,
        ).copyWith(bottom: spacingMd + MediaQuery.paddingOf(context).bottom),
        children: <Widget>[
          // One row like the sunset choice below, so the four kinds never
          // wrap on a narrow phone (owner report 2026-10-14).
          SegmentedButton<SignificantDateKind>(
            showSelectedIcon: false,
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
                EdgeInsets.symmetric(horizontal: spacingXs),
              ),
            ),
            segments: <ButtonSegment<SignificantDateKind>>[
              for (final SignificantDateKind kind in SignificantDateKind.values)
                ButtonSegment<SignificantDateKind>(
                  value: kind,
                  label: FittedBox(
                    key: ValueKey<String>('significant-kind-${kind.name}'),
                    fit: BoxFit.scaleDown,
                    child: Text(_kindLabel(l10n, kind), maxLines: 1),
                  ),
                ),
            ],
            selected: <SignificantDateKind>{_kind},
            onSelectionChanged: (Set<SignificantDateKind> s) =>
                setState(() => _kind = s.first),
          ),
          SizedBox(height: spacingMd),
          TextField(
            key: const ValueKey<String>('significant-name'),
            controller: _name,
            maxLength: 80,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: l10n.significantNameLabel,
              hintText: _kind == SignificantDateKind.other
                  ? l10n.significantNameHintOther
                  : null,
              border: const OutlineInputBorder(),
            ),
          ),
          SizedBox(height: spacingSm),
          Text(l10n.significantDateLabel),
          SizedBox(height: spacingXs),
          GregorianDateDropdowns(
            onChanged: (DateTime? picked) => setState(() => _day = picked),
          ),
          SizedBox(height: spacingMd),
          Text(l10n.significantSunsetLabel),
          SizedBox(height: spacingXs),
          SegmentedButton<_Sunset>(
            showSelectedIcon: false,
            segments: <ButtonSegment<_Sunset>>[
              ButtonSegment<_Sunset>(
                value: _Sunset.before,
                label: Text(l10n.significantSunsetBefore),
              ),
              ButtonSegment<_Sunset>(
                value: _Sunset.after,
                label: Text(l10n.significantSunsetAfter),
              ),
              ButtonSegment<_Sunset>(
                value: _Sunset.unknown,
                label: Text(l10n.significantSunsetUnknown),
              ),
            ],
            selected: <_Sunset>{_sunset},
            onSelectionChanged: (Set<_Sunset> s) =>
                setState(() => _sunset = s.first),
          ),
          if (day != null) ...<Widget>[
            SizedBox(height: spacingMd),
            _Preview(
              engine: engine,
              kind: _kind,
              day: day,
              afterSunset: _sunset == _Sunset.after,
            ),
          ],
          SizedBox(height: spacingSm),
          CheckboxListTile(
            key: const ValueKey<String>('significant-also-gregorian'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _alsoGregorian,
            onChanged: (bool? v) => setState(() => _alsoGregorian = v ?? false),
            title: Text(l10n.significantAlsoGregorian),
          ),
          SizedBox(height: spacingMd),
          FilledButton(
            key: const ValueKey<String>('significant-save'),
            onPressed: _canSave ? _save : null,
            child: Text(l10n.significantSave),
          ),
        ],
      ),
    );
  }
}

/// "15 במרץ 1985 היה כ״ב באדר תשמ״ה. השנה יחול ב-..."
class _Preview extends StatelessWidget {
  const _Preview({
    required this.engine,
    required this.kind,
    required this.day,
    required this.afterSunset,
  });

  final HebrewDateEngine engine;
  final SignificantDateKind kind;
  final DateTime day;
  final bool afterSunset;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final DateFormat gregorian = DateFormat.yMMMMd('he');
    final HebrewDate anchor = significantHebrewDate(
      engine: engine,
      day: day,
      afterSunset: afterSunset,
    );
    final RecurrenceRule rule = significantDateRule(kind, anchor);
    final HebrewDate? next = nextSignificantOccurrence(
      engine: engine,
      anchor: anchor,
      rule: rule,
      today: engine.fromGregorian(DateTime.now()),
    );
    final String text = <String>[
      l10n.significantPreviewWas(gregorian.format(day), _hebrew(anchor)),
      if (next != null)
        l10n.significantPreviewNext(
          _hebrew(next),
          gregorian.format(engine.toGregorian(next)),
        ),
      if (rule.leapAdar == LeapAdarPolicy.adarI) l10n.significantAdarNote,
    ].join(' ');
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Card(
      key: const ValueKey<String>('significant-preview'),
      color: colors.secondaryContainer,
      elevation: 0,
      child: Padding(
        padding: EdgeInsets.all(spacingMd),
        child: Text(
          text,
          style: TextStyle(
            fontSize: bodyRem,
            color: colors.onSecondaryContainer,
          ),
        ),
      ),
    );
  }

  String _hebrew(HebrewDate d) =>
      '${hebrewDayNumeral(d.day)} ב${engine.monthName(d.month)} '
      '${hebrewYearNumeral(d.year)}';
}

String _kindLabel(AppLocalizations l10n, SignificantDateKind kind) =>
    switch (kind) {
      SignificantDateKind.birthday => l10n.significantKindBirthday,
      SignificantDateKind.yahrzeit => l10n.significantKindYahrzeit,
      SignificantDateKind.anniversary => l10n.significantKindAnniversary,
      SignificantDateKind.other => l10n.significantKindOther,
    };

({String hebrew, String gregorian}) _titles(
  AppLocalizations l10n,
  SignificantDateKind kind,
  String name,
) => switch (kind) {
  SignificantDateKind.birthday => (
    hebrew: l10n.significantTitleBirthdayHebrew(name),
    gregorian: l10n.significantTitleBirthdayGregorian(name),
  ),
  SignificantDateKind.yahrzeit => (
    hebrew: l10n.significantTitleYahrzeitHebrew(name),
    gregorian: l10n.significantTitleYahrzeitGregorian(name),
  ),
  SignificantDateKind.anniversary => (
    hebrew: l10n.significantTitleAnniversaryHebrew(name),
    gregorian: l10n.significantTitleAnniversaryGregorian(name),
  ),
  SignificantDateKind.other => (
    hebrew: l10n.significantTitleOtherHebrew(name),
    gregorian: l10n.significantTitleOtherGregorian(name),
  ),
};
