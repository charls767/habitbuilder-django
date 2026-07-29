import 'package:flutter_test/flutter_test.dart';
import 'package:habitbuilder_mobile/features/reminders/infrastructure/notifications/flutter_notification_gateway.dart';

void main() {
  group('Android notification permission policy', () {
    test('uses exact scheduling only while exact alarms are granted', () async {
      final boundary = _FakeNotificationPermissionBoundary(
        notificationsEnabled: true,
        exactSchedulingEnabled: true,
      );
      final policy = NotificationPermissionPolicy(
        platform: NotificationGatewayPlatform.android,
        boundary: boundary,
      );

      final state = await policy.resolve(
        requestFromEligibleActivation: false,
      );

      expect(state.notificationsGranted, isTrue);
      expect(state.precision, ReminderSchedulePrecision.exact);
      expect(boundary.notificationRequestCount, 0);
      expect(boundary.exactRequestCount, 0);
    });

    test('does not prompt when reconciliation finds notifications denied',
        () async {
      final boundary = _FakeNotificationPermissionBoundary(
        notificationsEnabled: false,
        exactSchedulingEnabled: true,
      );
      final policy = NotificationPermissionPolicy(
        platform: NotificationGatewayPlatform.android,
        boundary: boundary,
      );

      final state = await policy.resolve(
        requestFromEligibleActivation: false,
      );

      expect(state.notificationsGranted, isFalse);
      expect(state.precision, ReminderSchedulePrecision.unavailable);
      expect(boundary.notificationRequestCount, 0);
      expect(boundary.exactCheckCount, 0);
    });

    test('eligible activation requests notification and exact permissions',
        () async {
      final boundary = _FakeNotificationPermissionBoundary(
        notificationsEnabled: false,
        notificationRequestResult: true,
        exactSchedulingEnabled: false,
        exactRequestResult: false,
      );
      final policy = NotificationPermissionPolicy(
        platform: NotificationGatewayPlatform.android,
        boundary: boundary,
      );

      final state = await policy.resolve(
        requestFromEligibleActivation: true,
      );

      expect(state.notificationsGranted, isTrue);
      expect(state.precision, ReminderSchedulePrecision.inexact);
      expect(boundary.notificationRequestCount, 1);
      expect(boundary.exactRequestCount, 1);
      expect(boundary.exactCheckCount, 2);
    });

    test('rechecks exact permission on every reconciliation', () async {
      final boundary = _FakeNotificationPermissionBoundary(
        notificationsEnabled: true,
        exactSchedulingEnabled: true,
      );
      final policy = NotificationPermissionPolicy(
        platform: NotificationGatewayPlatform.android,
        boundary: boundary,
      );

      expect(
        (await policy.resolve(requestFromEligibleActivation: false)).precision,
        ReminderSchedulePrecision.exact,
      );
      boundary.exactSchedulingEnabled = false;
      expect(
        (await policy.resolve(requestFromEligibleActivation: false)).precision,
        ReminderSchedulePrecision.inexact,
      );

      expect(boundary.exactCheckCount, 2);
      expect(boundary.exactRequestCount, 0);
    });

    test('uses exact scheduling after settings grant is rechecked', () async {
      final boundary = _FakeNotificationPermissionBoundary(
        notificationsEnabled: true,
        exactSchedulingEnabled: false,
        exactRequestResult: true,
      );
      final policy = NotificationPermissionPolicy(
        platform: NotificationGatewayPlatform.android,
        boundary: boundary,
      );

      final state = await policy.resolve(
        requestFromEligibleActivation: true,
      );

      expect(state.precision, ReminderSchedulePrecision.exact);
      expect(boundary.exactRequestCount, 1);
      expect(boundary.exactCheckCount, 2);
    });
  });
}

final class _FakeNotificationPermissionBoundary
    implements NotificationPermissionBoundary {
  _FakeNotificationPermissionBoundary({
    required this.notificationsEnabled,
    required this.exactSchedulingEnabled,
    this.notificationRequestResult = false,
    this.exactRequestResult = false,
  });

  bool notificationsEnabled;
  bool exactSchedulingEnabled;
  final bool notificationRequestResult;
  final bool exactRequestResult;

  int notificationRequestCount = 0;
  int exactRequestCount = 0;
  int exactCheckCount = 0;

  @override
  Future<bool> areNotificationsEnabled() async => notificationsEnabled;

  @override
  Future<bool> canScheduleExactNotifications() async {
    exactCheckCount += 1;
    return exactSchedulingEnabled;
  }

  @override
  Future<bool> requestNotificationPermission() async {
    notificationRequestCount += 1;
    notificationsEnabled = notificationRequestResult;
    return notificationRequestResult;
  }

  @override
  Future<void> requestExactAlarmPermission() async {
    exactRequestCount += 1;
    exactSchedulingEnabled = exactRequestResult;
  }
}
