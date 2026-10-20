/// What the app should ask about a newer version (owner request
/// 2026-10-20): nothing, a dismissible banner, or Google Play's full-screen
/// update.
enum UpdatePrompt { none, flexible, immediate }

/// How long "לא עכשיו" quiets the banner.
const Duration kUpdateSnooze = Duration(days: 3);

/// Decides the prompt. Play reports an update ([availableCode] above
/// [installedCode]) and which kinds it allows. An installed version below
/// the site's [minVersionCode] (the emergency switch, `site/min-version.json`)
/// asks for the immediate update; otherwise a flexible one, unless the
/// banner was dismissed within [kUpdateSnooze].
UpdatePrompt decideUpdatePrompt({
  required int installedCode,
  required int? availableCode,
  required bool flexibleAllowed,
  required bool immediateAllowed,
  required int? minVersionCode,
  required DateTime? dismissedAt,
  required DateTime now,
}) {
  if (availableCode == null || availableCode <= installedCode) {
    return UpdatePrompt.none;
  }
  if (immediateAllowed &&
      minVersionCode != null &&
      installedCode < minVersionCode) {
    return UpdatePrompt.immediate;
  }
  if (!flexibleAllowed) {
    return UpdatePrompt.none;
  }
  if (dismissedAt != null && now.difference(dismissedAt) < kUpdateSnooze) {
    return UpdatePrompt.none;
  }
  return UpdatePrompt.flexible;
}
