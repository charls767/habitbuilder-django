import 'package:flutter_test/flutter_test.dart';
import 'package:habitbuilder_mobile/features/reminders/domain/entities/recordatorio.dart';
import 'package:habitbuilder_mobile/features/reminders/domain/entities/reminder_time.dart';
import 'package:habitbuilder_mobile/features/reminders/domain/services/reminder_occurrence_planner.dart';
import 'package:timezone/data/latest_all.dart' as timezone_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  late ReminderOccurrencePlanner planner;

  setUpAll(timezone_data.initializeTimeZones);

  setUp(() {
    planner = const ReminderOccurrencePlanner();
  });

  test('same-day future occurrence keeps the selected profile wall time', () {
    final location = tz.getLocation('America/Bogota');
    final now = tz.TZDateTime(location, 2026, 7, 29, 9);
    final reminder = reminderAt(
      id: 'future',
      hour: 10,
      minute: 15,
      weekdays: [now.weekday],
    );

    final occurrence = planner.nextOccurrence(
      reminder: reminder,
      location: location,
      now: now,
    );

    expect(
      occurrence.scheduledAt,
      tz.TZDateTime(location, 2026, 7, 29, 10, 15),
    );
    expect(occurrence.isoWeekday, now.weekday);
  });

  test('same-day past occurrence rolls to the next selected week', () {
    final location = tz.getLocation('America/Bogota');
    final now = tz.TZDateTime(location, 2026, 7, 29, 10);
    final reminder = reminderAt(
      id: 'past',
      hour: 9,
      minute: 30,
      weekdays: [now.weekday],
    );

    final occurrence = planner.nextOccurrence(
      reminder: reminder,
      location: location,
      now: now,
    );

    expect(occurrence.scheduledAt, tz.TZDateTime(location, 2026, 8, 5, 9, 30));
  });

  test('uses ISO weekdays 1 through 7 without Sunday remapping', () {
    final location = tz.getLocation('Etc/UTC');
    final sunday = tz.TZDateTime(location, 2026, 8, 2, 8);
    expect(sunday.weekday, DateTime.sunday);
    final reminder = reminderAt(
      id: 'monday',
      hour: 7,
      minute: 45,
      weekdays: [DateTime.monday],
    );

    final occurrence = planner.nextOccurrence(
      reminder: reminder,
      location: location,
      now: sunday,
    );

    expect(occurrence.scheduledAt, tz.TZDateTime(location, 2026, 8, 3, 7, 45));
    expect(occurrence.isoWeekday, DateTime.monday);
  });

  test('calendar construction rolls across month and year boundaries', () {
    final location = tz.getLocation('Etc/UTC');
    final now = tz.TZDateTime(location, 2026, 12, 31, 23, 50);
    final januaryFirst = tz.TZDateTime(location, 2027, 1, 1, 0, 5);
    final reminder = reminderAt(
      id: 'new-year',
      hour: 0,
      minute: 5,
      weekdays: [januaryFirst.weekday],
    );

    final occurrence = planner.nextOccurrence(
      reminder: reminder,
      location: location,
      now: now,
    );

    expect(occurrence.scheduledAt, januaryFirst);
  });

  test('profile Location wins when it differs from the device location', () {
    final deviceLocation = tz.getLocation('America/Bogota');
    final profileLocation = tz.getLocation('Asia/Tokyo');
    tz.setLocalLocation(deviceLocation);
    final now = tz.TZDateTime(profileLocation, 2026, 7, 30, 8);
    final reminder = reminderAt(
      id: 'profile-zone',
      hour: 9,
      minute: 0,
      weekdays: [now.weekday],
    );

    final occurrence = planner.nextOccurrence(
      reminder: reminder,
      location: profileLocation,
      now: now,
    );

    expect(occurrence.scheduledAt.location, profileLocation);
    expect(occurrence.scheduledAt.hour, 9);
    expect(occurrence.scheduledAt.toUtc().hour, 0);
    expect(tz.local, deviceLocation);
  });

  test('invalid IANA profile zone fails before planning', () {
    expect(
      () => resolveProfileLocation('Mars/Olympus'),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('D-08 spring gap advances to the first valid local instant', () {
    final location = tz.getLocation('America/New_York');
    final now = tz.TZDateTime(location, 2026, 3, 8, 0);
    final reminder = reminderAt(
      id: 'spring-gap',
      hour: 2,
      minute: 30,
      weekdays: [DateTime.sunday],
    );

    final occurrence = planner.nextOccurrence(
      reminder: reminder,
      location: location,
      now: now,
    );

    expect(occurrence.scheduledAt, tz.TZDateTime(location, 2026, 3, 8, 3));
    expect(occurrence.scheduledAt.timeZoneOffset, const Duration(hours: -4));
  });

  test('D-08 fall overlap emits one occurrence at the earliest offset', () {
    final location = tz.getLocation('America/New_York');
    final now = tz.TZDateTime(location, 2026, 11, 1, 0);
    final reminder = reminderAt(
      id: 'fall-overlap',
      hour: 1,
      minute: 30,
      weekdays: [DateTime.sunday],
    );

    final occurrence = planner.nextOccurrence(
      reminder: reminder,
      location: location,
      now: now,
    );

    expect(
      occurrence.scheduledAt.toUtc(),
      tz.TZDateTime.utc(2026, 11, 1, 5, 30),
    );
    expect(occurrence.scheduledAt.timeZoneOffset, const Duration(hours: -4));
  });

  test('ties are deterministic by reminder, weekday, and ordinal', () {
    final instant = tz.TZDateTime.utc(2026, 8, 1, 12);
    final occurrences = [
      ReminderOccurrence(
        habitId: 'habit',
        reminderId: 'z-reminder',
        message: 'Z',
        isoWeekday: 2,
        ordinal: 0,
        scheduledAt: instant,
      ),
      ReminderOccurrence(
        habitId: 'habit',
        reminderId: 'a-reminder',
        message: 'A',
        isoWeekday: 3,
        ordinal: 1,
        scheduledAt: instant,
      ),
      ReminderOccurrence(
        habitId: 'habit',
        reminderId: 'a-reminder',
        message: 'A',
        isoWeekday: 1,
        ordinal: 0,
        scheduledAt: instant,
      ),
    ];

    occurrences.sort(ReminderOccurrence.compare);

    expect(
      occurrences.map(
        (item) => '${item.reminderId}:${item.isoWeekday}:${item.ordinal}',
      ),
      ['a-reminder:1:0', 'a-reminder:3:1', 'z-reminder:2:0'],
    );
  });
}

Recordatorio reminderAt({
  required String id,
  required int hour,
  required int minute,
  required List<int> weekdays,
}) {
  return Recordatorio(
    id: id,
    habitId: 'habit-1',
    mensaje: 'Hora del habito',
    hora: ReminderTime(hour: hour, minute: minute),
    diasSemana: weekdays,
    activo: true,
  );
}
