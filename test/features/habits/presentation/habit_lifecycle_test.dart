import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitbuilder_mobile/core/network/api_exception.dart';
import 'package:habitbuilder_mobile/features/habits/domain/entities/frecuencia.dart';
import 'package:habitbuilder_mobile/features/habits/domain/entities/habito.dart';
import 'package:habitbuilder_mobile/features/habits/domain/repositories/habit_repository.dart';
import 'package:habitbuilder_mobile/features/habits/presentation/providers/habit_providers.dart';
import 'package:habitbuilder_mobile/features/habits/presentation/screens/habits_list_screen.dart';

void main() {
  testWidgets('pause requires confirmation and cancel is side-effect free', (
    tester,
  ) async {
    final repository = _LifecycleRepository();
    await _pumpLifecycle(tester, repository, _habit());

    await _openAction(tester, 'Pausar');
    expect(find.text('¿Pausar hábito?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(repository.pauseCalls, 0);

    await _openAction(tester, 'Pausar');
    await tester.tap(find.widgetWithText(FilledButton, 'Pausar'));
    await tester.pumpAndSettle();

    expect(repository.pauseCalls, 1);
    expect(repository.pauseStart, isNotNull);
    expect(find.text('Hábito pausado.'), findsOneWidget);
  });

  testWidgets('complete and delete display explicit impact confirmations', (
    tester,
  ) async {
    final repository = _LifecycleRepository();
    await _pumpLifecycle(tester, repository, _habit());

    await _openAction(tester, 'Completar');
    expect(find.text('¿Completar hábito?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Completar'));
    await tester.pumpAndSettle();
    expect(repository.completeCalls, 1);

    await _openAction(tester, 'Eliminar');
    expect(find.textContaining('reportes relacionados'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
    await tester.pumpAndSettle();

    expect(repository.deleteCalls, 1);
    expect(find.text('Hábito eliminado.'), findsOneWidget);
  });

  testWidgets('failed lifecycle action keeps the habit and offers retry', (
    tester,
  ) async {
    final repository = _LifecycleRepository()
      ..failure = const ApiException(
        statusCode: 409,
        code: 'TRANSICION_INVALIDA',
        message: 'El hábito ya cambió de estado.',
      );
    await _pumpLifecycle(tester, repository, _habit());

    await _openAction(tester, 'Pausar');
    await tester.tap(find.widgetWithText(FilledButton, 'Pausar'));
    await tester.pumpAndSettle();

    expect(find.text('Leer'), findsOneWidget);
    expect(find.text('El hábito ya cambió de estado.'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('paused habits can be resumed through confirmation', (
    tester,
  ) async {
    final repository = _LifecycleRepository();
    await _pumpLifecycle(
      tester,
      repository,
      _habit(estado: HabitoEstado.pausado),
    );

    await _openAction(tester, 'Reanudar');
    expect(find.text('¿Reanudar hábito?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Reanudar'));
    await tester.pumpAndSettle();

    expect(repository.resumeCalls, 1);
    expect(find.text('Hábito reanudado.'), findsOneWidget);
  });
}

Future<void> _pumpLifecycle(
  WidgetTester tester,
  _LifecycleRepository repository,
  Habito habit,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        habitRepositoryProvider.overrideWithValue(repository),
        habitsListProvider.overrideWith((ref) async => [habit]),
      ],
      child: const MaterialApp(home: HabitsListScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openAction(WidgetTester tester, String action) async {
  await tester.tap(find.byTooltip('Más acciones para Leer'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(action));
  await tester.pumpAndSettle();
}

Habito _habit({HabitoEstado estado = HabitoEstado.activo}) {
  return Habito(
    id: 'hab_1',
    usuarioId: 'usr_1',
    nombre: 'Leer',
    fechaInicio: DateTime(2026, 7, 28),
    frecuencia: Frecuencia.diaria(),
    estado: estado,
    pausas: const [],
    fechaCreacion: DateTime.utc(2026, 7, 28),
    fechaActualizacion: DateTime.utc(2026, 7, 28),
  );
}

class _LifecycleRepository implements HabitRepository {
  Object? failure;
  int pauseCalls = 0;
  int resumeCalls = 0;
  int completeCalls = 0;
  int deleteCalls = 0;
  DateTime? pauseStart;

  void _throwIfNeeded() {
    final error = failure;
    if (error != null) throw error;
  }

  @override
  Future<Habito> pauseHabit(
    String habitId,
    DateTime fechaInicio, {
    DateTime? fechaFin,
  }) async {
    _throwIfNeeded();
    pauseCalls++;
    pauseStart = fechaInicio;
    return _habit(estado: HabitoEstado.pausado);
  }

  @override
  Future<Habito> resumeHabit(String habitId) async {
    _throwIfNeeded();
    resumeCalls++;
    return _habit();
  }

  @override
  Future<Habito> completeHabit(String habitId) async {
    _throwIfNeeded();
    completeCalls++;
    return _habit(estado: HabitoEstado.completado);
  }

  @override
  Future<void> deleteHabit(String habitId) async {
    _throwIfNeeded();
    deleteCalls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
