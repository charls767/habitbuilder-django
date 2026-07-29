import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitbuilder_mobile/features/habits/domain/entities/frecuencia.dart';
import 'package:habitbuilder_mobile/features/habits/domain/entities/habito.dart';
import 'package:habitbuilder_mobile/features/habits/presentation/providers/habit_providers.dart';
import 'package:habitbuilder_mobile/features/reminders/domain/entities/recordatorio.dart';
import 'package:habitbuilder_mobile/features/reminders/domain/entities/reminder_time.dart';
import 'package:habitbuilder_mobile/features/reminders/domain/repositories/reminder_repository.dart';
import 'package:habitbuilder_mobile/features/reminders/presentation/providers/reminder_providers.dart';
import 'package:habitbuilder_mobile/features/reminders/presentation/screens/reminders_screen.dart';

void main() {
  group('RemindersScreen tracer', () {
    testWidgets('renders loading, empty and error states', (tester) async {
      final pending = Completer<List<Recordatorio>>();
      await _pumpScreen(tester, listFuture: pending.future);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      pending.complete(const []);
      await tester.pumpAndSettle();
      expect(find.text('Aún no tienes recordatorios'), findsOneWidget);
      expect(find.text('Añadir recordatorio'), findsOneWidget);

      await _pumpScreen(
        tester,
        listFuture: Future<List<Recordatorio>>.error(Exception('offline')),
      );
      await tester.pumpAndSettle();
      expect(find.text('No pudimos cargar tus recordatorios.'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });

    testWidgets('creates a valid reminder from the empty state', (
      tester,
    ) async {
      final repository = _FakeReminderRepository();
      await _pumpScreen(tester, repository: repository);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Añadir recordatorio'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mensaje'),
        'Preparar botella',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Hora (HH:mm)'),
        '07:45',
      );
      await tester.tap(find.widgetWithText(FilterChip, 'L'));
      await tester.tap(
        find.widgetWithText(FilledButton, 'Guardar recordatorio'),
      );
      await tester.pumpAndSettle();

      expect(repository.createCalls, 1);
      expect(repository.createdDraft?.mensaje, 'Preparar botella');
      expect(repository.createdDraft?.hora.toString(), '07:45');
      expect(repository.createdDraft?.diasSemana, [1]);
      expect(find.text('Preparar botella'), findsOneWidget);
    });

    testWidgets('renders the successful list state', (tester) async {
      await _pumpScreen(tester, listFuture: Future.value([_reminder()]));
      await tester.pumpAndSettle();

      expect(find.text('08:30'), findsOneWidget);
      expect(find.text('Tomar agua'), findsOneWidget);
      expect(find.text('Lun'), findsOneWidget);
      expect(find.text('Mié'), findsOneWidget);
      expect(find.text('Vie'), findsOneWidget);
    });
  });
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  Future<List<Recordatorio>>? listFuture,
  ReminderRepository? repository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        habitDetailProvider('hab-1').overrideWith((ref) async => _habit()),
        if (listFuture != null)
          remindersListProvider('hab-1').overrideWith((ref) => listFuture),
        if (repository != null)
          reminderRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(home: RemindersScreen(habitId: 'hab-1')),
    ),
  );
}

Habito _habit({HabitoEstado state = HabitoEstado.activo}) {
  return Habito(
    id: 'hab-1',
    usuarioId: 'user-1',
    nombre: 'Tomar agua',
    fechaInicio: DateTime(2026, 7, 29),
    frecuencia: Frecuencia.diaria(),
    estado: state,
    pausas: const [],
    fechaCreacion: DateTime.utc(2026, 7, 29),
    fechaActualizacion: DateTime.utc(2026, 7, 29),
  );
}

Recordatorio _reminder({String id = 'rem-1', String message = 'Tomar agua'}) {
  return Recordatorio(
    id: id,
    habitId: 'hab-1',
    mensaje: message,
    hora: ReminderTime.parse('08:30'),
    diasSemana: const [1, 3, 5],
    activo: true,
  );
}

class _FakeReminderRepository implements ReminderRepository {
  int createCalls = 0;
  ReminderDraft? createdDraft;
  final reminders = <Recordatorio>[];

  @override
  Future<List<Recordatorio>> listByHabit(String habitId) async {
    return List<Recordatorio>.of(reminders);
  }

  @override
  Future<Recordatorio> create({
    required String habitId,
    required ReminderDraft draft,
  }) async {
    createCalls++;
    createdDraft = draft;
    final created = _reminder(message: draft.mensaje);
    reminders.add(created);
    return created;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
