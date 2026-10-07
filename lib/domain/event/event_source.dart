/// Where an [Event] originated from — ARCHITECTURE.md §5's "imported events
/// ... marked as `source: google`". Plain data, no Flutter/Firebase.
enum EventSource {
  /// Created in this app (the default for every event before M5a).
  app,

  /// Imported from Google Calendar by the M5a sync engine.
  google,
}
