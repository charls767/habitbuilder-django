import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habitbuilder_mobile/features/reminders/domain/services/managed_notification.dart';
import 'package:habitbuilder_mobile/features/reminders/infrastructure/notifications/flutter_notification_gateway.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

const _mode = String.fromEnvironment(
  'REMINDER_ACCEPTANCE_MODE',
  defaultValue: 'full',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: SizedBox.shrink()));

  try {
    tz_data.initializeTimeZones();
    final gateway = FlutterNotificationGateway.android();
    if (_mode == 'verify') {
      await _verifyPersistedSchedule(gateway);
    } else if (_mode == 'full') {
      await _exerciseManagedLifecycle(gateway);
    } else {
      throw StateError('Unknown reminder acceptance mode: $_mode');
    }
  } catch (error, stackTrace) {
    debugPrint('REMINDER_ACCEPTANCE:FAIL mode=$_mode error=$error');
    debugPrintStack(stackTrace: stackTrace);
  } finally {
    await SystemNavigator.pop();
  }
}

Future<void> _exerciseManagedLifecycle(
  FlutterNotificationGateway gateway,
) async {
  final permission = await gateway.permissionState(
    requestFromEligibleActivation: false,
  );
  if (!permission.notificationsGranted) {
    await gateway.replaceManagedNotifications(const []);
    _expect(
      (await gateway.managedPendingNotifications()).isEmpty,
      'denied permission must leave no managed notifications',
    );
    debugPrint('REMINDER_ACCEPTANCE:PASS mode=full permission=denied');
    return;
  }

  final first = _notification(body: 'Initial acceptance reminder');
  await gateway.replaceManagedNotifications([first]);
  var pending = await gateway.managedPendingNotifications();
  _expect(pending.length == 1, 'initial schedule was not persisted');
  _expect(
    pending.single.payload.startsWith(managedReminderPayloadPrefix),
    'managed payload prefix is missing',
  );

  final edited = _notification(body: 'Edited acceptance reminder');
  await gateway.replaceManagedNotifications([edited]);
  pending = await gateway.managedPendingNotifications();
  _expect(
    pending.length == 1 && pending.single.body == edited.body,
    'edit did not replace the managed schedule',
  );

  await gateway.replaceManagedNotifications(const []);
  _expect(
    (await gateway.managedPendingNotifications()).isEmpty,
    'deactivation did not clear the managed schedule',
  );

  await gateway.replaceManagedNotifications([edited]);
  await gateway.replaceManagedNotifications(const []);
  _expect(
    (await gateway.managedPendingNotifications()).isEmpty,
    'delete did not clear the managed schedule',
  );

  await gateway.replaceManagedNotifications([edited]);
  _expect(
    (await gateway.managedPendingNotifications()).length == 1,
    'final schedule seed was not persisted',
  );
  debugPrint(
    'REMINDER_ACCEPTANCE:PASS mode=full '
    'permission=granted precision=${permission.precision.name} '
    'payload=${edited.payload}',
  );
}

Future<void> _verifyPersistedSchedule(
  FlutterNotificationGateway gateway,
) async {
  final pending = await gateway.managedPendingNotifications();
  _expect(pending.length == 1, 'expected one restored managed notification');
  _expect(
    pending.single.payload.startsWith(managedReminderPayloadPrefix),
    'restored notification has an unmanaged payload',
  );
  debugPrint(
    'REMINDER_ACCEPTANCE:PASS mode=verify '
    'pending=${pending.length} payload=${pending.single.payload}',
  );
}

ManagedNotification _notification({required String body}) {
  final now = tz.TZDateTime.now(tz.UTC);
  final scheduledAt = now.add(const Duration(minutes: 10));
  return ManagedNotification(
    id: ManagedNotificationId.reservedBase,
    habitId: 'android-acceptance-habit',
    reminderId: 'android-acceptance-reminder',
    key: 'weekly-${scheduledAt.weekday}',
    title: 'HabitBuilder',
    body: body,
    scheduledAt: scheduledAt,
  );
}

void _expect(bool condition, String message) {
  if (!condition) {
    throw StateError(message);
  }
}
