import 'package:timezone/timezone.dart' as tz;

import '../../habits/domain/entities/habito.dart';
import '../../profile/domain/entities/perfil_usuario.dart';
import '../domain/entities/recordatorio.dart';
import '../domain/services/reminder_occurrence_planner.dart';
import '../domain/services/reminder_scheduler.dart';

enum ReminderDeliveryStatus {
  idle,
  delivered,
  denied,
  inexact,
  unsupported,
  failed,
}

final class ReminderDeliveryState {
  const ReminderDeliveryState._(this.status, [this.error]);

  const ReminderDeliveryState.idle() : this._(ReminderDeliveryStatus.idle);

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

final class ReminderReconciliationCoordinator {
  ReminderReconciliationCoordinator({
    required this.loadProfile,
    required this.loadHabits,
    required this.loadReminders,
    required this.scheduler,
    required this.clock,
    required this.deliveryProbe,
    this.planner = const ReminderOccurrencePlanner(),
  });

  final ProfileLoader loadProfile;
  final HabitsLoader loadHabits;
  final RemindersLoader loadReminders;
  final ReminderScheduler scheduler;
  final ProfileClock clock;
  final ReminderDeliveryProbe deliveryProbe;
  final ReminderOccurrencePlanner planner;

  ReminderDeliveryState get state => const ReminderDeliveryState.idle();

  Future<ReminderDeliveryState> reconcile({bool requestPermission = false}) {
    throw UnimplementedError('Implemented during the GREEN phase.');
  }
}
