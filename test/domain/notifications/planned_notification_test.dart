// Unit tests for PlannedNotification's value semantics (equality, hashCode,
// toString) — mirrors test/domain/event/event_occurrence_test.dart's
// pattern for another small domain value object.

import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/domain/notifications/planned_notification.dart';

void main() {
  final DateTime fireAt = DateTime(2026, 1, 10, 13, 30);

  PlannedNotification build({int stableId = 1, String body = 'body'}) =>
      PlannedNotification(
        stableId: stableId,
        fireAt: fireAt,
        title: 'תזכורת',
        body: body,
      );

  test('two notifications with identical fields are equal', () {
    expect(build(), build());
    expect(build().hashCode, build().hashCode);
  });

  test('a different stableId makes them unequal', () {
    expect(build(stableId: 1), isNot(build(stableId: 2)));
  });

  test('a different body makes them unequal', () {
    expect(build(body: 'a'), isNot(build(body: 'b')));
  });

  test('toString includes the id, fire time, title and body', () {
    final String text = build(stableId: 42, body: 'פגישה').toString();
    expect(text, contains('42'));
    expect(text, contains('פגישה'));
    expect(text, contains('תזכורת'));
  });
}
