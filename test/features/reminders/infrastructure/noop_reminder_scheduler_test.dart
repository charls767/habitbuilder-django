import 'package:flutter_test/flutter_test.dart';
import 'package:habitbuilder_mobile/features/reminders/infrastructure/notifications/noop_reminder_scheduler.dart';
import 'package:habitbuilder_mobile/features/reminders/infrastructure/notifications/reminder_scheduler_factory.dart';
import 'package:habitbuilder_mobile/features/reminders/infrastructure/notifications/reminder_scheduler_factory_noop.dart'
    as noop_factory;

void main() {
  test('unsupported desktop factory returns the explicit no-op adapter', () {
    final scheduler = createReminderScheduler();

    expect(scheduler, isA<NoopReminderScheduler>());
    expect(
      (scheduler as NoopReminderScheduler).support,
      ReminderSchedulingSupport.unsupported,
    );
  });

  test('no-op replacement completes without native plugin behavior', () async {
    final scheduler = NoopReminderScheduler();

    await scheduler.replaceManagedNotifications(const []);

    expect(scheduler.support, ReminderSchedulingSupport.unsupported);
  });

  test('web factory target constructs the explicit no-op adapter', () {
    expect(noop_factory.createReminderScheduler(), isA<NoopReminderScheduler>());
  });
}
