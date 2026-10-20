import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/update/app_update_gateway.dart';
import '../../domain/update/update_decision.dart';
import '../../l10n/app_localizations.dart';

/// Google Play In-App Updates. Overridden in tests and screenshots.
final Provider<AppUpdateGateway> appUpdateGatewayProvider =
    Provider<AppUpdateGateway>((Ref ref) => PlayAppUpdateGateway());

/// The site's emergency minimum version. Overridden in tests.
final Provider<Future<int?> Function()> minVersionCodeProvider =
    Provider<Future<int?> Function()>((Ref ref) => fetchMinVersionCode);

/// The installed build number (the Play version code).
final Provider<Future<int> Function()> installedVersionCodeProvider =
    Provider<Future<int> Function()>(
      (Ref ref) =>
          () async =>
              int.tryParse((await PackageInfo.fromPlatform()).buildNumber) ?? 0,
    );

const String _kDismissedKey = 'app_update_dismissed_v1';
const String _kCheckedKey = 'app_update_checked_v1';

/// How often the app asks Play about a newer version.
const Duration kUpdateCheckEvery = Duration(hours: 12);

/// Wraps the calendar home (owner request 2026-10-20): when Google Play
/// has a newer version, a banner offers it ("עדכון" / "לא עכשיו"); the
/// download runs in the background and a snackbar offers to restart into
/// it. A version below the site's minimum gets Play's full-screen update.
class AppUpdateLauncher extends ConsumerStatefulWidget {
  const AppUpdateLauncher({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppUpdateLauncher> createState() => _AppUpdateLauncherState();
}

class _AppUpdateLauncherState extends ConsumerState<AppUpdateLauncher>
    with WidgetsBindingObserver {
  StreamSubscription<void>? _downloaded;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_check()));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_downloaded?.cancel());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_check());
    }
  }

  Future<void> _check() async {
    if (_busy || !mounted) {
      return;
    }
    _busy = true;
    try {
      final DateTime now = DateTime.now();
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final int? checked = prefs.getInt(_kCheckedKey);
      if (checked != null &&
          now.difference(DateTime.fromMillisecondsSinceEpoch(checked)) <
              kUpdateCheckEvery) {
        return;
      }
      final AppUpdateGateway gateway = ref.read(appUpdateGatewayProvider);
      final UpdateCheck? update = await gateway.check();
      if (update == null) {
        return;
      }
      await prefs.setInt(_kCheckedKey, now.millisecondsSinceEpoch);
      final int? dismissed = prefs.getInt(_kDismissedKey);
      final UpdatePrompt prompt = decideUpdatePrompt(
        installedCode: await ref.read(installedVersionCodeProvider)(),
        availableCode: update.availableCode,
        flexibleAllowed: update.flexibleAllowed,
        immediateAllowed: update.immediateAllowed,
        minVersionCode: await ref.read(minVersionCodeProvider)(),
        dismissedAt: dismissed == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(dismissed),
        now: now,
      );
      if (!mounted) {
        return;
      }
      switch (prompt) {
        case UpdatePrompt.none:
          break;
        case UpdatePrompt.immediate:
          await gateway.immediate();
        case UpdatePrompt.flexible:
          _showBanner(gateway, prefs);
      }
    } catch (_) {
      // Never let an update check break the calendar.
    } finally {
      _busy = false;
    }
  }

  void _showBanner(AppUpdateGateway gateway, SharedPreferences prefs) {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    messenger.showMaterialBanner(
      MaterialBanner(
        key: const ValueKey<String>('app-update-banner'),
        leading: const Icon(Icons.system_update),
        content: Text(l10n.updateAvailable),
        actions: <Widget>[
          TextButton(
            key: const ValueKey<String>('app-update-later'),
            onPressed: () {
              messenger.hideCurrentMaterialBanner();
              unawaited(
                prefs.setInt(
                  _kDismissedKey,
                  DateTime.now().millisecondsSinceEpoch,
                ),
              );
            },
            child: Text(l10n.updateLater),
          ),
          FilledButton(
            key: const ValueKey<String>('app-update-now'),
            onPressed: () {
              messenger.hideCurrentMaterialBanner();
              unawaited(_startDownload(gateway, messenger, l10n));
            },
            child: Text(l10n.updateNow),
          ),
        ],
      ),
    );
  }

  Future<void> _startDownload(
    AppUpdateGateway gateway,
    ScaffoldMessengerState messenger,
    AppLocalizations l10n,
  ) async {
    await _downloaded?.cancel();
    _downloaded = gateway.downloaded.listen((_) {
      messenger.showSnackBar(
        SnackBar(
          key: const ValueKey<String>('app-update-ready'),
          duration: const Duration(days: 1),
          content: Text(l10n.updateDownloaded),
          action: SnackBarAction(
            label: l10n.updateRestart,
            onPressed: () => unawaited(gateway.completeFlexible()),
          ),
        ),
      );
    });
    await gateway.startFlexible();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
