import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/dimens.dart';
import '../../../domain/zmanim/zmanim.dart';
import '../../../l10n/app_localizations.dart';
import '../application/zmanim_settings.dart';

String zmanLabel(AppLocalizations l10n, Zman zman) => switch (zman) {
  Zman.alos => l10n.zmanAlos,
  Zman.sunrise => l10n.zmanSunrise,
  Zman.sofZmanShmaMga => l10n.zmanShmaMga,
  Zman.sofZmanShmaGra => l10n.zmanShmaGra,
  Zman.sofZmanTfilaGra => l10n.zmanTfilaGra,
  Zman.chatzos => l10n.zmanChatzos,
  Zman.minchaGedola => l10n.zmanMinchaGedola,
  Zman.minchaKetana => l10n.zmanMinchaKetana,
  Zman.plagHamincha => l10n.zmanPlag,
  Zman.sunset => l10n.zmanSunset,
  Zman.tzais => l10n.zmanTzais,
};

final DateFormat _hm = DateFormat('HH:mm');

/// "17:47"-style time of a zman.
String formatZman(DateTime time) => _hm.format(time);

/// The day view's collapsible "times of day" panel (sketch 10), above the
/// hour grid; nothing when the times of day are turned off in settings.
class ZmanimPanel extends ConsumerWidget {
  const ZmanimPanel({required this.day, super.key});

  /// The civil (Gregorian) date shown.
  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ZmanimSettings settings = ref.watch(zmanimSettingsProvider);
    final ZmanimDay? zmanim = zmanimFor(settings, day);
    if (zmanim == null) {
      return const SizedBox.shrink();
    }
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final String place = settings.useDevicePosition
        ? l10n.zmanimDevicePosition
        : settings.city.name;
    Widget row(String label, DateTime time, {bool strong = false}) => Padding(
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: spacingMd,
        vertical: spacingXs / 2,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: strong
                  ? const TextStyle(fontWeight: FontWeight.w700)
                  : null,
            ),
          ),
          Text(
            formatZman(time),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: strong ? theme.colorScheme.primary : null,
            ),
          ),
        ],
      ),
    );
    return ExpansionTile(
      key: const PageStorageKey<String>('zmanim-panel'),
      dense: true,
      tilePadding: EdgeInsetsDirectional.symmetric(horizontal: spacingMd),
      title: Text(
        l10n.zmanimPanelTitle(place),
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      childrenPadding: EdgeInsetsDirectional.only(bottom: spacingSm),
      children: <Widget>[
        if (zmanim.candleLighting != null)
          row(l10n.zmanCandleLighting, zmanim.candleLighting!, strong: true),
        if (zmanim.havdalah != null)
          row(l10n.zmanHavdalah, zmanim.havdalah!, strong: true),
        for (final Zman zman in Zman.values)
          if (zmanim.times[zman] != null)
            row(zmanLabel(l10n, zman), zmanim.times[zman]!),
      ],
    );
  }
}
