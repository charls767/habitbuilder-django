import 'package:timezone/timezone.dart' as tz;

import '../entities/recordatorio.dart';

tz.Location resolveProfileLocation(String ianaZoneName) {
  if (ianaZoneName.trim() != ianaZoneName || ianaZoneName.isEmpty) {
    throw ArgumentError.value(
      ianaZoneName,
      'ianaZoneName',
      'Must be a non-empty canonical IANA zone name.',
    );
  }
  try {
    return tz.getLocation(ianaZoneName);
  } on tz.LocationNotFoundException {
    throw ArgumentError.value(
      ianaZoneName,
      'ianaZoneName',
      'Unknown IANA time zone.',
    );
  }
}

final class ReminderOccurrence {
  ReminderOccurrence({
    required this.habitId,
    required this.reminderId,
    required this.message,
    required this.isoWeekday,
    required this.ordinal,
    required this.scheduledAt,
  }) {
    if (isoWeekday < DateTime.monday || isoWeekday > DateTime.sunday) {
      throw ArgumentError.value(
        isoWeekday,
        'isoWeekday',
        'Must be an ISO weekday from 1 through 7.',
      );
    }
    if (ordinal < 0) {
      throw ArgumentError.value(ordinal, 'ordinal', 'Must be non-negative.');
    }
  }

  final String habitId;
  final String reminderId;
  final String message;
  final int isoWeekday;
  final int ordinal;
  final tz.TZDateTime scheduledAt;

  String get key =>
      'ios:$isoWeekday:$ordinal:${scheduledAt.millisecondsSinceEpoch}';

  static int compare(ReminderOccurrence left, ReminderOccurrence right) {
    var comparison = left.scheduledAt.compareTo(right.scheduledAt);
    if (comparison != 0) {
      return comparison;
    }
    comparison = left.reminderId.compareTo(right.reminderId);
    if (comparison != 0) {
      return comparison;
    }
    comparison = left.isoWeekday.compareTo(right.isoWeekday);
    if (comparison != 0) {
      return comparison;
    }
    comparison = left.ordinal.compareTo(right.ordinal);
    if (comparison != 0) {
      return comparison;
    }
    return left.habitId.compareTo(right.habitId);
  }
}

final class ReminderOccurrencePlanner {
  const ReminderOccurrencePlanner();

  ReminderOccurrence nextOccurrence({
    required Recordatorio reminder,
    required tz.Location location,
    required tz.TZDateTime now,
    int ordinal = 0,
  }) {
    if (!reminder.activo) {
      throw StateError('Inactive reminders do not produce occurrences.');
    }
    if (now.location != location) {
      throw ArgumentError.value(
        now.location.name,
        'now',
        'The injected time must use the profile location ${location.name}.',
      );
    }
    if (ordinal < 0) {
      throw ArgumentError.value(ordinal, 'ordinal', 'Must be non-negative.');
    }

    for (var dayOffset = 0; dayOffset <= DateTime.daysPerWeek; dayOffset++) {
      final calendarDate = DateTime.utc(
        now.year,
        now.month,
        now.day + dayOffset,
      );
      if (!reminder.diasSemana.contains(calendarDate.weekday)) {
        continue;
      }
      final candidate = _resolveD08WallTime(
        location: location,
        year: calendarDate.year,
        month: calendarDate.month,
        day: calendarDate.day,
        hour: reminder.hora.hour,
        minute: reminder.hora.minute,
      );
      if (candidate.isAfter(now)) {
        return ReminderOccurrence(
          habitId: reminder.habitId,
          reminderId: reminder.id,
          message: reminder.mensaje,
          isoWeekday: calendarDate.weekday,
          ordinal: ordinal,
          scheduledAt: candidate,
        );
      }
    }
    throw StateError('No future occurrence found for a valid reminder.');
  }
}

final class IosOccurrenceAllocator {
  const IosOccurrenceAllocator();

  static const maximumPending = 64;

  List<ReminderOccurrence> earliest(Iterable<ReminderOccurrence> occurrences) {
    final ordered = List<ReminderOccurrence>.of(occurrences)
      ..sort(ReminderOccurrence.compare);
    final count = ordered.length < maximumPending
        ? ordered.length
        : maximumPending;
    return List<ReminderOccurrence>.unmodifiable(ordered.take(count));
  }
}

tz.TZDateTime _resolveD08WallTime({
  required tz.Location location,
  required int year,
  required int month,
  required int day,
  required int hour,
  required int minute,
}) {
  final localMilliseconds = DateTime.utc(
    year,
    month,
    day,
    hour,
    minute,
  ).millisecondsSinceEpoch;

  for (final transitionAt in location.transitionAt) {
    if (transitionAt <= tz.minTime || transitionAt >= tz.maxTime) {
      continue;
    }
    final beforeOffset = location
        .lookupTimeZone(transitionAt - 1)
        .timeZone
        .offset
        .inMilliseconds;
    final afterOffset = location
        .lookupTimeZone(transitionAt)
        .timeZone
        .offset
        .inMilliseconds;
    if (afterOffset > beforeOffset) {
      final gapStart = transitionAt + beforeOffset;
      final gapEnd = transitionAt + afterOffset;
      if (localMilliseconds >= gapStart && localMilliseconds < gapEnd) {
        return tz.TZDateTime.fromMillisecondsSinceEpoch(location, transitionAt);
      }
    } else if (afterOffset < beforeOffset) {
      final overlapStart = transitionAt + afterOffset;
      final overlapEnd = transitionAt + beforeOffset;
      if (localMilliseconds >= overlapStart && localMilliseconds < overlapEnd) {
        final earliestInstant = localMilliseconds - beforeOffset;
        return tz.TZDateTime.fromMillisecondsSinceEpoch(
          location,
          earliestInstant,
        );
      }
    }
  }

  return tz.TZDateTime(location, year, month, day, hour, minute);
}
