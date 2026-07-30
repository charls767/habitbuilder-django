import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:timezone/data/latest_all.dart' as timezone_data;
import 'package:timezone/timezone.dart' as tz;

import '../../../../core/network/dio_client.dart';
import '../../../habits/domain/entities/habito.dart';
import '../../../habits/presentation/providers/habit_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../application/reminder_reconciliation_coordinator.dart';
import '../../data/datasources/reminder_remote_data_source.dart';
import '../../data/repositories/reminder_repository_impl.dart';
import '../../domain/entities/recordatorio.dart';
import '../../domain/repositories/reminder_repository.dart';
import '../../domain/services/reminder_scheduler.dart';
import '../../infrastructure/notifications/noop_reminder_scheduler.dart';
import '../../infrastructure/notifications/reminder_scheduler_factory.dart';

part 'reminder_providers.g.dart';

@riverpod
ReminderRemoteDataSource reminderRemoteDataSource(Ref ref) {
  return ReminderRemoteDataSource(ref.watch(dioProvider));
}

@riverpod
ReminderRepository reminderRepository(Ref ref) {
  return ReminderRepositoryImpl(ref.watch(reminderRemoteDataSourceProvider));
}

@riverpod
Future<List<Recordatorio>> remindersList(Ref ref, String habitId) {
  return ref.watch(reminderRepositoryProvider).listByHabit(habitId);
}

typedef ReminderReconciliationRequest =
    Future<ReminderDeliveryState> Function({bool requestPermission});

final reminderReconciliationRequestProvider =
    Provider<ReminderReconciliationRequest>(
      (ref) => ({bool requestPermission = false}) {
        timezone_data.initializeTimeZones();
        return ref
            .read(reminderReconciliationCoordinatorProvider)
            .reconcile(requestPermission: requestPermission);
      },
    );

final reminderSchedulerProvider = Provider<ReminderScheduler>(
  (ref) => createReminderScheduler(),
);

final reminderReconciliationCoordinatorProvider =
    Provider<ReminderReconciliationCoordinator>((ref) {
      final scheduler = ref.watch(reminderSchedulerProvider);
      return ReminderReconciliationCoordinator(
        loadProfile: () => ref.read(profileRepositoryProvider).getMyProfile(),
        loadHabits: () => ref.read(habitRepositoryProvider).listHabits(),
        loadReminders: (habitId) =>
            ref.read(reminderRepositoryProvider).listByHabit(habitId),
        scheduler: scheduler,
        clock: tz.TZDateTime.now,
        deliveryProbe: ({required requestPermission}) => _probeDeliveryState(
          scheduler,
          requestPermission: requestPermission,
        ),
        onStateChanged: (state) {
          ref.read(reminderDeliveryStateProvider.notifier).update(state);
        },
      );
    });

final reminderDeliveryStateProvider =
    NotifierProvider<ReminderDeliveryController, ReminderDeliveryState>(
      ReminderDeliveryController.new,
    );

final class ReminderDeliveryController extends Notifier<ReminderDeliveryState> {
  @override
  ReminderDeliveryState build() => const ReminderDeliveryState.idle();

  void update(ReminderDeliveryState next) {
    state = next;
  }

  Future<void> retry() async {
    state = await ref.read(reminderReconciliationRequestProvider)(
      requestPermission: true,
    );
  }
}

Future<ReminderDeliveryState> _probeDeliveryState(
  ReminderScheduler scheduler, {
  required bool requestPermission,
}) async {
  if (scheduler is NoopReminderScheduler) {
    return const ReminderDeliveryState.unsupported();
  }

  final dynamic gateway = scheduler;
  try {
    final dynamic permission = await gateway.permissionState(
      requestFromEligibleActivation: requestPermission,
    );
    if (permission.notificationsGranted != true) {
      return const ReminderDeliveryState.denied();
    }
    final precision = permission.precision.toString().split('.').last;
    if (precision == 'inexact') {
      return const ReminderDeliveryState.inexact();
    }
    if (precision == 'exact') {
      return const ReminderDeliveryState.delivered();
    }
    throw StateError('Unknown reminder delivery precision: $precision');
  } on NoSuchMethodError {
    throw StateError(
      'The native reminder scheduler does not expose delivery state.',
    );
  }
}

final class ReminderEligibilityException implements Exception {
  const ReminderEligibilityException(this.message);

  final String message;

  @override
  String toString() => message;
}

const reminderEligibilityMessage =
    'Los hábitos pausados o completados no pueden crear ni reactivar '
    'recordatorios.';

bool canActivateReminders(Habito? habit) {
  return habit?.estado == HabitoEstado.activo;
}

@riverpod
class ReminderController extends _$ReminderController {
  late String _habitId;

  @override
  FutureOr<void> build(String habitId) {
    _habitId = habitId;
  }

  Future<bool> create(ReminderDraft draft) {
    return _mutate(() async {
      await _ensureCanActivate();
      await ref
          .read(reminderRepositoryProvider)
          .create(habitId: _habitId, draft: draft);
    }, requestPermission: draft.activo);
  }

  Future<bool> updateReminder({
    required Recordatorio reminder,
    required ReminderDraft draft,
  }) {
    return _mutate(() async {
      if (!reminder.activo && draft.activo) {
        await _ensureCanActivate();
      }
      await ref
          .read(reminderRepositoryProvider)
          .update(reminderId: reminder.id, draft: draft);
    }, requestPermission: !reminder.activo && draft.activo);
  }

  Future<bool> toggle(Recordatorio reminder, bool active) {
    return updateReminder(
      reminder: reminder,
      draft: ReminderDraft(
        mensaje: reminder.mensaje,
        hora: reminder.hora,
        diasSemana: reminder.diasSemana,
        activo: active,
      ),
    );
  }

  Future<bool> delete(String reminderId) {
    return _mutate(
      () => ref.read(reminderRepositoryProvider).delete(reminderId),
    );
  }

  Future<void> _ensureCanActivate() async {
    final habit = await ref.read(habitDetailProvider(_habitId).future);
    if (!canActivateReminders(habit)) {
      throw const ReminderEligibilityException(reminderEligibilityMessage);
    }
  }

  Future<bool> _mutate(
    Future<void> Function() operation, {
    bool requestPermission = false,
  }) async {
    if (state.isLoading) return false;

    state = const AsyncLoading();
    state = await AsyncValue.guard(operation);
    if (!state.hasError) {
      ref.invalidate(remindersListProvider(_habitId));
      await ref.read(reminderReconciliationRequestProvider)(
        requestPermission: requestPermission,
      );
    }
    return !state.hasError;
  }
}
