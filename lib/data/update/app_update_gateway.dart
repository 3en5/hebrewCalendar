import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:http/http.dart' as http;
import 'package:in_app_update/in_app_update.dart';

/// What Google Play says about a newer version.
class UpdateCheck {
  const UpdateCheck({
    required this.availableCode,
    required this.flexibleAllowed,
    required this.immediateAllowed,
  });

  /// The newer version's code, or null when there is none.
  final int? availableCode;
  final bool flexibleAllowed;
  final bool immediateAllowed;
}

/// Google Play In-App Updates, behind an interface so tests and screenshots
/// can fake it. Works only on Android, for an app installed from Play
/// (testing tracks included); everywhere else [check] returns null.
abstract class AppUpdateGateway {
  Future<UpdateCheck?> check();

  /// Starts the background download; true when the user accepted.
  Future<bool> startFlexible();

  /// Installs a downloaded flexible update (the app restarts).
  Future<void> completeFlexible();

  /// Google Play's full-screen update.
  Future<void> immediate();

  /// Fires when a flexible update finished downloading.
  Stream<void> get downloaded;
}

class PlayAppUpdateGateway implements AppUpdateGateway {
  @override
  Future<UpdateCheck?> check() async {
    if (!Platform.isAndroid) {
      return null;
    }
    try {
      final AppUpdateInfo info = await InAppUpdate.checkForUpdate();
      final bool available =
          info.updateAvailability == UpdateAvailability.updateAvailable;
      return UpdateCheck(
        availableCode: available ? info.availableVersionCode : null,
        flexibleAllowed: info.flexibleUpdateAllowed,
        immediateAllowed: info.immediateUpdateAllowed,
      );
    } catch (_) {
      // Not installed from Play, no Play services, offline: no prompt.
      return null;
    }
  }

  @override
  Future<bool> startFlexible() async {
    try {
      return await InAppUpdate.startFlexibleUpdate() == AppUpdateResult.success;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> completeFlexible() async {
    try {
      await InAppUpdate.completeFlexibleUpdate();
    } catch (_) {
      // Play shows its own error; nothing to add.
    }
  }

  @override
  Future<void> immediate() async {
    try {
      await InAppUpdate.performImmediateUpdate();
    } catch (_) {
      // The user backed out or Play failed: the app keeps working.
    }
  }

  @override
  Stream<void> get downloaded => InAppUpdate.installUpdateListener
      .where((InstallStatus s) => s == InstallStatus.downloaded)
      .map((_) {});
}

/// Where the emergency minimum version lives (Firebase Hosting).
const String kMinVersionUrl =
    'https://hebrewcalendar-68363.web.app/min-version.json';

/// The site's `{"minVersionCode": N}`: versions below N get the immediate
/// update. Null when unreachable or unset, which never forces anything.
Future<int?> fetchMinVersionCode({
  http.Client? client,
  String url = kMinVersionUrl,
}) async {
  final http.Client c = client ?? http.Client();
  try {
    final http.Response r = await c
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) {
      return null;
    }
    final Object? json = jsonDecode(utf8.decode(r.bodyBytes));
    final Object? code = json is Map<String, Object?>
        ? json['minVersionCode']
        : null;
    return code is int && code > 0 ? code : null;
  } catch (_) {
    return null;
  } finally {
    if (client == null) {
      c.close();
    }
  }
}
