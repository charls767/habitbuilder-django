import '../../domain/services/managed_notification.dart';
import '../../domain/services/reminder_scheduler.dart';

enum ReminderSchedulingSupport { unsupported }

final class NoopReminderScheduler implements ReminderScheduler {
  ReminderSchedulingSupport get support =>
      ReminderSchedulingSupport.unsupported;

  @override
  Future<void> replaceManagedNotifications(
    List<ManagedNotification> notifications,
  ) async {}
}
