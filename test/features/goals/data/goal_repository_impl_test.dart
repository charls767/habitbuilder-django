import 'package:flutter_test/flutter_test.dart';
import 'package:habitbuilder_mobile/core/network/api_exception.dart';
import 'package:habitbuilder_mobile/features/goals/data/datasources/goal_remote_data_source.dart';
import 'package:habitbuilder_mobile/features/goals/data/models/meta_dto.dart';
import 'package:habitbuilder_mobile/features/goals/data/repositories/goal_repository_impl.dart';
import 'package:habitbuilder_mobile/features/goals/domain/entities/meta.dart';
import 'package:habitbuilder_mobile/features/goals/domain/repositories/goal_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockGoalRemoteDataSource extends Mock implements GoalRemoteDataSource {}

class _FakeCreateRequest extends Fake implements MetaCreateRequestDto {}

class _FakeUpdateRequest extends Fake implements MetaUpdateRequestDto {}

void main() {
  late _MockGoalRemoteDataSource remote;
  late GoalRepositoryImpl repository;

  setUpAll(() {
    registerFallbackValue(_FakeCreateRequest());
    registerFallbackValue(_FakeUpdateRequest());
  });

  setUp(() {
    remote = _MockGoalRemoteDataSource();
    repository = GoalRepositoryImpl(remote);
  });

  test('lists goals and serializes an optional state filter', () async {
    when(
      () => remote.listGoals(estado: 'pausada'),
    ).thenAnswer((_) async => [_goalDto()]);

    final goals = await repository.listGoals(estado: MetaEstado.pausada);

    expect(goals.single.id, 'goal-1');
    expect(goals.single.fechaCreacion, DateTime.utc(2026, 7, 1));
    verify(() => remote.listGoals(estado: 'pausada')).called(1);
  });

  test('lists goals without a state filter', () async {
    when(() => remote.listGoals()).thenAnswer((_) async => [_goalDto()]);

    await repository.listGoals();

    verify(() => remote.listGoals()).called(1);
  });

  test('gets and maps one goal', () async {
    when(() => remote.getGoal('goal-1')).thenAnswer((_) async => _goalDto());

    final goal = await repository.getGoal('goal-1');

    expect(goal.nombre, 'Dormir mejor');
    expect(goal.estado, MetaEstado.enProgreso);
    verify(() => remote.getGoal('goal-1')).called(1);
  });

  test(
    'creates a goal with unique habit ids and exact editable fields',
    () async {
      when(() => remote.createGoal(any())).thenAnswer((_) async => _goalDto());

      final goal = await repository.createGoal(
        nombre: 'Dormir mejor',
        descripcion: 'Ocho horas',
        fechaObjetivo: DateTime(2026, 12, 31),
        habitoIds: const ['habit-1', 'habit-2', 'habit-1'],
      );

      final request =
          verify(() => remote.createGoal(captureAny())).captured.single
              as MetaCreateRequestDto;
      expect(goal.id, 'goal-1');
      expect(request.toJson(), {
        'nombre': 'Dormir mejor',
        'descripcion': 'Ocho horas',
        'fechaObjetivo': '2026-12-31',
        'habitoIds': ['habit-1', 'habit-2'],
      });
    },
  );

  test(
    'updates editable fields and preserves explicit nullable clears',
    () async {
      when(
        () => remote.updateGoal('goal-1', any()),
      ).thenAnswer((_) async => _goalDto());

      final goal = await repository.updateGoal(
        goalId: 'goal-1',
        nombre: 'Dormir profundamente',
        descripcion: const GoalPatchValue<String?>.present(null),
        fechaObjetivo: const GoalPatchValue<DateTime?>.present(null),
        estado: MetaEstado.lograda,
      );

      final request =
          verify(
                () => remote.updateGoal('goal-1', captureAny()),
              ).captured.single
              as MetaUpdateRequestDto;
      expect(goal.id, 'goal-1');
      expect(request.toJson(), {
        'nombre': 'Dormir profundamente',
        'descripcion': null,
        'fechaObjetivo': null,
        'estado': 'lograda',
      });
    },
  );

  test('keeps absent nullable fields out of an update', () async {
    when(
      () => remote.updateGoal('goal-1', any()),
    ).thenAnswer((_) async => _goalDto());

    await repository.updateGoal(
      goalId: 'goal-1',
      descripcion: const GoalPatchValue<String?>.present('Nueva'),
    );

    final request =
        verify(() => remote.updateGoal('goal-1', captureAny())).captured.single
            as MetaUpdateRequestDto;
    expect(request.descripcion.isPresent, isTrue);
    expect(request.fechaObjetivo.isPresent, isFalse);
    expect(request.toJson(), {'descripcion': 'Nueva'});
  });

  test('rejects an empty update before calling the datasource', () async {
    await expectLater(
      repository.updateGoal(goalId: 'goal-1'),
      throwsArgumentError,
    );

    verifyNever(() => remote.updateGoal(any(), any()));
  });

  test('delegates delete only for the selected goal', () async {
    when(() => remote.deleteGoal('goal-1')).thenAnswer((_) async {});

    await repository.deleteGoal('goal-1');

    verify(() => remote.deleteGoal('goal-1')).called(1);
  });

  test('links a habit and maps the authoritative returned goal', () async {
    when(
      () => remote.linkHabit('goal-1', 'habit-2'),
    ).thenAnswer((_) async => _goalDto(habitoIds: ['habit-1', 'habit-2']));

    final goal = await repository.linkHabit('goal-1', 'habit-2');

    expect(goal.habitoIds, ['habit-1', 'habit-2']);
    verify(() => remote.linkHabit('goal-1', 'habit-2')).called(1);
  });

  test('unlinks a habit and maps the authoritative returned goal', () async {
    when(
      () => remote.unlinkHabit('goal-1', 'habit-1'),
    ).thenAnswer((_) async => _goalDto(habitoIds: const []));

    final goal = await repository.unlinkHabit('goal-1', 'habit-1');

    expect(goal.habitoIds, isEmpty);
    verify(() => remote.unlinkHabit('goal-1', 'habit-1')).called(1);
    verifyNever(() => remote.getGoal(any()));
  });

  test('preserves normalized datasource errors unchanged', () async {
    const expected = ApiException(
      statusCode: 409,
      code: 'TRANSICION_INVALIDA',
      message: 'La operacion fue rechazada.',
    );
    when(() => remote.updateGoal('goal-1', any())).thenThrow(expected);

    await expectLater(
      repository.updateGoal(goalId: 'goal-1', estado: MetaEstado.cancelada),
      throwsA(same(expected)),
    );
  });
}

MetaDto _goalDto({List<String> habitoIds = const ['habit-1']}) {
  return MetaDto(
    id: 'goal-1',
    usuarioId: 'user-1',
    nombre: 'Dormir mejor',
    estado: MetaEstado.enProgreso,
    habitoIds: habitoIds,
    fechaCreacion: DateTime.utc(2026, 7, 1),
    fechaActualizacion: DateTime.utc(2026, 7, 28),
  );
}
