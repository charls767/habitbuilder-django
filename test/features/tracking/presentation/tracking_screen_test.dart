import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitbuilder_mobile/core/network/api_exception.dart';
import 'package:habitbuilder_mobile/core/theme/app_theme.dart';
import 'package:habitbuilder_mobile/features/habits/domain/entities/frecuencia.dart';
import 'package:habitbuilder_mobile/features/habits/domain/entities/habito.dart';
import 'package:habitbuilder_mobile/features/habits/presentation/providers/habit_providers.dart';
import 'package:habitbuilder_mobile/features/tracking/domain/entities/registro_habito.dart';
import 'package:habitbuilder_mobile/features/tracking/domain/repositories/tracking_repository.dart';
import 'package:habitbuilder_mobile/features/tracking/presentation/providers/tracking_providers.dart';
import 'package:habitbuilder_mobile/features/tracking/presentation/screens/tracking_screen.dart';

void main() {
  testWidgets('shows only active habits and saves every daily status', (
    tester,
  ) async {
    final repository = _FakeTrackingRepository();
    await _pumpScreen(tester, repository: repository);

    expect(find.text('Leer'), findsOneWidget);
    expect(find.text('Pausado'), findsNothing);
    expect(find.text('Terminado'), findsNothing);
    expect(find.text('Hecho'), findsOneWidget);
    expect(find.text('Parcial'), findsOneWidget);
    expect(find.text('Omitido'), findsOneWidget);

    await tester.tap(find.text('Parcial'));
    await tester.pumpAndSettle();

    expect(repository.savedDraft?.estado, EstadoRegistro.parcial);
    expect(find.text('Cumplimiento guardado.'), findsOneWidget);
  });

  testWidgets('edits the note while preserving the selected status', (
    tester,
  ) async {
    final repository = _FakeTrackingRepository(
      initial: _record(note: 'Nota inicial'),
    );
    await _pumpScreen(tester, repository: repository);

    expect(find.text('Nota inicial'), findsOneWidget);
    await tester.tap(find.byTooltip('Editar nota'));
    await tester.pumpAndSettle();
    expect(find.text('Nota del día'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Nota actualizada');
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(repository.savedDraft?.estado, EstadoRegistro.completado);
    expect(repository.savedDraft?.nota, 'Nota actualizada');
    expect(find.text('Nota actualizada'), findsOneWidget);
  });

  testWidgets('asks for a status before adding a note', (tester) async {
    await _pumpScreen(tester, repository: _FakeTrackingRepository());

    await tester.tap(find.byTooltip('Agregar nota'));
    await tester.pump();

    expect(find.text('Selecciona primero un estado.'), findsOneWidget);
  });

  testWidgets('surfaces API failures', (tester) async {
    final repository = _FakeTrackingRepository()
      ..saveFailure = const ApiException(
        statusCode: 409,
        code: 'CONFLICT',
        message: 'No se pudo editar el registro.',
      );
    await _pumpScreen(tester, repository: repository);

    await tester.tap(find.text('Omitido'));
    await tester.pumpAndSettle();
    expect(find.text('No se pudo editar el registro.'), findsOneWidget);
  });

  testWidgets('reloads a record after a list failure', (tester) async {
    final repository = _FakeTrackingRepository()
      ..listFailure = Exception('offline');
    await _pumpScreen(tester, repository: repository);

    expect(find.text('Reintentar carga'), findsOneWidget);
    repository.listFailure = null;
    await tester.tap(find.text('Reintentar carga'));
    await tester.pumpAndSettle();

    expect(find.text('Sin nota'), findsOneWidget);
  });

  testWidgets('renders active controls without overflow at 320x640', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpScreen(tester, repository: _FakeTrackingRepository());
    expect(find.text('Hecho'), findsOneWidget);
    expect(find.text('Parcial'), findsOneWidget);
    expect(find.text('Omitido'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders empty and habits error states', (tester) async {
    await _pumpScreen(
      tester,
      repository: _FakeTrackingRepository(),
      habits: [],
    );
    expect(
      find.text('No tienes hábitos activos para registrar en esta fecha.'),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpScreen(
      tester,
      repository: _FakeTrackingRepository(),
      habitsError: Exception('offline'),
    );
    expect(find.text('Reintentar'), findsOneWidget);
  });
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required _FakeTrackingRepository repository,
  List<Habito>? habits,
  Object? habitsError,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        trackingRepositoryProvider.overrideWithValue(repository),
        habitsListProvider.overrideWith(
          (ref) => habitsError == null
              ? Future.value(
                  habits ??
                      [
                        _habit(),
                        _habit(
                          id: 'habit-2',
                          name: 'Pausado',
                          status: HabitoEstado.pausado,
                        ),
                        _habit(
                          id: 'habit-3',
                          name: 'Terminado',
                          status: HabitoEstado.completado,
                        ),
                      ],
                )
              : Future.error(habitsError),
        ),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: const TrackingScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Habito _habit({
  String id = 'habit-1',
  String name = 'Leer',
  HabitoEstado status = HabitoEstado.activo,
}) {
  return Habito(
    id: id,
    usuarioId: 'user-1',
    nombre: name,
    fechaInicio: DateTime(2026, 7, 30),
    frecuencia: Frecuencia.diaria(),
    estado: status,
    pausas: const [],
    fechaCreacion: DateTime.utc(2026, 7, 30),
    fechaActualizacion: DateTime.utc(2026, 7, 30),
  );
}

RegistroHabito _record({String? note}) {
  final now = DateTime.now();
  return RegistroHabito(
    id: 'log-1',
    habitId: 'habit-1',
    fecha: DateTime(now.year, now.month, now.day),
    estado: EstadoRegistro.completado,
    nota: note,
  );
}

class _FakeTrackingRepository implements TrackingRepository {
  _FakeTrackingRepository({RegistroHabito? initial}) : record = initial;

  RegistroHabito? record;
  RegistroHabitoDraft? savedDraft;
  Object? saveFailure;
  Object? listFailure;

  @override
  Future<List<RegistroHabito>> listByHabit(
    String habitId, {
    required DateTime from,
    required DateTime to,
  }) async {
    final error = listFailure;
    if (error != null) throw error;
    return <RegistroHabito>[?record];
  }

  @override
  Future<RegistroHabito> upsert(RegistroHabitoDraft draft) async {
    savedDraft = draft;
    final error = saveFailure;
    if (error != null) throw error;
    record = RegistroHabito(
      id: record?.id ?? 'log-1',
      habitId: draft.habitId,
      fecha: draft.fecha,
      estado: draft.estado,
      nota: draft.nota,
    );
    return record!;
  }
}
