/// A place to compute the times of day for (M21): a city from
/// [kZmanimCities], or the phone's own position.
class ZmanimLocation {
  const ZmanimLocation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.elevation = 0,
    this.candleLightingMinutes = 30,
  });

  /// Stable id for preferences ("jerusalem"); "device" for the phone's
  /// position.
  final String id;

  /// Hebrew display name.
  final String name;
  final double latitude;
  final double longitude;

  /// Meters above sea level.
  final double elevation;

  /// The city's custom: how many minutes before sunset candles are lit
  /// (Jerusalem 40, Haifa 30, most places 20-30). The user can override it.
  final int candleLightingMinutes;

  ZmanimLocation withPosition(double latitude, double longitude) =>
      ZmanimLocation(
        id: id,
        name: name,
        latitude: latitude,
        longitude: longitude,
        elevation: elevation,
        candleLightingMinutes: candleLightingMinutes,
      );
}

/// Id of the "use the phone's position" choice.
const String kDeviceZmanimLocationId = 'device';

/// Cities offered in settings, at each city center. All at sea level, as
/// the common Israeli calendars and Hebcal compute them (owner decision
/// 2026-10-15: Jerusalem's 754 m and Ma'ale Adumim's 500 m moved sunset
/// and candle lighting away from the printed times). Candle lighting:
/// Jerusalem, Ma'ale Adumim and Petah Tikva 40, by local custom; Haifa,
/// Zichron Ya'akov, Tiberias and Safed 30 (Hebcal, Kipa); Bnei Brak, Modi'in Illit
/// and Beit Shemesh 30 as their communities light early (owner decision
/// 2026-10-20, as Modi'in and Ariel moved to the common 20).
const List<ZmanimLocation> kZmanimCities = <ZmanimLocation>[
  ZmanimLocation(
    id: 'jerusalem',
    name: 'ירושלים',
    latitude: 31.7780,
    longitude: 35.2354,
    candleLightingMinutes: 40,
  ),
  ZmanimLocation(
    id: 'tel_aviv',
    name: 'תל אביב-יפו',
    latitude: 32.0853,
    longitude: 34.7818,
    candleLightingMinutes: 20,
  ),
  ZmanimLocation(
    id: 'haifa',
    name: 'חיפה',
    latitude: 32.7940,
    longitude: 34.9896,
    candleLightingMinutes: 30,
  ),
  ZmanimLocation(
    id: 'beer_sheva',
    name: 'באר שבע',
    latitude: 31.2520,
    longitude: 34.7915,
    candleLightingMinutes: 20,
  ),
  ZmanimLocation(
    id: 'modiin',
    name: 'מודיעין',
    latitude: 31.8980,
    longitude: 35.0104,
    candleLightingMinutes: 20,
  ),
  ZmanimLocation(
    id: 'modiin_illit',
    name: 'מודיעין עילית',
    latitude: 31.9330,
    longitude: 35.0420,
    candleLightingMinutes: 30,
  ),
  ZmanimLocation(
    id: 'bnei_brak',
    name: 'בני ברק',
    latitude: 32.0840,
    longitude: 34.8338,
    candleLightingMinutes: 30,
  ),
  ZmanimLocation(
    id: 'petah_tikva',
    name: 'פתח תקווה',
    latitude: 32.0871,
    longitude: 34.8875,
    candleLightingMinutes: 40,
  ),
  ZmanimLocation(
    id: 'rishon',
    name: 'ראשון לציון',
    latitude: 31.9730,
    longitude: 34.7925,
    candleLightingMinutes: 20,
  ),
  ZmanimLocation(
    id: 'holon',
    name: 'חולון',
    latitude: 32.0158,
    longitude: 34.7874,
    candleLightingMinutes: 20,
  ),
  ZmanimLocation(
    id: 'ramat_gan',
    name: 'רמת גן',
    latitude: 32.0684,
    longitude: 34.8248,
    candleLightingMinutes: 20,
  ),
  ZmanimLocation(
    id: 'netanya',
    name: 'נתניה',
    latitude: 32.3215,
    longitude: 34.8532,
    candleLightingMinutes: 20,
  ),
  ZmanimLocation(
    id: 'herzliya',
    name: 'הרצליה',
    latitude: 32.1663,
    longitude: 34.8436,
    candleLightingMinutes: 20,
  ),
  ZmanimLocation(
    id: 'kfar_saba',
    name: 'כפר סבא',
    latitude: 32.1750,
    longitude: 34.9070,
    candleLightingMinutes: 20,
  ),
  ZmanimLocation(
    id: 'raanana',
    name: 'רעננה',
    latitude: 32.1848,
    longitude: 34.8713,
    candleLightingMinutes: 20,
  ),
  ZmanimLocation(
    id: 'rehovot',
    name: 'רחובות',
    latitude: 31.8928,
    longitude: 34.8113,
    candleLightingMinutes: 20,
  ),
  ZmanimLocation(
    id: 'ashdod',
    name: 'אשדוד',
    latitude: 31.8040,
    longitude: 34.6553,
    candleLightingMinutes: 20,
  ),
  ZmanimLocation(
    id: 'ashkelon',
    name: 'אשקלון',
    latitude: 31.6688,
    longitude: 34.5743,
    candleLightingMinutes: 20,
  ),
  ZmanimLocation(
    id: 'beit_shemesh',
    name: 'בית שמש',
    latitude: 31.7470,
    longitude: 34.9881,
    candleLightingMinutes: 30,
  ),
  ZmanimLocation(
    id: 'maale_adumim',
    name: 'מעלה אדומים',
    latitude: 31.7770,
    longitude: 35.2980,
    candleLightingMinutes: 40,
  ),
  ZmanimLocation(
    id: 'ariel',
    name: 'אריאל',
    latitude: 32.1060,
    longitude: 35.1870,
    candleLightingMinutes: 20,
  ),
  ZmanimLocation(
    id: 'hadera',
    name: 'חדרה',
    latitude: 32.4340,
    longitude: 34.9196,
    candleLightingMinutes: 20,
  ),
  ZmanimLocation(
    id: 'zichron_yaakov',
    name: 'זכרון יעקב',
    latitude: 32.5707,
    longitude: 34.9532,
    candleLightingMinutes: 30,
  ),
  ZmanimLocation(
    id: 'afula',
    name: 'עפולה',
    latitude: 32.6080,
    longitude: 35.2890,
    candleLightingMinutes: 20,
  ),
  ZmanimLocation(
    id: 'tiberias',
    name: 'טבריה',
    latitude: 32.7959,
    longitude: 35.5310,
    candleLightingMinutes: 30,
  ),
  ZmanimLocation(
    id: 'safed',
    name: 'צפת',
    latitude: 32.9646,
    longitude: 35.4960,
    candleLightingMinutes: 30,
  ),
  ZmanimLocation(
    id: 'nahariya',
    name: 'נהריה',
    latitude: 33.0060,
    longitude: 35.0940,
    candleLightingMinutes: 20,
  ),
  ZmanimLocation(
    id: 'eilat',
    name: 'אילת',
    latitude: 29.5577,
    longitude: 34.9519,
    candleLightingMinutes: 20,
  ),
  ZmanimLocation(
    id: 'new_york',
    name: 'ניו יורק',
    latitude: 40.7128,
    longitude: -74.0060,
    candleLightingMinutes: 18,
  ),
  ZmanimLocation(
    id: 'los_angeles',
    name: 'לוס אנג׳לס',
    latitude: 34.0522,
    longitude: -118.2437,
    candleLightingMinutes: 18,
  ),
  ZmanimLocation(
    id: 'london',
    name: 'לונדון',
    latitude: 51.5072,
    longitude: -0.1276,
    candleLightingMinutes: 18,
  ),
  ZmanimLocation(
    id: 'paris',
    name: 'פריז',
    latitude: 48.8566,
    longitude: 2.3522,
    candleLightingMinutes: 18,
  ),
  ZmanimLocation(
    id: 'antwerp',
    name: 'אנטוורפן',
    latitude: 51.2194,
    longitude: 4.4025,
    candleLightingMinutes: 18,
  ),
];

/// The default city: Jerusalem.
const ZmanimLocation kDefaultZmanimCity = ZmanimLocation(
  id: 'jerusalem',
  name: 'ירושלים',
  latitude: 31.7780,
  longitude: 35.2354,
  candleLightingMinutes: 40,
);

ZmanimLocation zmanimCityById(String? id) {
  for (final ZmanimLocation city in kZmanimCities) {
    if (city.id == id) {
      return city;
    }
  }
  return kDefaultZmanimCity;
}
