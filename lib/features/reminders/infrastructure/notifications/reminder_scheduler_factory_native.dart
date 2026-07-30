import 'dart:io';

import '../../domain/services/reminder_scheduler.dart';
import 'flutter_notification_gateway.dart';
import 'noop_reminder_scheduler.dart';

ReminderScheduler createReminderScheduler() {
  if (Platform.isAndroid) {
    return FlutterNotificationGateway.android();
  }
  if (Platform.isIOS) {
    return FlutterNotificationGateway.ios();
  }
  return NoopReminderScheduler();
}
