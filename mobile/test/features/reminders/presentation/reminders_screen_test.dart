import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitbuilder_mobile/core/network/api_exception.dart';
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

      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpScreen(tester, listError: Exception('offline'));
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

  group('complete CU-006', () {
    testWidgets('failed create preserves every entered value', (tester) async {
      final repository = _FakeReminderRepository()
        ..failure = const ApiException(
          statusCode: 409,
          code: 'RECORDATORIO_DUPLICADO',
          message: 'Ya existe un recordatorio a esa hora.',
        );
      await _pumpScreen(tester, repository: repository);
      await tester.pumpAndSettle();

      await _openCreateForm(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mensaje'),
        'Preparar botella',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Hora (HH:mm)'),
        '07:45',
      );
      await tester.tap(find.widgetWithText(FilterChip, 'L'));
      await tester.tap(find.widgetWithText(FilterChip, 'X'));
      await tester.tap(
        find.widgetWithText(FilledButton, 'Guardar recordatorio'),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Ya existe un recordatorio a esa hora.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Mensaje'),
            )
            .controller
            ?.text,
        'Preparar botella',
      );
      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, 'L'))
            .selected,
        isTrue,
      );
      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, 'X'))
            .selected,
        isTrue,
      );
    });

    testWidgets('edit hydrates once and submits the complete shape', (
      tester,
    ) async {
      final repository = _FakeReminderRepository(reminders: [_reminder()]);
      await _pumpScreen(tester, repository: repository);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tomar agua'));
      await tester.pumpAndSettle();
      expect(find.text('Editar recordatorio'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Mensaje'),
            )
            .controller
            ?.text,
        'Tomar agua',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mensaje'),
        'Tomar dos vasos',
      );
      await tester.pump();
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Mensaje'),
            )
            .controller
            ?.text,
        'Tomar dos vasos',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar cambios'));
      await tester.pumpAndSettle();

      expect(repository.updateCalls, 1);
      expect(repository.updatedReminderId, 'rem-1');
      expect(repository.updatedDraft?.mensaje, 'Tomar dos vasos');
      expect(repository.updatedDraft?.hora.toString(), '08:30');
      expect(repository.updatedDraft?.diasSemana, [1, 3, 5]);
      expect(repository.updatedDraft?.activo, isTrue);
    });

    testWidgets('failed switch rolls back to authoritative value', (
      tester,
    ) async {
      final repository = _FakeReminderRepository(reminders: [_reminder()])
        ..failure = const ApiException(
          statusCode: 409,
          code: 'CAMBIO_RECHAZADO',
          message: 'No pudimos desactivar el recordatorio.',
        );
      await _pumpScreen(tester, repository: repository);
      await tester.pumpAndSettle();

      final toggle = find.byKey(const ValueKey('reminder-toggle-rem-1'));
      await tester.tap(toggle);
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(toggle).value, isTrue);
      expect(
        find.text('No pudimos desactivar el recordatorio.'),
        findsOneWidget,
      );
    });

    testWidgets('paused habit blocks create and reactivate but allows edit', (
      tester,
    ) async {
      final repository = _FakeReminderRepository(
        reminders: [_reminder(active: false)],
      );
      await _pumpScreen(
        tester,
        repository: repository,
        habitState: HabitoEstado.pausado,
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('no crear ni reactivar'), findsOneWidget);
      final toggle = find.byKey(const ValueKey('reminder-toggle-rem-1'));
      expect(tester.widget<Switch>(toggle).onChanged, isNull);
      final addButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Añadir recordatorio'),
      );
      expect(addButton.onPressed, isNull);

      await tester.tap(find.text('Tomar agua'));
      await tester.pumpAndSettle();
      expect(find.text('Editar recordatorio'), findsOneWidget);
    });

    testWidgets('delete removes only after confirmation and success', (
      tester,
    ) async {
      final repository = _FakeReminderRepository(reminders: [_reminder()]);
      await _pumpScreen(tester, repository: repository);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Más acciones para Tomar agua'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      expect(find.text('¿Eliminar recordatorio?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
      await tester.pumpAndSettle();

      expect(repository.deleteCalls, 1);
      expect(find.text('Tomar agua'), findsNothing);
    });

    testWidgets('failed delete keeps the card visible', (tester) async {
      final repository = _FakeReminderRepository(reminders: [_reminder()])
        ..failure = const ApiException(
          statusCode: 409,
          code: 'DELETE_RECHAZADO',
          message: 'No pudimos eliminar el recordatorio.',
        );
      await _pumpScreen(tester, repository: repository);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Más acciones para Tomar agua'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
      await tester.pumpAndSettle();

      expect(find.text('Tomar agua'), findsOneWidget);
      expect(find.text('No pudimos eliminar el recordatorio.'), findsOneWidget);
    });

    testWidgets('prevents duplicate form submits while create is pending', (
      tester,
    ) async {
      final repository = _FakeReminderRepository()
        ..pendingCreate = Completer<Recordatorio>();
      await _pumpScreen(tester, repository: repository);
      await tester.pumpAndSettle();
      await _openCreateForm(tester);
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
      await tester.pump();

      expect(repository.createCalls, 1);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('reminder-form-submit')),
            )
            .onPressed,
        isNull,
      );
      repository.pendingCreate!.complete(_reminder());
      await tester.pumpAndSettle();
      expect(repository.createCalls, 1);
    });

    testWidgets('is accessible without overflow at 320x640', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      final repository = _FakeReminderRepository(
        reminders: [
          _reminder(),
          _reminder(
            id: 'rem-2',
            message: 'Un mensaje deliberadamente largo para el recordatorio',
            active: false,
          ),
        ],
      );

      await _pumpScreen(tester, repository: repository);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.bySemanticsLabel('Recordatorio Tomar agua a las 08:30, activo'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text('Añadir recordatorio'),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Añadir recordatorio'), findsOneWidget);
      semantics.dispose();
    });
  });
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  Future<List<Recordatorio>>? listFuture,
  Object? listError,
  ReminderRepository? repository,
  HabitoEstado habitState = HabitoEstado.activo,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        habitDetailProvider(
          'hab-1',
        ).overrideWith((ref) async => _habit(state: habitState)),
        if (listFuture != null)
          remindersListProvider('hab-1').overrideWith((ref) => listFuture),
        if (listError != null)
          remindersListProvider(
            'hab-1',
          ).overrideWith((ref) => Future.error(listError)),
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

Recordatorio _reminder({
  String id = 'rem-1',
  String message = 'Tomar agua',
  bool active = true,
}) {
  return Recordatorio(
    id: id,
    habitId: 'hab-1',
    mensaje: message,
    hora: ReminderTime.parse('08:30'),
    diasSemana: const [1, 3, 5],
    activo: active,
  );
}

Future<void> _openCreateForm(WidgetTester tester) async {
  await tester.tap(find.text('Añadir recordatorio'));
  await tester.pumpAndSettle();
}

class _FakeReminderRepository implements ReminderRepository {
  _FakeReminderRepository({List<Recordatorio> reminders = const []})
    : reminders = List<Recordatorio>.of(reminders);

  Object? failure;
  int createCalls = 0;
  int updateCalls = 0;
  int deleteCalls = 0;
  ReminderDraft? createdDraft;
  String? updatedReminderId;
  ReminderDraft? updatedDraft;
  Completer<Recordatorio>? pendingCreate;
  final List<Recordatorio> reminders;

  void _throwIfNeeded() {
    final error = failure;
    if (error != null) throw error;
  }

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
    _throwIfNeeded();
    if (pendingCreate case final pending?) return pending.future;
    final created = _reminder(message: draft.mensaje);
    reminders.add(created);
    return created;
  }

  @override
  Future<Recordatorio> update({
    required String reminderId,
    required ReminderDraft draft,
  }) async {
    updateCalls++;
    updatedReminderId = reminderId;
    updatedDraft = draft;
    _throwIfNeeded();
    final index = reminders.indexWhere((item) => item.id == reminderId);
    final updated = Recordatorio(
      id: reminderId,
      habitId: 'hab-1',
      mensaje: draft.mensaje,
      hora: draft.hora,
      diasSemana: draft.diasSemana,
      activo: draft.activo,
    );
    if (index >= 0) reminders[index] = updated;
    return updated;
  }

  @override
  Future<void> delete(String reminderId) async {
    deleteCalls++;
    _throwIfNeeded();
    reminders.removeWhere((item) => item.id == reminderId);
  }
}
