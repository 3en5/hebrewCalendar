import 'package:flutter/material.dart';

import '../../../core/theme/dimens.dart';
import '../../../domain/zmanim/zmanim.dart';
import '../../../l10n/app_localizations.dart';
import '../application/zmanim_settings.dart';
import 'zmanim_panel.dart' show formatZman;

/// A Shabbat time shown in the month view (sketch 11): candle lighting on
/// Friday, the end of Shabbat on Saturday.
class ShabbatTime {
  const ShabbatTime({required this.isCandleLighting, required this.time});

  final bool isCandleLighting;
  final DateTime time;

  IconData get icon => isCandleLighting
      ? Icons.local_fire_department_outlined
      : Icons.nights_stay_outlined;

  String label(AppLocalizations l10n) =>
      isCandleLighting ? l10n.zmanCandleLighting : l10n.zmanHavdalah;
}

/// The Shabbat time of the civil date [day], or null on other weekdays or
/// when the times of day are off.
ShabbatTime? shabbatTimeFor(ZmanimSettings settings, DateTime day) {
  if (!settings.enabled ||
      (day.weekday != DateTime.friday && day.weekday != DateTime.saturday)) {
    return null;
  }
  final ZmanimDay? zmanim = zmanimFor(settings, day);
  final DateTime? candles = zmanim?.candleLighting;
  if (candles != null) {
    return ShabbatTime(isCandleLighting: true, time: candles);
  }
  final DateTime? havdalah = zmanim?.havdalah;
  return havdalah == null
      ? null
      : ShabbatTime(isCandleLighting: false, time: havdalah);
}

/// The tiny "icon 17:47" line in a month cell.
class ShabbatTimeLine extends StatelessWidget {
  const ShabbatTimeLine({required this.shabbatTime, super.key});

  final ShabbatTime shabbatTime;

  @override
  Widget build(BuildContext context) {
    final Color color = Theme.of(context).colorScheme.tertiary;
    final double size = rem(0.5625);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(shabbatTime.icon, size: size * 1.2, color: color),
        SizedBox(width: spacingXs / 4),
        Text(
          formatZman(shabbatTime.time),
          style: TextStyle(
            fontSize: size,
            height: 1.2,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
