import 'dart:async';

import 'package:timezone/timezone.dart' as tz;

import '../../habits/domain/entities/habito.dart';
import '../../profile/domain/entities/perfil_usuario.dart';
import '../domain/entities/recordatorio.dart';
import '../domain/services/managed_notification.dart';
import '../domain/services/reminder_occurrence_planner.dart';
import '../domain/services/reminder_scheduler.dart';

enum ReminderDeliveryStatus {
  idle,
  reconciling,
  delivered,
  denied,
  inexact,
  unsupported,
  failed,
}

final class ReminderDeliveryState {
  const ReminderDeliveryState._(this.status, [this.error]);

  const ReminderDeliveryState.idle() : this._(ReminderDeliveryStatus.idle);

  const ReminderDeliveryState.reconciling()
    : this._(ReminderDeliveryStatus.reconciling);

  const ReminderDeliveryState.delivered()
    : this._(ReminderDeliveryStatus.delivered);

  const ReminderDeliveryState.denied() : this._(ReminderDeliveryStatus.denied);

  const ReminderDeliveryState.inexact()
    : this._(ReminderDeliveryStatus.inexact);

  const ReminderDeliveryState.unsupported()
    : this._(ReminderDeliveryStatus.unsupported);

  const ReminderDeliveryState.failed(Object error)
    : this._(ReminderDeliveryStatus.failed, error);

  final ReminderDeliveryStatus status;
  final Object? error;
}

typedef ProfileLoader = Future<PerfilUsuario> Function();
typedef HabitsLoader = Future<List<Habito>> Function();
typedef RemindersLoader = Future<List<Recordatorio>> Function(String habitId);
typedef ProfileClock = tz.TZDateTime Function(tz.Location location);
typedef ReminderDeliveryProbe =
    Future<ReminderDeliveryState> Function({required bool requestPermission});
typedef ReminderDeliveryListener = void Function(ReminderDeliveryState state);

final class ReminderReconciliationCoordinator {
  ReminderReconciliationCoordinator({
    required this.loadProfile,
    required this.loadHabits,
    required this.loadReminders,
    required this.scheduler,
    required this.clock,
    required this.deliveryProbe,
    this.planner = const ReminderOccurrencePlanner(),
    this.onStateChanged,
  });

  final ProfileLoader loadProfile;
  final HabitsLoader loadHabits;
  final RemindersLoader loadReminders;
  final ReminderScheduler scheduler;
  final ProfileClock clock;
  final ReminderDeliveryProbe deliveryProbe;
  final ReminderOccurrencePlanner planner;
  final ReminderDeliveryListener? onStateChanged;

  ReminderDeliveryState _state = const ReminderDeliveryState.idle();
  Future<ReminderDeliveryState>? _running;
  bool _rerunRequested = false;
  bool _requestPermission = false;

  ReminderDeliveryState get state => _state;

  Future<ReminderDeliveryState> reconcile({bool requestPermission = false}) {
    _rerunRequested = true;
    _requestPermission = _requestPermission || requestPermission;
    final running = _running;
    if (running != null) {
      return running;
    }

    final completion = Completer<ReminderDeliveryState>();
    _running = completion.future;
    unawaited(_drain(completion));
    return completion.future;
  }

  Future<void> _drain(Completer<ReminderDeliveryState> completion) async {
    var latest = _state;
    do {
      _rerunRequested = false;
      final requestPermission = _requestPermission;
      _requestPermission = false;
      latest = await _reconcileOnce(requestPermission: requestPermission);
    } while (_rerunRequested);

    _running = null;
    completion.complete(latest);
  }

  Future<ReminderDeliveryState> _reconcileOnce({
    required bool requestPermission,
  }) async {
    _setState(const ReminderDeliveryState.reconciling());
    try {
      final profile = await loadProfile();
      final remindersEnabled =
          profile.notifications.enabled && profile.notifications.habitReminders;
      if (!remindersEnabled) {
        await scheduler.replaceManagedNotifications(const []);
        return _setState(const ReminderDeliveryState.delivered());
      }

      final location = resolveProfileLocation(profile.zonaHoraria);
      final now = clock(location);
      if (now.location != location) {
        throw ArgumentError.value(
          now.location.name,
          'clock',
          'The injected clock must use the profile location ${location.name}.',
        );
      }

      final habits = await loadHabits();
      final activeHabits =
          habits.where((habit) => habit.estado == HabitoEstado.activo).toList()
            ..sort((left, right) => left.id.compareTo(right.id));
      final remindersByHabit = await Future.wait(
        activeHabits.map((habit) async {
          final reminders = await loadReminders(habit.id);
          if (reminders.any((reminder) => reminder.habitId != habit.id)) {
            throw StateError(
              'Reminder response for ${habit.id} contained another habit.',
            );
          }
          return reminders;
        }),
      );

      final candidates = <_ManagedCandidate>[];
      for (var index = 0; index < activeHabits.length; index++) {
        final habit = activeHabits[index];
        final reminders =
            remindersByHabit[index]
                .where((reminder) => reminder.activo)
                .toList()
              ..sort((left, right) => left.id.compareTo(right.id));
        for (final reminder in reminders) {
          for (final weekday in reminder.diasSemana) {
            final occurrence = planner.nextOccurrence(
              reminder: Recordatorio(
                id: reminder.id,
                habitId: reminder.habitId,
                mensaje: reminder.mensaje,
                hora: reminder.hora,
                diasSemana: [weekday],
                activo: true,
              ),
              location: location,
              now: now,
            );
            candidates.add(
              _ManagedCandidate(
                habit: habit,
                reminder: reminder,
                key: 'weekly:${habit.id}:${reminder.id}:$weekday',
                scheduledAt: occurrence.scheduledAt,
              ),
            );
          }
        }
      }
      candidates.sort(_ManagedCandidate.compare);

      final ids = ManagedNotificationId.allocate(
        candidates.map((candidate) => candidate.key),
      );
      final desired = List<ManagedNotification>.unmodifiable(
        candidates.map(
          (candidate) => ManagedNotification(
            id: ids[candidate.key]!,
            habitId: candidate.habit.id,
            reminderId: candidate.reminder.id,
            key: candidate.key,
            title: candidate.habit.nombre,
            body: candidate.reminder.mensaje,
            scheduledAt: candidate.scheduledAt,
          ),
        ),
      );

      final delivery = desired.isEmpty
          ? const ReminderDeliveryState.delivered()
          : await deliveryProbe(requestPermission: requestPermission);
      await scheduler.replaceManagedNotifications(desired);
      return _setState(delivery);
    } catch (error) {
      return _setState(ReminderDeliveryState.failed(error));
    }
  }

  ReminderDeliveryState _setState(ReminderDeliveryState next) {
    _state = next;
    onStateChanged?.call(next);
    return next;
  }
}

final class _ManagedCandidate {
  const _ManagedCandidate({
    required this.habit,
    required this.reminder,
    required this.key,
    required this.scheduledAt,
  });

  final Habito habit;
  final Recordatorio reminder;
  final String key;
  final tz.TZDateTime scheduledAt;

  static int compare(_ManagedCandidate left, _ManagedCandidate right) {
    final instant = left.scheduledAt.compareTo(right.scheduledAt);
    if (instant != 0) {
      return instant;
    }
    return left.key.compareTo(right.key);
  }
}
