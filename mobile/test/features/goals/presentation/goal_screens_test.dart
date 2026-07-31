import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitbuilder_mobile/core/network/api_exception.dart';
import 'package:habitbuilder_mobile/features/goals/domain/entities/meta.dart';
import 'package:habitbuilder_mobile/features/goals/domain/repositories/goal_repository.dart';
import 'package:habitbuilder_mobile/features/goals/presentation/providers/goal_providers.dart';
import 'package:habitbuilder_mobile/features/goals/presentation/screens/goal_detail_screen.dart';
import 'package:habitbuilder_mobile/features/goals/presentation/screens/goal_form_screen.dart';
import 'package:habitbuilder_mobile/features/goals/presentation/screens/goals_list_screen.dart';
import 'package:habitbuilder_mobile/features/habits/domain/entities/frecuencia.dart';
import 'package:habitbuilder_mobile/features/habits/domain/entities/habito.dart';
import 'package:habitbuilder_mobile/features/habits/presentation/providers/habit_providers.dart';
// ignore: implementation_imports, depend_on_referenced_packages
import 'package:riverpod/src/framework.dart' show Override;

void main() {
  group('GoalsListScreen', () {
    testWidgets('shows names, states and target dates', (tester) async {
      await _pump(
        tester,
        const GoalsListScreen(),
        overrides: [
          goalsListProvider.overrideWith(
            (ref) async => [
              _goal(fechaObjetivo: DateTime(2026, 12, 31)),
              _goal(
                id: 'goal-2',
                nombre: 'Leer más',
                estado: MetaEstado.lograda,
              ),
            ],
          ),
        ],
      );

      expect(find.text('Mis metas'), findsOneWidget);
      expect(find.text('Dormir mejor'), findsOneWidget);
      expect(find.text('En curso'), findsOneWidget);
      expect(find.text('31/12/2026'), findsOneWidget);
      expect(find.text('Leer más'), findsOneWidget);
      expect(find.text('Alcanzada'), findsOneWidget);
    });

    testWidgets('renders loading state', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            goalsListProvider.overrideWith(
              (ref) => Completer<List<Meta>>().future,
            ),
          ],
          child: const MaterialApp(home: GoalsListScreen()),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders an actionable empty state', (tester) async {
      await _pump(
        tester,
        const GoalsListScreen(),
        overrides: [goalsListProvider.overrideWith((ref) async => const [])],
      );
      expect(find.text('Define tu próxima meta'), findsOneWidget);
      expect(find.text('Crear meta'), findsOneWidget);
    });

    testWidgets('renders an actionable error state', (tester) async {
      await _pump(
        tester,
        const GoalsListScreen(),
        overrides: [
          goalsListProvider.overrideWith(
            (ref) => Future<List<Meta>>.error(Exception('offline')),
          ),
        ],
      );
      expect(find.text('No pudimos cargar tus metas.'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });
  });

  group('GoalFormScreen', () {
    testWidgets('validates and creates a goal with linked habits', (
      tester,
    ) async {
      final repository = _ScreenGoalRepository();
      await _pumpForm(tester, repository);

      await tester.tap(find.widgetWithText(TextButton, 'Guardar'));
      await tester.pump();
      expect(find.text('Escribe un nombre para la meta'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre'),
        'Dormir profundamente',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Descripción'),
        'Ocho horas',
      );
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pump();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Leer'));
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(repository.createdName, 'Dormir profundamente');
      expect(repository.createdDescription, 'Ocho horas');
      expect(repository.createdHabitIds, ['hab-1']);
    });

    testWidgets('hydrates editable fields and updates state and links', (
      tester,
    ) async {
      final repository = _ScreenGoalRepository(
        goal: _goal(
          descripcion: 'Rutina estable',
          fechaObjetivo: DateTime(2026, 12, 31),
          habitIds: const ['hab-1'],
        ),
      );
      await _pumpForm(tester, repository, goalId: 'goal-1');

      expect(find.text('Editar meta'), findsOneWidget);
      expect(find.text('31/12/2026'), findsOneWidget);
      expect(find.text('En curso'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre'),
        'Descansar mejor',
      );
      await tester.tap(find.text('En curso'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pausada').last);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -350));
      await tester.pump();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Caminar'));
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(repository.updatedName, 'Descansar mejor');
      expect(repository.updatedState, MetaEstado.pausada);
      expect(repository.linkedHabitIds, ['hab-2']);
      expect(repository.unlinkedHabitIds, isEmpty);
    });

    testWidgets('keeps form values visible after a failed save', (
      tester,
    ) async {
      final repository = _ScreenGoalRepository()
        ..failure = const ApiException(
          statusCode: 409,
          code: 'META_INVALIDA',
          message: 'La meta no se pudo guardar.',
        );
      await _pumpForm(tester, repository);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre'),
        'Conservar este texto',
      );
      await tester.tap(find.widgetWithText(TextButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Conservar este texto'), findsOneWidget);
      expect(find.text('La meta no se pudo guardar.'), findsOneWidget);
    });
  });

  group('GoalDetailScreen', () {
    testWidgets('shows details and synchronizes selected habits', (
      tester,
    ) async {
      final repository = _ScreenGoalRepository(
        goal: _goal(
          descripcion: 'Rutina estable',
          fechaObjetivo: DateTime(2026, 12, 31),
          habitIds: const ['hab-1'],
        ),
      );
      await _pump(
        tester,
        const GoalDetailScreen(goalId: 'goal-1'),
        overrides: [
          goalRepositoryProvider.overrideWithValue(repository),
          habitsListProvider.overrideWith(
            (ref) async => [
              _habit(),
              _habit(id: 'hab-2', nombre: 'Caminar', metaId: 'goal-2'),
            ],
          ),
        ],
      );

      expect(find.text('Rutina estable'), findsOneWidget);
      expect(find.text('Fecha objetivo'), findsOneWidget);
      expect(find.text('Leer'), findsOneWidget);

      await tester.tap(find.text('Gestionar'));
      await tester.pumpAndSettle();
      expect(
        find.text('Vinculado a otra meta; se reasignará.'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Leer'));
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Caminar'));
      await tester.tap(find.text('Guardar vínculos'));
      await tester.pumpAndSettle();

      expect(repository.linkedHabitIds, ['hab-2']);
      expect(repository.unlinkedHabitIds, ['hab-1']);
      expect(find.text('Hábitos de la meta actualizados.'), findsOneWidget);
    });

    testWidgets('offers retry when detail fails', (tester) async {
      final repository = _ScreenGoalRepository()..detailFails = true;
      await _pump(
        tester,
        const GoalDetailScreen(goalId: 'goal-1'),
        overrides: [goalRepositoryProvider.overrideWithValue(repository)],
      );
      expect(find.text('Reintentar'), findsOneWidget);
    });

    testWidgets('offers retry when habits fail', (tester) async {
      final repository = _ScreenGoalRepository();
      await _pump(
        tester,
        const GoalDetailScreen(goalId: 'goal-1'),
        overrides: [
          goalRepositoryProvider.overrideWithValue(repository),
          habitsListProvider.overrideWith(
            (ref) => Future<List<Habito>>.error(Exception('offline')),
          ),
        ],
      );
      expect(find.text('Reintentar hábitos'), findsOneWidget);
    });
  });

  testWidgets('goal list and detail fit a 320px viewport', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _ScreenGoalRepository(
      goal: _goal(
        descripcion: 'Rutina estable',
        fechaObjetivo: DateTime(2026, 12, 31),
        habitIds: const ['hab-1'],
      ),
    );

    await _pump(
      tester,
      const GoalsListScreen(),
      overrides: [
        goalsListProvider.overrideWith((ref) async => [repository.goal]),
      ],
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    await _pump(
      tester,
      const GoalDetailScreen(goalId: 'goal-1'),
      overrides: [
        goalRepositoryProvider.overrideWithValue(repository),
        habitsListProvider.overrideWith((ref) async => [_habit()]),
      ],
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const <Override>[],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(home: child),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpForm(
  WidgetTester tester,
  _ScreenGoalRepository repository, {
  String? goalId,
}) {
  return _pump(
    tester,
    GoalFormScreen(goalId: goalId),
    overrides: [
      goalRepositoryProvider.overrideWithValue(repository),
      habitsListProvider.overrideWith(
        (ref) async => [
          _habit(),
          _habit(id: 'hab-2', nombre: 'Caminar', metaId: 'goal-2'),
        ],
      ),
    ],
  );
}

class _ScreenGoalRepository implements GoalRepository {
  _ScreenGoalRepository({Meta? goal}) : goal = goal ?? _goal();

  Meta goal;
  Object? failure;
  bool detailFails = false;
  String? createdName;
  String? createdDescription;
  List<String>? createdHabitIds;
  String? updatedName;
  MetaEstado? updatedState;
  final linkedHabitIds = <String>[];
  final unlinkedHabitIds = <String>[];

  void _throwIfNeeded() {
    if (failure case final error?) throw error;
  }

  @override
  Future<List<Meta>> listGoals({MetaEstado? estado}) async => [goal];

  @override
  Future<Meta> getGoal(String goalId) async {
    if (detailFails) throw Exception('offline');
    return goal;
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
    createdHabitIds = habitoIds;
    return goal;
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
    updatedState = estado;
    return goal;
  }

  @override
  Future<Meta> linkHabit(String goalId, String habitId) async {
    _throwIfNeeded();
    linkedHabitIds.add(habitId);
    return goal;
  }

  @override
  Future<Meta> unlinkHabit(String goalId, String habitId) async {
    _throwIfNeeded();
    unlinkedHabitIds.add(habitId);
    return goal;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Meta _goal({
  String id = 'goal-1',
  String nombre = 'Dormir mejor',
  String? descripcion,
  DateTime? fechaObjetivo,
  MetaEstado estado = MetaEstado.enProgreso,
  List<String> habitIds = const [],
}) {
  return Meta(
    id: id,
    usuarioId: 'user-1',
    nombre: nombre,
    descripcion: descripcion,
    fechaObjetivo: fechaObjetivo,
    estado: estado,
    habitoIds: habitIds,
    fechaCreacion: DateTime.utc(2026, 7, 1),
    fechaActualizacion: DateTime.utc(2026, 7, 28),
  );
}

Habito _habit({
  String id = 'hab-1',
  String nombre = 'Leer',
  String? metaId = 'goal-1',
}) {
  return Habito(
    id: id,
    usuarioId: 'user-1',
    nombre: nombre,
    metaId: metaId,
    fechaInicio: DateTime(2026, 7, 28),
    frecuencia: Frecuencia.diaria(),
    estado: HabitoEstado.activo,
    pausas: const [],
    fechaCreacion: DateTime.utc(2026, 7, 1),
    fechaActualizacion: DateTime.utc(2026, 7, 28),
  );
}
