import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/dio_client.dart';
import '../../../habits/domain/entities/habito.dart';
import '../../../habits/presentation/providers/habit_providers.dart';
import '../../data/datasources/reminder_remote_data_source.dart';
import '../../data/repositories/reminder_repository_impl.dart';
import '../../domain/entities/recordatorio.dart';
import '../../domain/repositories/reminder_repository.dart';

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
    });
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
    });
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

  Future<bool> _mutate(Future<void> Function() operation) async {
    if (state.isLoading) return false;

    state = const AsyncLoading();
    state = await AsyncValue.guard(operation);
    if (!state.hasError) {
      ref.invalidate(remindersListProvider(_habitId));
    }
    return !state.hasError;
  }
}
