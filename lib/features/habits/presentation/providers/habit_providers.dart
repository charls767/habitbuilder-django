import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/dio_client.dart';
import '../../data/datasources/habit_remote_data_source.dart';
import '../../data/repositories/habit_repository_impl.dart';
import '../../domain/entities/categoria.dart';
import '../../domain/entities/frecuencia.dart';
import '../../domain/entities/habito.dart';
import '../../domain/entities/meta_option.dart';
import '../../domain/repositories/habit_repository.dart';
import '../../../reminders/presentation/providers/reminder_providers.dart';

part 'habit_providers.g.dart';

@riverpod
HabitRemoteDataSource habitRemoteDataSource(Ref ref) {
  return HabitRemoteDataSource(ref.watch(dioProvider));
}

@riverpod
HabitRepository habitRepository(Ref ref) {
  return HabitRepositoryImpl(ref.watch(habitRemoteDataSourceProvider));
}

@riverpod
Future<List<Habito>> habitsList(Ref ref) {
  return ref.watch(habitRepositoryProvider).listHabits();
}

@riverpod
Future<Habito> habitDetail(Ref ref, String habitId) {
  return ref.watch(habitRepositoryProvider).getHabit(habitId);
}

@riverpod
Future<List<Categoria>> categoriesList(Ref ref) {
  return ref.watch(habitRepositoryProvider).listCategories();
}

@riverpod
Future<List<MetaOption>> goalOptionsList(Ref ref) {
  return ref.watch(habitRepositoryProvider).listGoalOptions();
}

@riverpod
class HabitController extends _$HabitController {
  @override
  FutureOr<void> build() {}

  Future<bool> createHabit({
    required String nombre,
    required DateTime fechaInicio,
    required Frecuencia frecuencia,
    String? descripcion,
    String? categoriaId,
    String? metaId,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(habitRepositoryProvider)
          .createHabit(
            nombre: nombre,
            descripcion: descripcion,
            fechaInicio: fechaInicio,
            frecuencia: frecuencia,
            categoriaId: categoriaId,
            metaId: metaId,
          ),
    );
    if (!state.hasError) {
      ref.invalidate(habitsListProvider);
    }
    return !state.hasError;
  }

  Future<bool> updateHabit({
    required String habitId,
    required String nombre,
    required DateTime fechaInicio,
    required Frecuencia frecuencia,
    String? descripcion,
    String? categoriaId,
    String? metaId,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(habitRepositoryProvider)
          .updateHabit(
            habitId: habitId,
            nombre: nombre,
            descripcion: PatchValue.present(descripcion),
            fechaInicio: fechaInicio,
            frecuencia: frecuencia,
            categoriaId: PatchValue.present(categoriaId),
            metaId: PatchValue.present(metaId),
          ),
    );
    if (!state.hasError) {
      ref.invalidate(habitsListProvider);
      ref.invalidate(habitDetailProvider(habitId));
    }
    return !state.hasError;
  }

  Future<bool> pauseHabit(String habitId) {
    return _mutateHabit(
      habitId,
      () =>
          ref.read(habitRepositoryProvider).pauseHabit(habitId, DateTime.now()),
      requestPermission: false,
    );
  }

  Future<bool> resumeHabit(String habitId) {
    return _mutateHabit(
      habitId,
      () => ref.read(habitRepositoryProvider).resumeHabit(habitId),
      requestPermission: true,
    );
  }

  Future<bool> completeHabit(String habitId) {
    return _mutateHabit(
      habitId,
      () => ref.read(habitRepositoryProvider).completeHabit(habitId),
      requestPermission: false,
    );
  }

  Future<bool> deleteHabit(String habitId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(habitRepositoryProvider).deleteHabit(habitId),
    );
    if (!state.hasError) {
      ref.invalidate(habitsListProvider);
      ref.invalidate(habitDetailProvider(habitId));
    }
    return !state.hasError;
  }

  Future<bool> _mutateHabit(
    String habitId,
    Future<Habito> Function() operation, {
    required bool requestPermission,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(operation);
    if (!state.hasError) {
      ref.invalidate(habitsListProvider);
      ref.invalidate(habitDetailProvider(habitId));
      await ref.read(reminderReconciliationRequestProvider)(
        requestPermission: requestPermission,
      );
    }
    return !state.hasError;
  }
}
