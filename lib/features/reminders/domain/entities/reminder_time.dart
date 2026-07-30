final class ReminderTime {
  const ReminderTime._(this.hour, this.minute);

  factory ReminderTime({required int hour, required int minute}) {
    if (hour < 0 || hour > 23) {
      throw RangeError.range(hour, 0, 23, 'hour');
    }
    if (minute < 0 || minute > 59) {
      throw RangeError.range(minute, 0, 59, 'minute');
    }
    return ReminderTime._(hour, minute);
  }

  factory ReminderTime.parse(String value) {
    final match = _wallClockPattern.firstMatch(value);
    if (match == null) {
      throw FormatException('Hora invalida; se esperaba HH:mm.', value);
    }
    return ReminderTime._(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
    );
  }

  static final RegExp _wallClockPattern = RegExp(
    r'^([01]\d|2[0-3]):([0-5]\d)$',
  );

  final int hour;
  final int minute;

  @override
  String toString() {
    final formattedHour = hour.toString().padLeft(2, '0');
    final formattedMinute = minute.toString().padLeft(2, '0');
    return '$formattedHour:$formattedMinute';
  }

  @override
  bool operator ==(Object other) {
    return other is ReminderTime &&
        other.hour == hour &&
        other.minute == minute;
  }

  @override
  int get hashCode => Object.hash(hour, minute);
}
