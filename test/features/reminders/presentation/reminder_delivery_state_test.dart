import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitbuilder_mobile/features/habits/domain/entities/frecuencia.dart';
import 'package:habitbuilder_mobile/features/habits/domain/entities/habito.dart';
import 'package:habitbuilder_mobile/features/habits/presentation/providers/habit_providers.dart';
import 'package:habitbuilder_mobile/features/reminders/application/reminder_reconciliation_coordinator.dart';
import 'package:habitbuilder_mobile/features/reminders/domain/entities/recordatorio.dart';
import 'package:habitbuilder_mobile/features/reminders/domain/entities/reminder_time.dart';
import 'package:habitbuilder_mobile/features/reminders/domain/repositories/reminder_repository.dart';
import 'package:habitbuilder_mobile/features/reminders/presentation/providers/reminder_providers.dart';
import 'package:habitbuilder_mobile/features/reminders/presentation/screens/reminders_screen.dart';

void main() {
  test('provider construction is reconciliation side-effect free', () {
    final recorder = _ReconciliationRecorder();
    final container = ProviderContainer(
      overrides: [
        reminderReconciliationRequestProvider.overrideWithValue(recorder.call),
      ],
    );
    addTearDown(container.dispose);

    container.read(reminderDeliveryStateProvider);

    expect(recorder.requests, isEmpty);
    expect(
      container.read(reminderReconciliationActivationProvider).enabled,
      isFalse,
    );
  });

  test(
    'successful reminder mutations request every D-12 reconciliation',
    () async {
      final repository = _ReminderRepository();
      final recorder = _ReconciliationRecorder();
      final container = ProviderContainer(
        overrides: [
          reminderRepositoryProvider.overrideWithValue(repository),
          habitDetailProvider('habit-1').overrideWith((ref) async => _habit()),
          reminderReconciliationRequestProvider.overrideWithValue(
            recorder.call,
          ),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(
        reminderControllerProvider('habit-1').notifier,
      );
      final active = _reminder(active: true);
      final inactive = _reminder(active: false);

      expect(await controller.create(_draft(active: true)), isTrue);
      expect(
        await controller.updateReminder(
          reminder: active,
          draft: _draft(active: true),
        ),
        isTrue,
      );
      expect(await controller.toggle(inactive, true), isTrue);
      expect(await controller.toggle(active, false), isTrue);
      expect(await controller.delete(active.id), isTrue);

      expect(recorder.requests, [true, false, true, false, false]);
    },
  );

  test('failed reminder mutation never requests reconciliation', () async {
    final repository = _ReminderRepository()..failure = StateError('backend');
    final recorder = _ReconciliationRecorder();
    final container = ProviderContainer(
      overrides: [
        reminderRepositoryProvider.overrideWithValue(repository),
        habitDetailProvider('habit-1').overrideWith((ref) async => _habit()),
        reminderReconciliationRequestProvider.overrideWithValue(recorder.call),
      ],
    );
    addTearDown(container.dispose);

    final success = await container
        .read(reminderControllerProvider('habit-1').notifier)
        .create(_draft(active: true));

    expect(success, isFalse);
    expect(recorder.requests, isEmpty);
  });

  for (final scenario in <(ReminderDeliveryState, String)>[
    (
      const ReminderDeliveryState.denied(),
      'Las notificaciones están desactivadas',
    ),
    (const ReminderDeliveryState.inexact(), 'pueden entregarse con demora'),
    (
      const ReminderDeliveryState.unsupported(),
      'no admite notificaciones locales',
    ),
  ]) {
    testWidgets(
      '${scenario.$1.status.name} remains visible with saved reminders',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            remindersListProvider(
              'habit-1',
            ).overrideWith((ref) async => [_reminder(active: true)]),
            habitDetailProvider(
              'habit-1',
            ).overrideWith((ref) async => _habit()),
          ],
        );
        addTearDown(container.dispose);
        container
            .read(reminderDeliveryStateProvider.notifier)
            .update(scenario.$1);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: RemindersScreen(habitId: 'habit-1')),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining(scenario.$2), findsOneWidget);
        expect(find.text('Tomar agua'), findsWidgets);
        expect(
          find.textContaining('1 recordatorio programado'),
          findsOneWidget,
        );
        expect(find.text('Notificaciones activas'), findsNothing);
      },
    );
  }

  testWidgets('delivery retry requests permission and keeps server data', (
    tester,
  ) async {
    final recorder = _ReconciliationRecorder();
    final container = ProviderContainer(
      overrides: [
        remindersListProvider(
          'habit-1',
        ).overrideWith((ref) async => [_reminder(active: true)]),
        habitDetailProvider('habit-1').overrideWith((ref) async => _habit()),
        reminderReconciliationRequestProvider.overrideWithValue(recorder.call),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(reminderDeliveryStateProvider.notifier)
        .update(const ReminderDeliveryState.denied());

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: RemindersScreen(habitId: 'habit-1')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Permitir y reintentar'));
    await tester.pumpAndSettle();

    expect(recorder.requests, [true]);
    expect(
      container.read(reminderDeliveryStateProvider).status,
      ReminderDeliveryStatus.delivered,
    );
    expect(find.text('Tomar agua'), findsWidgets);
  });
}

final class _ReconciliationRecorder {
  final requests = <bool>[];

  Future<ReminderDeliveryState> call({bool requestPermission = false}) async {
    requests.add(requestPermission);
    return const ReminderDeliveryState.delivered();
  }
}

final class _ReminderRepository implements ReminderRepository {
  Object? failure;

  void _throwIfNeeded() {
    final error = failure;
    if (error != null) throw error;
  }

  @override
  Future<Recordatorio> create({
    required String habitId,
    required ReminderDraft draft,
  }) async {
    _throwIfNeeded();
    return _reminder(active: draft.activo);
  }

  @override
  Future<Recordatorio> update({
    required String reminderId,
    required ReminderDraft draft,
  }) async {
    _throwIfNeeded();
    return _reminder(active: draft.activo);
  }

  @override
  Future<void> delete(String reminderId) async {
    _throwIfNeeded();
  }

  @override
  Future<List<Recordatorio>> listByHabit(String habitId) async => const [];
}

ReminderDraft _draft({required bool active}) {
  return ReminderDraft(
    mensaje: 'Tomar agua',
    hora: ReminderTime.parse('08:30'),
    diasSemana: const [1, 3, 5],
    activo: active,
  );
}

Recordatorio _reminder({required bool active}) {
  return Recordatorio(
    id: 'reminder-1',
    habitId: 'habit-1',
    mensaje: 'Tomar agua',
    hora: ReminderTime.parse('08:30'),
    diasSemana: const [1, 3, 5],
    activo: active,
  );
}

Habito _habit() {
  return Habito(
    id: 'habit-1',
    usuarioId: 'user-1',
    nombre: 'Tomar agua',
    fechaInicio: DateTime(2026, 7, 29),
    frecuencia: Frecuencia.diaria(),
    estado: HabitoEstado.activo,
    pausas: const [],
    fechaCreacion: DateTime.utc(2026, 7, 29),
    fechaActualizacion: DateTime.utc(2026, 7, 29),
  );
}
