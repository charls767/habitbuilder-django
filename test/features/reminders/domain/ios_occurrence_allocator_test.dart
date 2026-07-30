import 'package:flutter_test/flutter_test.dart';
import 'package:habitbuilder_mobile/features/reminders/domain/services/reminder_occurrence_planner.dart';
import 'package:timezone/data/latest_all.dart' as timezone_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(timezone_data.initializeTimeZones);

  const allocator = IosOccurrenceAllocator();

  test('returns every event when fewer than 64 are available', () {
    final events = occurrences(10).reversed;

    final allocated = allocator.earliest(events);

    expect(allocated, hasLength(10));
    expect(allocated.map((item) => item.ordinal), List.generate(10, (i) => i));
  });

  test('returns exactly 64 events when exactly 64 are available', () {
    final allocated = allocator.earliest(occurrences(64));

    expect(allocated, hasLength(IosOccurrenceAllocator.maximumPending));
    expect(allocated.last.ordinal, 63);
  });

  test('returns globally earliest 64 when more than 64 are available', () {
    final events = occurrences(80).reversed;

    final allocated = allocator.earliest(events);

    expect(allocated, hasLength(64));
    expect(allocated.first.ordinal, 0);
    expect(allocated.last.ordinal, 63);
    expect(allocated.any((item) => item.ordinal >= 64), isFalse);
  });

  test('uses deterministic tie-breakers independent of input order', () {
    final instant = tz.TZDateTime.utc(2026, 8, 1, 12);
    final events = [
      occurrence(reminderId: 'b', isoWeekday: 1, ordinal: 0, at: instant),
      occurrence(reminderId: 'a', isoWeekday: 2, ordinal: 0, at: instant),
      occurrence(reminderId: 'a', isoWeekday: 1, ordinal: 1, at: instant),
      occurrence(reminderId: 'a', isoWeekday: 1, ordinal: 0, at: instant),
    ];

    final allocated = allocator.earliest(events.reversed);

    expect(
      allocated.map(
        (item) => '${item.reminderId}:${item.isoWeekday}:${item.ordinal}',
      ),
      ['a:1:0', 'a:1:1', 'a:2:0', 'b:1:0'],
    );
  });
}

List<ReminderOccurrence> occurrences(int count) {
  return List.generate(
    count,
    (index) => occurrence(
      reminderId: 'reminder-${index % 3}',
      isoWeekday: (index % DateTime.daysPerWeek) + 1,
      ordinal: index,
      at: tz.TZDateTime.utc(2026, 8, 1, 12, index),
    ),
  );
}

ReminderOccurrence occurrence({
  required String reminderId,
  required int isoWeekday,
  required int ordinal,
  required tz.TZDateTime at,
}) {
  return ReminderOccurrence(
    habitId: 'habit',
    reminderId: reminderId,
    message: 'Mensaje',
    isoWeekday: isoWeekday,
    ordinal: ordinal,
    scheduledAt: at,
  );
}
