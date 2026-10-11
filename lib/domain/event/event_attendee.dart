/// An invited participant's reply, as Google Calendar reports it (M11).
enum AttendeeResponse { needsAction, accepted, declined, tentative }

/// One participant of an event (M11): invited by email, invitations sent by
/// Google Calendar when the event syncs. [response] comes back from Google.
class EventAttendee {
  const EventAttendee({
    required this.email,
    this.response = AttendeeResponse.needsAction,
  });

  final String email;
  final AttendeeResponse response;

  /// Google's `responseStatus` string -> [AttendeeResponse].
  static AttendeeResponse responseFromGoogle(String? value) =>
      AttendeeResponse.values.firstWhere(
        (AttendeeResponse r) => r.name == value,
        orElse: () => AttendeeResponse.needsAction,
      );

  @override
  bool operator ==(Object other) =>
      other is EventAttendee &&
      other.email.toLowerCase() == email.toLowerCase() &&
      other.response == response;

  @override
  int get hashCode => Object.hash(email.toLowerCase(), response);

  @override
  String toString() => 'EventAttendee($email, ${response.name})';
}

/// Maximum participants per event (Google allows more; this keeps a single
/// sync push and the editor manageable).
const int kMaxEventAttendees = 50;

final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// Whether [value] looks like an email address worth sending an invite to.
bool isValidAttendeeEmail(String value) => _emailPattern.hasMatch(value.trim());

/// M11: [EventAttendee]s as plain maps (`email`, `response`) — shared by
/// Firestore and the local backup format.
List<Map<String, dynamic>> attendeesToMaps(List<EventAttendee> attendees) =>
    <Map<String, dynamic>>[
      for (final EventAttendee a in attendees)
        <String, dynamic>{'email': a.email, 'response': a.response.name},
    ];

/// The inverse of [attendeesToMaps]; tolerates a missing/odd field.
List<EventAttendee> attendeesFromMaps(Object? raw) {
  if (raw is! List) {
    return const <EventAttendee>[];
  }
  return <EventAttendee>[
    for (final Object? item in raw)
      if (item is Map && item['email'] is String)
        EventAttendee(
          email: item['email'] as String,
          response: EventAttendee.responseFromGoogle(
            item['response'] as String?,
          ),
        ),
  ];
}

/// [local] with each participant's reply taken from [fromGoogle] (matched by
/// email, case-insensitively); participants Google doesn't list keep theirs.
List<EventAttendee> mergeAttendeeResponses(
  List<EventAttendee> local,
  List<EventAttendee> fromGoogle,
) {
  final Map<String, AttendeeResponse> replies = <String, AttendeeResponse>{
    for (final EventAttendee a in fromGoogle) a.email.toLowerCase(): a.response,
  };
  return <EventAttendee>[
    for (final EventAttendee a in local)
      EventAttendee(
        email: a.email,
        response: replies[a.email.toLowerCase()] ?? a.response,
      ),
  ];
}
