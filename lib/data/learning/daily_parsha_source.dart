import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/learning/daily_parsha.dart';

/// Where the daily files live (Firebase Hosting, `site/learning/parsha/`).
const String kDailyParshaBaseUrl =
    'https://hebrewcalendar-68363.web.app/learning/parsha';

const String _cachePrefix = 'daily_parsha_';

/// M26: like the daily halacha (`DailyHalachaSource`), the app carries none
/// of the Torah. It keeps only the coming week's portions, downloaded ahead
/// so a learner is covered offline for the week.
class DailyParshaSource {
  DailyParshaSource({http.Client? client, this.baseUrl = kDailyParshaBaseUrl})
    : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;

  /// [key]'s reading: from the cache, else downloaded (and cached). Null
  /// when it's neither cached nor reachable.
  Future<DailyParsha?> load(String key) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? cached = prefs.getString('$_cachePrefix$key');
    if (cached != null) {
      final DailyParsha? parsed = _parse(cached);
      if (parsed != null) {
        return parsed;
      }
    }
    final String? body = await _download(key);
    if (body == null) {
      return null;
    }
    final DailyParsha? parsed = _parse(body);
    if (parsed != null) {
      await prefs.setString('$_cachePrefix$key', body);
    }
    return parsed;
  }

  /// Downloads whichever of [keys] (the coming week) isn't cached yet and
  /// drops cached days no longer in [keys], so the cache stays a week.
  Future<void> keepOnly(Iterable<String> keys) async {
    final Set<String> wanted = keys.toSet();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    for (final String stored in prefs.getKeys()) {
      if (stored.startsWith(_cachePrefix) &&
          !wanted.contains(stored.substring(_cachePrefix.length))) {
        await prefs.remove(stored);
      }
    }
    for (final String key in wanted) {
      if (!prefs.containsKey('$_cachePrefix$key')) {
        await load(key);
      }
    }
  }

  Future<String?> _download(String key) async {
    try {
      final http.Response response = await _client
          .get(Uri.parse('$baseUrl/$key.json'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        return null;
      }
      return utf8.decode(response.bodyBytes);
    } catch (_) {
      return null;
    }
  }

  static DailyParsha? _parse(String body) {
    try {
      return DailyParsha.fromJson(jsonDecode(body));
    } catch (_) {
      return null;
    }
  }

  void dispose() => _client.close();
}
