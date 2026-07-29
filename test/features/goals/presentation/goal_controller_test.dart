import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitbuilder_mobile/core/network/api_exception.dart';
import 'package:habitbuilder_mobile/features/goals/domain/entities/meta.dart';
import 'package:habitbuilder_mobile/features/goals/domain/repositories/goal_repository.dart';
import 'package:habitbuilder_mobile/features/goals/presentation/providers/goal_providers.dart';

void main() {
  test('create delegates exact fields and reports success', () async {
    final repository = _FakeGoalRepository();
    final container = _container(repository);
    addTearDown(container.dispose);

    final success = await container
        .read(goalControllerProvider.notifier)
        .createGoal(
          nombre: 'Dormir mejor',
          descripcion: 'Ocho horas',
          fechaObjetivo: DateTime(2026, 12, 31),
          habitoIds: const ['hab-2', 'hab-1'],
        );

    expect(success, isTrue);
    expect(repository.createdName, 'Dormir mejor');
    expect(repository.createdDescription, 'Ocho horas');
    expect(repository.createdDate, DateTime(2026, 12, 31));
    expect(repository.createdHabitIds, ['hab-2', 'hab-1']);
  });

  test(
    'update sends fields and synchronizes additions before removals',
    () async {
      final repository = _FakeGoalRepository();
      final container = _container(repository);
      addTearDown(container.dispose);

      final success = await container
          .read(goalControllerProvider.notifier)
          .updateGoal(
            goalId: 'goal-1',
            nombre: 'Rutina nocturna',
            descripcion: null,
            fechaObjetivo: null,
            estado: MetaEstado.pausada,
            previousHabitIds: const ['hab-3', 'hab-1'],
            selectedHabitIds: const ['hab-4', 'hab-2'],
          );

      expect(success, isTrue);
      expect(repository.updatedName, 'Rutina nocturna');
      expect(repository.updatedDescription?.isPresent, isTrue);
      expect(repository.updatedDescription?.value, isNull);
      expect(repository.updatedDate?.isPresent, isTrue);
      expect(repository.updatedState, MetaEstado.pausada);
      expect(repository.linkedHabitIds, ['hab-2', 'hab-4']);
      expect(repository.unlinkedHabitIds, ['hab-1', 'hab-3']);
    },
  );

  test(
    'link failure is exposed without continuing destructive changes',
    () async {
      final repository = _FakeGoalRepository()
        ..failure = const ApiException(
          statusCode: 409,
          code: 'HABITO_ASIGNADO',
          message: 'El hábito no se pudo reasignar.',
        );
      final container = _container(repository);
      addTearDown(container.dispose);

      final success = await container
          .read(goalControllerProvider.notifier)
          .updateHabitLinks(
            goalId: 'goal-1',
            previousHabitIds: const ['hab-1'],
            selectedHabitIds: const ['hab-2'],
          );

      expect(success, isFalse);
      expect(container.read(goalControllerProvider).error, repository.failure);
      expect(repository.unlinkedHabitIds, isEmpty);
    },
  );
}

ProviderContainer _container(GoalRepository repository) {
  return ProviderContainer(
    overrides: [goalRepositoryProvider.overrideWithValue(repository)],
  );
}

class _FakeGoalRepository implements GoalRepository {
  Object? failure;
  String? createdName;
  String? createdDescription;
  DateTime? createdDate;
  List<String>? createdHabitIds;
  String? updatedName;
  GoalPatchValue<String?>? updatedDescription;
  GoalPatchValue<DateTime?>? updatedDate;
  MetaEstado? updatedState;
  final linkedHabitIds = <String>[];
  final unlinkedHabitIds = <String>[];

  void _throwIfNeeded() {
    if (failure case final error?) throw error;
  }

  @override
  Future<Meta> createGoal({
    required String nombre,
    String? descripcion,
    DateTime? fechaObjetivo,
    List<String> habitoIds = const [],
  }) async {
    _throwIfNeeded();
    createdName = nombre;
    createdDescription = descripcion;
    createdDate = fechaObjetivo;
    createdHabitIds = habitoIds;
    return _goal();
  }

  @override
  Future<Meta> updateGoal({
    required String goalId,
    String? nombre,
    GoalPatchValue<String?> descripcion =
        const GoalPatchValue<String?>.absent(),
    GoalPatchValue<DateTime?> fechaObjetivo =
        const GoalPatchValue<DateTime?>.absent(),
    MetaEstado? estado,
  }) async {
    _throwIfNeeded();
    updatedName = nombre;
    updatedDescription = descripcion;
    updatedDate = fechaObjetivo;
    updatedState = estado;
    return _goal();
  }

  @override
  Future<Meta> linkHabit(String goalId, String habitId) async {
    _throwIfNeeded();
    linkedHabitIds.add(habitId);
    return _goal(habitIds: linkedHabitIds);
  }

  @override
  Future<Meta> unlinkHabit(String goalId, String habitId) async {
    _throwIfNeeded();
    unlinkedHabitIds.add(habitId);
    return _goal();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Meta _goal({List<String> habitIds = const []}) {
  return Meta(
    id: 'goal-1',
    usuarioId: 'user-1',
    nombre: 'Dormir mejor',
    estado: MetaEstado.enProgreso,
    habitoIds: habitIds,
    fechaCreacion: DateTime.utc(2026, 7, 1),
    fechaActualizacion: DateTime.utc(2026, 7, 28),
  );
}
