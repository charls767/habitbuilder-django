import 'package:flutter_test/flutter_test.dart';
import 'package:habitbuilder_mobile/features/habits/data/datasources/habit_remote_data_source.dart';
import 'package:habitbuilder_mobile/features/habits/data/models/categoria_dto.dart';
import 'package:habitbuilder_mobile/features/habits/data/models/frecuencia_dto.dart';
import 'package:habitbuilder_mobile/features/habits/data/models/habito_dto.dart';
import 'package:habitbuilder_mobile/features/habits/data/models/meta_option_dto.dart';
import 'package:habitbuilder_mobile/features/habits/data/repositories/habit_repository_impl.dart';
import 'package:habitbuilder_mobile/features/habits/domain/entities/frecuencia.dart';
import 'package:habitbuilder_mobile/features/habits/domain/entities/habito.dart';
import 'package:habitbuilder_mobile/features/habits/domain/repositories/habit_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockHabitRemoteDataSource extends Mock
    implements HabitRemoteDataSource {}

class _FakeCreateRequest extends Fake implements HabitoCreateRequestDto {}

class _FakeUpdateRequest extends Fake implements HabitoUpdateRequestDto {}

void main() {
  late _MockHabitRemoteDataSource remote;
  late HabitRepositoryImpl repository;

  setUpAll(() {
    registerFallbackValue(_FakeCreateRequest());
    registerFallbackValue(_FakeUpdateRequest());
  });

  setUp(() {
    remote = _MockHabitRemoteDataSource();
    repository = HabitRepositoryImpl(remote);
  });

  test('maps category options', () async {
    when(() => remote.listCategories()).thenAnswer(
      (_) async => const [
        CategoriaDto(
          id: 'cat-1',
          nombre: 'Salud',
          colorHex: '#00FF00',
          icono: 'fitness',
        ),
      ],
    );

    final categories = await repository.listCategories();

    expect(categories.single.id, 'cat-1');
    expect(categories.single.nombre, 'Salud');
    expect(categories.single.colorHex, '#00FF00');
    verify(() => remote.listCategories()).called(1);
  });

  test('maps minimal goal options without exposing goal CRUD', () async {
    when(() => remote.listGoalOptions()).thenAnswer(
      (_) async => const [MetaOptionDto(id: 'goal-1', nombre: 'Dormir mejor')],
    );

    final options = await repository.listGoalOptions();

    expect(options.single.id, 'goal-1');
    expect(options.single.nombre, 'Dormir mejor');
    verify(() => remote.listGoalOptions()).called(1);
  });

  test('lists habits without a filter', () async {
    when(() => remote.listHabits()).thenAnswer((_) async => [_habitDto()]);

    final habits = await repository.listHabits();

    expect(habits.single.id, 'habit-1');
    verify(() => remote.listHabits()).called(1);
  });

  test('serializes the status filter using its API value', () async {
    when(
      () => remote.listHabits(estado: 'completado'),
    ).thenAnswer((_) async => [_habitDto()]);

    final habits = await repository.listHabits(estado: HabitoEstado.completado);

    expect(habits.single.estado, HabitoEstado.activo);
    verify(() => remote.listHabits(estado: 'completado')).called(1);
  });

  test('gets and maps one habit', () async {
    when(() => remote.getHabit('habit-1')).thenAnswer((_) async => _habitDto());

    final habit = await repository.getHabit('habit-1');

    expect(habit.nombre, 'Leer');
    expect(habit.frecuencia, isA<FrecuenciaDiaria>());
    verify(() => remote.getHabit('habit-1')).called(1);
  });

  test('creates a habit with fechaInicio required and exact payload', () async {
    when(() => remote.createHabit(any())).thenAnswer((_) async => _habitDto());

    final habit = await repository.createHabit(
      nombre: 'Leer',
      descripcion: 'Veinte paginas',
      categoriaId: 'cat-1',
      metaId: 'goal-1',
      fechaInicio: DateTime(2026, 7, 28),
      frecuencia: Frecuencia.vecesPeriodo(3, PeriodoFrecuencia.semana),
    );

    final request =
        verify(() => remote.createHabit(captureAny())).captured.single
            as HabitoCreateRequestDto;
    expect(habit.id, 'habit-1');
    expect(request.toJson(), {
      'nombre': 'Leer',
      'descripcion': 'Veinte paginas',
      'categoriaId': 'cat-1',
      'metaId': 'goal-1',
      'fechaInicio': '2026-07-28',
      'frecuencia': {'tipo': 'veces_periodo', 'veces': 3, 'periodo': 'semana'},
    });
  });

  test('updates fields and preserves explicit nullable clears', () async {
    when(
      () => remote.updateHabit('habit-1', any()),
    ).thenAnswer((_) async => _habitDto());

    final habit = await repository.updateHabit(
      habitId: 'habit-1',
      nombre: 'Leer a diario',
      descripcion: const PatchValue<String?>.present(null),
      categoriaId: const PatchValue<String?>.present('cat-2'),
      metaId: const PatchValue<String?>.present(null),
      fechaInicio: DateTime(2026, 8, 1),
      frecuencia: Frecuencia.diasSemana([1, 5]),
    );

    final request =
        verify(
              () => remote.updateHabit('habit-1', captureAny()),
            ).captured.single
            as HabitoUpdateRequestDto;
    expect(habit.id, 'habit-1');
    expect(request.toJson(), {
      'nombre': 'Leer a diario',
      'descripcion': null,
      'categoriaId': 'cat-2',
      'metaId': null,
      'fechaInicio': '2026-08-01',
      'frecuencia': {
        'tipo': 'dias_semana',
        'diasSemana': [1, 5],
      },
    });
  });

  test('keeps absent nullable patch fields out of the request', () async {
    when(
      () => remote.updateHabit('habit-1', any()),
    ).thenAnswer((_) async => _habitDto());

    await repository.updateHabit(
      habitId: 'habit-1',
      descripcion: const PatchValue<String?>.present(null),
    );

    final request =
        verify(
              () => remote.updateHabit('habit-1', captureAny()),
            ).captured.single
            as HabitoUpdateRequestDto;
    expect(request.descripcion.isPresent, isTrue);
    expect(request.categoriaId.isPresent, isFalse);
    expect(request.metaId.isPresent, isFalse);
    expect(request.toJson(), {'descripcion': null});
  });

  test('rejects an empty update before calling the datasource', () async {
    await expectLater(
      repository.updateHabit(habitId: 'habit-1'),
      throwsArgumentError,
    );

    verifyNever(() => remote.updateHabit(any(), any()));
  });

  test('delegates delete as a CRUD operation', () async {
    when(() => remote.deleteHabit('habit-1')).thenAnswer((_) async {});

    await repository.deleteHabit('habit-1');

    verify(() => remote.deleteHabit('habit-1')).called(1);
  });
}

HabitoDto _habitDto() {
  return HabitoDto(
    id: 'habit-1',
    usuarioId: 'user-1',
    nombre: 'Leer',
    fechaInicio: DateTime(2026, 7, 28),
    frecuencia: const FrecuenciaDiariaDto(),
    estado: HabitoEstado.activo,
    pausas: const [],
    fechaCreacion: DateTime.utc(2026, 7, 1),
    fechaActualizacion: DateTime.utc(2026, 7, 28),
  );
}
