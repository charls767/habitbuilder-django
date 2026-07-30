import 'dart:io';

import '../../domain/services/reminder_scheduler.dart';
import 'flutter_notification_gateway.dart';

ReminderScheduler createReminderScheduler() {
  if (Platform.isAndroid) {
    return FlutterNotificationGateway.android();
  }
  throw UnsupportedError(
    'Native reminder scheduling is not available on this platform.',
  );
}
