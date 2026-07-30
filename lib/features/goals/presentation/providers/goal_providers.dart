import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/dio_client.dart';
import '../../../habits/presentation/providers/habit_providers.dart';
import '../../data/datasources/goal_remote_data_source.dart';
import '../../data/repositories/goal_repository_impl.dart';
import '../../domain/entities/meta.dart';
import '../../domain/repositories/goal_repository.dart';

part 'goal_providers.g.dart';

@riverpod
GoalRemoteDataSource goalRemoteDataSource(Ref ref) {
  return GoalRemoteDataSource(ref.watch(dioProvider));
}

@riverpod
GoalRepository goalRepository(Ref ref) {
  return GoalRepositoryImpl(ref.watch(goalRemoteDataSourceProvider));
}

@riverpod
Future<List<Meta>> goalsList(Ref ref) {
  return ref.watch(goalRepositoryProvider).listGoals();
}

@riverpod
Future<Meta> goalDetail(Ref ref, String goalId) {
  return ref.watch(goalRepositoryProvider).getGoal(goalId);
}

@riverpod
class GoalController extends _$GoalController {
  @override
  FutureOr<void> build() {}

  Future<bool> createGoal({
    required String nombre,
    String? descripcion,
    DateTime? fechaObjetivo,
    List<String> habitoIds = const [],
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(goalRepositoryProvider);
      final goal = await repository.createGoal(
        nombre: nombre,
        descripcion: descripcion,
        fechaObjetivo: fechaObjetivo,
        habitoIds: habitoIds,
      );
      await _synchronizeHabitLinks(
        goalId: goal.id,
        previousHabitIds: const [],
        selectedHabitIds: habitoIds,
      );
    });
    if (!state.hasError) {
      _invalidateGoalCollections();
    }
    return !state.hasError;
  }

  Future<bool> updateGoal({
    required String goalId,
    required String nombre,
    required String? descripcion,
    required DateTime? fechaObjetivo,
    required MetaEstado estado,
    required Iterable<String> previousHabitIds,
    required Iterable<String> selectedHabitIds,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(goalRepositoryProvider)
          .updateGoal(
            goalId: goalId,
            nombre: nombre,
            descripcion: GoalPatchValue<String?>.present(descripcion),
            fechaObjetivo: GoalPatchValue<DateTime?>.present(fechaObjetivo),
            estado: estado,
          );
      await _synchronizeHabitLinks(
        goalId: goalId,
        previousHabitIds: previousHabitIds,
        selectedHabitIds: selectedHabitIds,
      );
    });
    if (!state.hasError) {
      _invalidateGoalCollections(goalId);
    }
    return !state.hasError;
  }

  Future<bool> updateHabitLinks({
    required String goalId,
    required Iterable<String> previousHabitIds,
    required Iterable<String> selectedHabitIds,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _synchronizeHabitLinks(
        goalId: goalId,
        previousHabitIds: previousHabitIds,
        selectedHabitIds: selectedHabitIds,
      ),
    );
    if (!state.hasError) {
      _invalidateGoalCollections(goalId);
    }
    return !state.hasError;
  }

  Future<void> _synchronizeHabitLinks({
    required String goalId,
    required Iterable<String> previousHabitIds,
    required Iterable<String> selectedHabitIds,
  }) async {
    final repository = ref.read(goalRepositoryProvider);
    final previous = previousHabitIds.toSet();
    final selected = selectedHabitIds.toSet();
    final additions = selected.difference(previous).toList()..sort();
    final removals = previous.difference(selected).toList()..sort();

    for (final habitId in additions) {
      await repository.linkHabit(goalId, habitId);
    }
    for (final habitId in removals) {
      await repository.unlinkHabit(goalId, habitId);
    }
  }

  void _invalidateGoalCollections([String? goalId]) {
    ref.invalidate(goalsListProvider);
    ref.invalidate(goalOptionsListProvider);
    ref.invalidate(habitsListProvider);
    if (goalId != null) {
      ref.invalidate(goalDetailProvider(goalId));
    }
  }
}
