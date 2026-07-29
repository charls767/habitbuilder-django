import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitbuilder_mobile/core/network/api_exception.dart';
import 'package:habitbuilder_mobile/features/habits/domain/entities/frecuencia.dart';
import 'package:habitbuilder_mobile/features/habits/domain/entities/habito.dart';
import 'package:habitbuilder_mobile/features/habits/domain/repositories/habit_repository.dart';
import 'package:habitbuilder_mobile/features/habits/presentation/providers/habit_providers.dart';
import 'package:habitbuilder_mobile/features/reminders/domain/entities/recordatorio.dart';
import 'package:habitbuilder_mobile/features/reminders/domain/entities/reminder_time.dart';
import 'package:habitbuilder_mobile/features/reminders/domain/repositories/reminder_repository.dart';
import 'package:habitbuilder_mobile/features/reminders/presentation/providers/reminder_providers.dart';

void main() {
  group('ReminderController create', () {
    test('creates for an active habit and invalidates only its list', () async {
      final repository = _FakeReminderRepository();
      final container = _container(repository, HabitoEstado.activo);
      addTearDown(container.dispose);

      await container.read(remindersListProvider('hab-1').future);
      await container.read(remindersListProvider('hab-2').future);

      final draft = ReminderDraft(
        mensaje: 'Tomar agua',
        hora: ReminderTime.parse('08:30'),
        diasSemana: const [1, 3, 5],
        activo: true,
      );
      final success = await container
          .read(reminderControllerProvider('hab-1').notifier)
          .create(draft);

      expect(success, isTrue);
      expect(repository.createCalls, 1);
      expect(repository.createdHabitId, 'hab-1');
      expect(repository.createdDraft, same(draft));
      await container.read(remindersListProvider('hab-1').future);
      expect(repository.listCalls['hab-1'], 2);
      expect(repository.listCalls['hab-2'], 1);
    });

    for (final state in [HabitoEstado.pausado, HabitoEstado.completado]) {
      test(
        'rejects ${state.apiValue} habits before repository calls',
        () async {
          final repository = _FakeReminderRepository();
          final container = _container(repository, state);
          addTearDown(container.dispose);

          final success = await container
              .read(reminderControllerProvider('hab-1').notifier)
              .create(_draft());

          expect(success, isFalse);
          expect(repository.createCalls, 0);
          expect(
            container.read(reminderControllerProvider('hab-1')).error,
            isA<ReminderEligibilityException>(),
          );
        },
      );
    }

    test(
      'exposes API failure without invalidating authoritative data',
      () async {
        final repository = _FakeReminderRepository()
          ..failure = const ApiException(
            statusCode: 409,
            code: 'RECORDATORIO_DUPLICADO',
            message: 'Ya existe un recordatorio a esa hora.',
          );
        final container = _container(repository, HabitoEstado.activo);
        addTearDown(container.dispose);

        await container.read(remindersListProvider('hab-1').future);
        final success = await container
            .read(reminderControllerProvider('hab-1').notifier)
            .create(_draft());

        expect(success, isFalse);
        expect(repository.createCalls, 1);
        expect(repository.listCalls['hab-1'], 1);
        expect(
          container.read(reminderControllerProvider('hab-1')).error,
          repository.failure,
        );
      },
    );
  });
}

ProviderContainer _container(
  _FakeReminderRepository repository,
  HabitoEstado state,
) {
  return ProviderContainer(
    overrides: [
      reminderRepositoryProvider.overrideWithValue(repository),
      habitRepositoryProvider.overrideWithValue(
        _FakeHabitRepository(_habit(state: state)),
      ),
    ],
  );
}

ReminderDraft _draft() {
  return ReminderDraft(
    mensaje: 'Tomar agua',
    hora: ReminderTime.parse('08:30'),
    diasSemana: const [1, 3, 5],
    activo: true,
  );
}

Recordatorio _reminder(String habitId) {
  return Recordatorio(
    id: 'reminder-${habitId.split('-').last}',
    habitId: habitId,
    mensaje: 'Tomar agua',
    hora: ReminderTime.parse('08:30'),
    diasSemana: const [1, 3, 5],
    activo: true,
  );
}

Habito _habit({String id = 'hab-1', HabitoEstado state = HabitoEstado.activo}) {
  return Habito(
    id: id,
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

class _FakeHabitRepository implements HabitRepository {
  _FakeHabitRepository(this.habit);

  final Habito habit;

  @override
  Future<Habito> getHabit(String habitId) async {
    return _habit(id: habitId, state: habit.estado);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeReminderRepository implements ReminderRepository {
  Object? failure;
  int createCalls = 0;
  String? createdHabitId;
  ReminderDraft? createdDraft;
  final listCalls = <String, int>{};
  final reminders = <String, List<Recordatorio>>{};

  void _throwIfNeeded() {
    final error = failure;
    if (error != null) throw error;
  }

  @override
  Future<List<Recordatorio>> listByHabit(String habitId) async {
    listCalls.update(habitId, (value) => value + 1, ifAbsent: () => 1);
    return List<Recordatorio>.of(reminders[habitId] ?? const []);
  }

  @override
  Future<Recordatorio> create({
    required String habitId,
    required ReminderDraft draft,
  }) async {
    createCalls++;
    createdHabitId = habitId;
    createdDraft = draft;
    _throwIfNeeded();
    final created = _reminder(habitId);
    reminders.putIfAbsent(habitId, () => []).add(created);
    return created;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
