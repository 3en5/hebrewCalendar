import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// The installed app version (M7 task brief §3 — "גרסה X.Y.Z" on the
/// settings screen), read from the platform via `package_info_plus`
/// (`pubspec.yaml`'s `version:` at build time). A [FutureProvider] rather
/// than a plain one because `PackageInfo.fromPlatform()` is itself async;
/// widget tests avoid ever hitting the real platform channel by calling
/// `PackageInfo.setMockInitialValues(...)` before pumping (the package's own
/// supported test seam), not by overriding this provider.
final FutureProvider<String> appVersionProvider = FutureProvider<String>((
  Ref ref,
) async {
  final PackageInfo info = await PackageInfo.fromPlatform();
  // Build number too ("1.0.0 (13)"), so a device report says exactly
  // which Play build is installed.
  return info.buildNumber.isEmpty
      ? info.version
      : '${info.version} (${info.buildNumber})';
});
