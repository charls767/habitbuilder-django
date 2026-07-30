import 'package:flutter_test/flutter_test.dart';
import 'package:habitbuilder_mobile/features/reminders/domain/services/managed_notification.dart';
import 'package:habitbuilder_mobile/features/reminders/domain/services/reminder_scheduler.dart';

void main() {
  test('allocates stable non-negative IDs independent of input order', () {
    final first = ManagedNotificationId.allocate([
      'habit-reminder:v1:habit:reminder:b',
      'habit-reminder:v1:habit:reminder:a',
    ]);
    final second = ManagedNotificationId.allocate([
      'habit-reminder:v1:habit:reminder:a',
      'habit-reminder:v1:habit:reminder:b',
    ]);

    expect(first, second);
    expect(first.values.every((id) => id >= 0), isTrue);
    expect(first.values.toSet(), hasLength(first.length));
    expect(
      first['habit-reminder:v1:habit:reminder:a'],
      ManagedNotificationId.reservedBase,
    );
  });

  test('rejects duplicate managed keys instead of assigning collisions', () {
    expect(
      () => ManagedNotificationId.allocate(['same', 'same']),
      throwsArgumentError,
    );
  });

  test('uses the literal versioned managed payload prefix', () {
    expect(managedReminderPayloadPrefix, 'habit-reminder:v1:');
    expect(
      ManagedNotification.payloadFor(
        habitId: 'habit-7',
        reminderId: 'reminder-4',
        key: 'ios:1:0',
      ),
      'habit-reminder:v1:habit-7:reminder-4:ios:1:0',
    );
  });

  test('scheduler contract remains a pure Dart replace projection port', () {
    final scheduler = _FakeReminderScheduler();

    expect(scheduler, isA<ReminderScheduler>());
    expect(scheduler.replaceManagedNotifications(const []), completes);
  });
}

final class _FakeReminderScheduler implements ReminderScheduler {
  @override
  Future<void> replaceManagedNotifications(
    List<ManagedNotification> notifications,
  ) async {}
}
