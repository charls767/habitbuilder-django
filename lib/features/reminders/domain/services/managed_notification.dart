import 'package:timezone/timezone.dart' as tz;

const managedReminderPayloadPrefix = 'habit-reminder:v1:';

final class ManagedNotification {
  ManagedNotification({
    required this.id,
    required this.habitId,
    required this.reminderId,
    required this.key,
    required this.title,
    required this.body,
    required this.scheduledAt,
  }) : payload = payloadFor(
         habitId: habitId,
         reminderId: reminderId,
         key: key,
       ) {
    if (id < 0) {
      throw ArgumentError.value(id, 'id', 'Must be non-negative.');
    }
  }

  final int id;
  final String habitId;
  final String reminderId;
  final String key;
  final String title;
  final String body;
  final tz.TZDateTime scheduledAt;
  final String payload;

  static String payloadFor({
    required String habitId,
    required String reminderId,
    required String key,
  }) {
    if (habitId.isEmpty || reminderId.isEmpty || key.isEmpty) {
      throw ArgumentError(
        'Managed notification habit, reminder, and key must be non-empty.',
      );
    }
    return '$managedReminderPayloadPrefix$habitId:$reminderId:$key';
  }
}

abstract final class ManagedNotificationId {
  static const reservedBase = 1000000;
  static const maximumId = 0x7fffffff;

  static Map<String, int> allocate(Iterable<String> managedKeys) {
    final keys = List<String>.of(managedKeys);
    if (keys.any((key) => key.isEmpty)) {
      throw ArgumentError.value(keys, 'managedKeys', 'Keys must be non-empty.');
    }
    if (keys.toSet().length != keys.length) {
      throw ArgumentError.value(
        keys,
        'managedKeys',
        'Managed keys must be unique.',
      );
    }
    if (keys.length > maximumId - reservedBase + 1) {
      throw ArgumentError.value(
        keys.length,
        'managedKeys',
        'Managed notification ID range exhausted.',
      );
    }

    keys.sort();
    return Map<String, int>.unmodifiable({
      for (var index = 0; index < keys.length; index++)
        keys[index]: reservedBase + index,
    });
  }
}
