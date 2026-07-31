import 'managed_notification.dart';

abstract interface class ReminderScheduler {
  Future<void> replaceManagedNotifications(
    List<ManagedNotification> notifications,
  );
}
