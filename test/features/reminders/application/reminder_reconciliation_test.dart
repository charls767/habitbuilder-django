import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:habitbuilder_mobile/features/habits/domain/entities/frecuencia.dart';
import 'package:habitbuilder_mobile/features/habits/domain/entities/habito.dart';
import 'package:habitbuilder_mobile/features/profile/domain/entities/perfil_usuario.dart';
import 'package:habitbuilder_mobile/features/reminders/application/reminder_reconciliation_coordinator.dart';
import 'package:habitbuilder_mobile/features/reminders/domain/entities/recordatorio.dart';
import 'package:habitbuilder_mobile/features/reminders/domain/entities/reminder_time.dart';
import 'package:habitbuilder_mobile/features/reminders/domain/services/managed_notification.dart';
import 'package:habitbuilder_mobile/features/reminders/domain/services/reminder_scheduler.dart';
import 'package:timezone/data/latest_all.dart' as timezone_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(timezone_data.initializeTimeZones);

  test(
    'preferences off replaces the managed projection with an empty set',
    () async {
      final scheduler = _RecordingScheduler();
      var habitsCalls = 0;
      final coordinator = _coordinator(
        scheduler: scheduler,
        profile: _profile(notificationsEnabled: false),
        loadHabits: () async {
          habitsCalls++;
          return [_habit()];
        },
      );

      final state = await coordinator.reconcile();

      expect(state.status, ReminderDeliveryStatus.delivered);
      expect(scheduler.replacements, [isEmpty]);
      expect(habitsCalls, 0);
    },
  );

  test('projects only active reminders belonging to active habits', () async {
    final scheduler = _RecordingScheduler();
    final loadedHabitIds = <String>[];
    final coordinator = _coordinator(
      scheduler: scheduler,
      loadHabits: () async => [
        _habit(id: 'active'),
        _habit(id: 'paused', state: HabitoEstado.pausado),
        _habit(id: 'completed', state: HabitoEstado.completado),
      ],
      loadReminders: (habitId) async {
        loadedHabitIds.add(habitId);
        return [
          _reminder(id: 'enabled', habitId: habitId, weekdays: const [1, 3]),
          _reminder(id: 'disabled', habitId: habitId, active: false),
        ];
      },
    );

    await coordinator.reconcile();

    expect(loadedHabitIds, ['active']);
    final projected = scheduler.replacements.single;
    expect(projected, hasLength(2));
    expect(projected.map((item) => item.reminderId), everyElement('enabled'));
    expect(
      projected.map((item) => item.payload),
      everyElement(startsWith(managedReminderPayloadPrefix)),
    );
    expect(
      projected.map((item) => item.scheduledAt.location.name),
      everyElement('America/Bogota'),
    );
  });

  test('invalid profile zone leaves prior schedules untouched', () async {
    final scheduler = _RecordingScheduler()
      ..pendingPayloads.add(
        '${managedReminderPayloadPrefix}habit:reminder:weekly',
      );
    final coordinator = _coordinator(
      scheduler: scheduler,
      profile: _profile(zone: 'Mars/Olympus'),
    );

    final state = await coordinator.reconcile();

    expect(state.status, ReminderDeliveryStatus.failed);
    expect(state.error, isA<ArgumentError>());
    expect(scheduler.replacements, isEmpty);
    expect(scheduler.pendingPayloads, hasLength(1));
  });

  test('partial reminder fetch leaves prior schedules untouched', () async {
    final scheduler = _RecordingScheduler()
      ..pendingPayloads.add(
        '${managedReminderPayloadPrefix}habit:reminder:weekly',
      );
    final coordinator = _coordinator(
      scheduler: scheduler,
      loadHabits: () async => [_habit(id: 'one'), _habit(id: 'two')],
      loadReminders: (habitId) async {
        if (habitId == 'two') {
          throw StateError('partial backend response');
        }
        return [_reminder(id: 'one-reminder', habitId: habitId)];
      },
    );

    final state = await coordinator.reconcile();

    expect(state.status, ReminderDeliveryStatus.failed);
    expect(scheduler.replacements, isEmpty);
    expect(scheduler.pendingPayloads, hasLength(1));
  });

  test('delivery probe failure occurs before scheduler mutation', () async {
    final scheduler = _RecordingScheduler();
    final coordinator = _coordinator(
      scheduler: scheduler,
      deliveryProbe: ({required requestPermission}) async {
        throw StateError('permission state unavailable');
      },
    );

    final state = await coordinator.reconcile(requestPermission: true);

    expect(state.status, ReminderDeliveryStatus.failed);
    expect(scheduler.replacements, isEmpty);
  });

  test(
    'managed replacement preserves unrelated pending notifications',
    () async {
      final scheduler = _RecordingScheduler()
        ..pendingPayloads.addAll([
          'calendar:event:42',
          '${managedReminderPayloadPrefix}old-habit:old-reminder:weekly',
        ]);
      final coordinator = _coordinator(scheduler: scheduler);

      await coordinator.reconcile();

      expect(scheduler.pendingPayloads, contains('calendar:event:42'));
      expect(
        scheduler.pendingPayloads.where(
          (payload) => payload.startsWith(managedReminderPayloadPrefix),
        ),
        isNotEmpty,
      );
      expect(
        scheduler.pendingPayloads,
        isNot(
          contains(
            '${managedReminderPayloadPrefix}old-habit:old-reminder:weekly',
          ),
        ),
      );
    },
  );

  test('overlapping requests serialize and coalesce into one rerun', () async {
    final firstStarted = Completer<void>();
    final releaseFirst = Completer<void>();
    var profileCalls = 0;
    var activeLoads = 0;
    var maximumActiveLoads = 0;
    final scheduler = _RecordingScheduler();
    final coordinator = _coordinator(
      scheduler: scheduler,
      loadProfile: () async {
        profileCalls++;
        activeLoads++;
        if (activeLoads > maximumActiveLoads) {
          maximumActiveLoads = activeLoads;
        }
        if (profileCalls == 1) {
          firstStarted.complete();
          await releaseFirst.future;
        }
        activeLoads--;
        return _profile();
      },
    );

    final first = coordinator.reconcile();
    await firstStarted.future;
    final second = coordinator.reconcile();
    final third = coordinator.reconcile(requestPermission: true);
    releaseFirst.complete();

    final results = await Future.wait([first, second, third]);

    expect(profileCalls, 2);
    expect(maximumActiveLoads, 1);
    expect(scheduler.replacements, hasLength(2));
    expect(
      results.map((state) => state.status),
      everyElement(ReminderDeliveryStatus.delivered),
    );
  });

  test(
    'reports degraded delivery without discarding desired reminders',
    () async {
      final scheduler = _RecordingScheduler();
      final coordinator = _coordinator(
        scheduler: scheduler,
        deliveryProbe: ({required requestPermission}) async =>
            const ReminderDeliveryState.inexact(),
      );

      final state = await coordinator.reconcile();

      expect(state.status, ReminderDeliveryStatus.inexact);
      expect(scheduler.replacements.single, isNotEmpty);
    },
  );
}

ReminderReconciliationCoordinator _coordinator({
  required _RecordingScheduler scheduler,
  PerfilUsuario? profile,
  ProfileLoader? loadProfile,
  HabitsLoader? loadHabits,
  RemindersLoader? loadReminders,
  ReminderDeliveryProbe? deliveryProbe,
}) {
  final location = tz.getLocation('America/Bogota');
  return ReminderReconciliationCoordinator(
    loadProfile: loadProfile ?? () async => profile ?? _profile(),
    loadHabits: loadHabits ?? () async => [_habit()],
    loadReminders:
        loadReminders ??
        (habitId) async => [_reminder(id: 'reminder-1', habitId: habitId)],
    scheduler: scheduler,
    clock: (_) => tz.TZDateTime(location, 2026, 7, 29, 7),
    deliveryProbe:
        deliveryProbe ??
        ({required requestPermission}) async =>
            const ReminderDeliveryState.delivered(),
  );
}

PerfilUsuario _profile({
  String zone = 'America/Bogota',
  bool notificationsEnabled = true,
}) {
  return PerfilUsuario(
    usuarioId: 'user-1',
    nombreCompleto: 'Camila Acevedo',
    objetivoGeneral: 'Dormir mejor',
    zonaHoraria: zone,
    accessibility: const AccessibilityPreferences.defaults(),
    notifications: NotificationPreferences(
      enabled: notificationsEnabled,
      habitReminders: notificationsEnabled,
      weeklySummary: true,
    ),
  );
}

Habito _habit({
  String id = 'habit-1',
  HabitoEstado state = HabitoEstado.activo,
}) {
  return Habito(
    id: id,
    usuarioId: 'user-1',
    nombre: 'Tomar agua',
    fechaInicio: DateTime(2026, 7, 29),
    frecuencia: Frecuencia.diaria(),
    estado: state,
    pausas: const [],
    fechaCreacion: DateTime.utc(2026, 7, 29),
    fechaActualizacion: DateTime.utc(2026, 7, 29),
  );
}

Recordatorio _reminder({
  required String id,
  required String habitId,
  List<int> weekdays = const [3],
  bool active = true,
}) {
  return Recordatorio(
    id: id,
    habitId: habitId,
    mensaje: 'Tomar agua',
    hora: ReminderTime.parse('08:30'),
    diasSemana: weekdays,
    activo: active,
  );
}

final class _RecordingScheduler implements ReminderScheduler {
  final replacements = <List<ManagedNotification>>[];
  final pendingPayloads = <String>[];

  @override
  Future<void> replaceManagedNotifications(
    List<ManagedNotification> notifications,
  ) async {
    replacements.add(List<ManagedNotification>.unmodifiable(notifications));
    pendingPayloads.removeWhere(
      (payload) => payload.startsWith(managedReminderPayloadPrefix),
    );
    pendingPayloads.addAll(notifications.map((item) => item.payload));
  }
}
