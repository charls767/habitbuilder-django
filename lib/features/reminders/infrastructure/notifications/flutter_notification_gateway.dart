import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../domain/services/managed_notification.dart';
import '../../domain/services/reminder_scheduler.dart';

enum NotificationGatewayPlatform { android, ios }

enum ReminderSchedulePrecision { exact, inexact, unavailable }

final class NotificationPermissionState {
  const NotificationPermissionState({
    required this.notificationsGranted,
    required this.precision,
  });

  final bool notificationsGranted;
  final ReminderSchedulePrecision precision;
}

final class ManagedPendingNotification {
  const ManagedPendingNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.payload,
  });

  final int id;
  final String? title;
  final String? body;
  final String payload;
}

abstract interface class NotificationPermissionBoundary {
  Future<bool> areNotificationsEnabled();

  Future<bool> requestNotificationPermission();

  Future<bool> canScheduleExactNotifications();

  Future<void> requestExactAlarmPermission();
}

final class NotificationPermissionPolicy {
  NotificationPermissionPolicy({
    required this.platform,
    required this.boundary,
  });

  final NotificationGatewayPlatform platform;
  final NotificationPermissionBoundary boundary;

  Future<NotificationPermissionState> resolve({
    required bool requestFromEligibleActivation,
  }) async {
    if (platform != NotificationGatewayPlatform.android) {
      throw UnsupportedError('iOS permission policy is not configured yet.');
    }

    var notificationsGranted = await boundary.areNotificationsEnabled();
    if (!notificationsGranted && requestFromEligibleActivation) {
      notificationsGranted = await boundary.requestNotificationPermission();
    }
    if (!notificationsGranted) {
      return const NotificationPermissionState(
        notificationsGranted: false,
        precision: ReminderSchedulePrecision.unavailable,
      );
    }

    var exactGranted = await boundary.canScheduleExactNotifications();
    if (!exactGranted && requestFromEligibleActivation) {
      await boundary.requestExactAlarmPermission();
      exactGranted = await boundary.canScheduleExactNotifications();
    }

    return NotificationPermissionState(
      notificationsGranted: true,
      precision: exactGranted
          ? ReminderSchedulePrecision.exact
          : ReminderSchedulePrecision.inexact,
    );
  }
}

final class FlutterNotificationGateway implements ReminderScheduler {
  FlutterNotificationGateway.android({FlutterLocalNotificationsPlugin? plugin})
    : _platform = NotificationGatewayPlatform.android,
      _plugin = plugin ?? FlutterLocalNotificationsPlugin() {
    _permissionBoundary = _FlutterNotificationPermissionBoundary.android(
      _plugin,
    );
    _permissionPolicy = NotificationPermissionPolicy(
      platform: _platform,
      boundary: _permissionBoundary,
    );
  }

  static const _androidChannelId = 'habit_reminders';
  static const _androidChannelName = 'Recordatorios de hábitos';
  static const _androidChannelDescription =
      'Recordatorios configurados para hábitos activos.';

  final NotificationGatewayPlatform _platform;
  final FlutterLocalNotificationsPlugin _plugin;
  late final NotificationPermissionBoundary _permissionBoundary;
  late final NotificationPermissionPolicy _permissionPolicy;
  Future<void>? _initialization;

  Future<void> initialize() => _initialization ??= _initialize();

  Future<NotificationPermissionState> permissionState({
    required bool requestFromEligibleActivation,
  }) async {
    await initialize();
    return _permissionPolicy.resolve(
      requestFromEligibleActivation: requestFromEligibleActivation,
    );
  }

  Future<List<ManagedPendingNotification>> managedPendingNotifications() async {
    await initialize();
    final pending = await _plugin.pendingNotificationRequests();
    return pending
        .where(
          (request) =>
              request.payload?.startsWith(managedReminderPayloadPrefix) ??
              false,
        )
        .map(
          (request) => ManagedPendingNotification(
            id: request.id,
            title: request.title,
            body: request.body,
            payload: request.payload!,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> replaceManagedNotifications(
    List<ManagedNotification> notifications,
  ) async {
    await initialize();
    final permission = await permissionState(
      requestFromEligibleActivation: false,
    );
    final pending = await managedPendingNotifications();
    for (final request in pending) {
      await _plugin.cancel(id: request.id);
    }

    if (!permission.notificationsGranted) {
      return;
    }

    final scheduleMode = permission.precision == ReminderSchedulePrecision.exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    for (final notification in notifications) {
      await _plugin.zonedSchedule(
        id: notification.id,
        title: notification.title,
        body: notification.body,
        scheduledDate: notification.scheduledAt,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _androidChannelId,
            _androidChannelName,
            channelDescription: _androidChannelDescription,
            icon: 'ic_notification',
          ),
        ),
        androidScheduleMode: scheduleMode,
        payload: notification.payload,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  Future<void> _initialize() async {
    if (_platform != NotificationGatewayPlatform.android) {
      throw UnsupportedError('iOS gateway is not configured yet.');
    }
    final initialized = await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
      ),
    );
    if (initialized != true) {
      throw StateError('Local notification plugin initialization failed.');
    }
  }
}

final class _FlutterNotificationPermissionBoundary
    implements NotificationPermissionBoundary {
  _FlutterNotificationPermissionBoundary.android(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  AndroidFlutterLocalNotificationsPlugin get _android {
    final implementation = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (implementation == null) {
      throw StateError('Android notification implementation is unavailable.');
    }
    return implementation;
  }

  @override
  Future<bool> areNotificationsEnabled() async =>
      await _android.areNotificationsEnabled() ?? false;

  @override
  Future<bool> canScheduleExactNotifications() async =>
      await _android.canScheduleExactNotifications() ?? false;

  @override
  Future<void> requestExactAlarmPermission() async {
    await _android.requestExactAlarmsPermission();
  }

  @override
  Future<bool> requestNotificationPermission() async =>
      await _android.requestNotificationsPermission() ?? false;
}
