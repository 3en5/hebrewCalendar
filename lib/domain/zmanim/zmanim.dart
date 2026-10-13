import 'package:kosher_dart/kosher_dart.dart' as kosher;

import 'zmanim_location.dart';

/// The times of day shown in the app (M21, owner-approved sketches 10-12).
enum Zman {
  alos,
  sunrise,
  sofZmanShmaMga,
  sofZmanShmaGra,
  sofZmanTfilaGra,
  chatzos,
  minchaGedola,
  minchaKetana,
  plagHamincha,
  sunset,
  tzais,
}

/// How the end of Shabbat is computed.
enum HavdalahMethod {
  /// Tzeit hakochavim, the sun 8.5° below the horizon (common in Israel).
  degrees8Point5,

  /// 72 minutes after sunset (Rabbeinu Tam).
  minutes72,
}

/// The times of one civil day at one place, in the device's local time.
class ZmanimDay {
  const ZmanimDay({required this.times, this.candleLighting, this.havdalah});

  /// Each [Zman] that could be computed (none near the poles' white nights).
  final Map<Zman, DateTime> times;

  /// Friday only: candle lighting.
  final DateTime? candleLighting;

  /// Saturday only: the end of Shabbat.
  final DateTime? havdalah;
}

/// Computes the times of day with `kosher_dart` (with
/// `hebrew_date_engine.dart` and `jewish_day_info.dart`, the only files
/// allowed to import it). Pure and synchronous; no network.
///
/// [day] is the civil (Gregorian) date; [candleLightingMinutes] is how many
/// minutes before sunset candles are lit.
ZmanimDay computeZmanim({
  required DateTime day,
  required ZmanimLocation location,
  required int candleLightingMinutes,
  HavdalahMethod havdalah = HavdalahMethod.degrees8Point5,
}) {
  final DateTime noon = DateTime(day.year, day.month, day.day, 12);
  final kosher.GeoLocation geo = kosher.GeoLocation.setLocation(
    location.name,
    location.latitude,
    location.longitude,
    noon,
    location.elevation,
  );
  final kosher.ComplexZmanimCalendar calendar =
      kosher.ComplexZmanimCalendar.intGeoLocation(geo)
        ..setCandleLightingOffset(candleLightingMinutes.toDouble());
  final Map<Zman, DateTime?> raw = <Zman, DateTime?>{
    Zman.alos: calendar.getAlosHashachar(),
    Zman.sunrise: calendar.getSunrise(),
    Zman.sofZmanShmaMga: calendar.getSofZmanShmaMGA(),
    Zman.sofZmanShmaGra: calendar.getSofZmanShmaGRA(),
    Zman.sofZmanTfilaGra: calendar.getSofZmanTfilaGRA(),
    Zman.chatzos: calendar.getChatzos(),
    Zman.minchaGedola: calendar.getMinchaGedola(),
    Zman.minchaKetana: calendar.getMinchaKetana(),
    Zman.plagHamincha: calendar.getPlagHamincha(),
    Zman.sunset: calendar.getSunset(),
    Zman.tzais: calendar.getTzais(),
  };
  final Map<Zman, DateTime> times = <Zman, DateTime>{
    for (final MapEntry<Zman, DateTime?> entry in raw.entries)
      if (entry.value != null) entry.key: entry.value!,
  };
  return ZmanimDay(
    times: times,
    candleLighting: day.weekday == DateTime.friday
        ? calendar.getCandleLighting()
        : null,
    havdalah: day.weekday == DateTime.saturday
        ? switch (havdalah) {
            HavdalahMethod.degrees8Point5 => calendar.getTzais(),
            HavdalahMethod.minutes72 => calendar.getTzais72(),
          }
        : null,
  );
}
