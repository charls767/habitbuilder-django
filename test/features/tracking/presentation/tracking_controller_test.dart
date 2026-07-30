import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitbuilder_mobile/core/network/api_exception.dart';
import 'package:habitbuilder_mobile/features/tracking/domain/entities/registro_habito.dart';
import 'package:habitbuilder_mobile/features/tracking/domain/repositories/tracking_repository.dart';
import 'package:habitbuilder_mobile/features/tracking/presentation/providers/tracking_providers.dart';

void main() {
  test('saves a normalized draft and invalidates only its day', () async {
    final repository = _FakeTrackingRepository();
    final container = _container(repository);
    addTearDown(container.dispose);
    final day = DateTime(2026, 7, 30);

    await container.read(trackingLogProvider('habit-1', day).future);
    await container.read(
      trackingLogProvider('habit-1', DateTime(2026, 7, 29)).future,
    );
    final success = await container
        .read(trackingControllerProvider('habit-1').notifier)
        .save(
          date: day,
          status: EstadoRegistro.parcial,
          note: '  Media sesion  ',
        );

    expect(success, isTrue);
    expect(repository.savedDraft?.fecha, day);
    expect(repository.savedDraft?.nota, 'Media sesion');
    await container.read(trackingLogProvider('habit-1', day).future);
    expect(repository.listCalls['2026-07-30'], 2);
    expect(repository.listCalls['2026-07-29'], 1);
  });

  test('turns a blank note into null', () async {
    final repository = _FakeTrackingRepository();
    final container = _container(repository);
    addTearDown(container.dispose);

    await container
        .read(trackingControllerProvider('habit-1').notifier)
        .save(
          date: DateTime(2026, 7, 30),
          status: EstadoRegistro.completado,
          note: '   ',
        );

    expect(repository.savedDraft?.nota, isNull);
  });

  test('exposes failures and keeps authoritative data cached', () async {
    final repository = _FakeTrackingRepository()
      ..failure = const ApiException(
        statusCode: 409,
        code: 'IDEMPOTENCY_KEY_REUSED',
        message: 'Conflicto de sincronizacion.',
      );
    final container = _container(repository);
    addTearDown(container.dispose);
    final day = DateTime(2026, 7, 30);
    await container.read(trackingLogProvider('habit-1', day).future);

    final success = await container
        .read(trackingControllerProvider('habit-1').notifier)
        .save(date: day, status: EstadoRegistro.omitido);

    expect(success, isFalse);
    expect(repository.listCalls['2026-07-30'], 1);
    expect(
      container.read(trackingControllerProvider('habit-1')).error,
      repository.failure,
    );
  });

  test('rejects duplicate writes while the first one is pending', () async {
    final repository = _FakeTrackingRepository()
      ..pendingSave = Completer<RegistroHabito>();
    final container = _container(repository);
    addTearDown(container.dispose);
    final subscription = container.listen(
      trackingControllerProvider('habit-1'),
      (_, _) {},
    );
    addTearDown(subscription.close);
    final controller = container.read(
      trackingControllerProvider('habit-1').notifier,
    );

    final first = controller.save(
      date: DateTime(2026, 7, 30),
      status: EstadoRegistro.completado,
    );
    await Future<void>.delayed(Duration.zero);
    final second = await controller.save(
      date: DateTime(2026, 7, 30),
      status: EstadoRegistro.omitido,
    );

    expect(second, isFalse);
    expect(repository.saveCalls, 1);
    repository.pendingSave!.complete(_record());
    expect(await first, isTrue);
  });
}

ProviderContainer _container(_FakeTrackingRepository repository) {
  return ProviderContainer(
    overrides: [trackingRepositoryProvider.overrideWithValue(repository)],
  );
}

RegistroHabito _record({
  DateTime? date,
  EstadoRegistro status = EstadoRegistro.completado,
  String? note,
}) {
  return RegistroHabito(
    id: 'log-1',
    habitId: 'habit-1',
    fecha: date ?? DateTime(2026, 7, 30),
    estado: status,
    nota: note,
  );
}

class _FakeTrackingRepository implements TrackingRepository {
  Object? failure;
  Completer<RegistroHabito>? pendingSave;
  RegistroHabitoDraft? savedDraft;
  int saveCalls = 0;
  final listCalls = <String, int>{};
  final records = <String, RegistroHabito>{};

  @override
  Future<List<RegistroHabito>> listByHabit(
    String habitId, {
    required DateTime from,
    required DateTime to,
  }) async {
    final key = formatLocalDate(from);
    listCalls.update(key, (value) => value + 1, ifAbsent: () => 1);
    return <RegistroHabito>[?records[key]];
  }

  @override
  Future<RegistroHabito> upsert(RegistroHabitoDraft draft) async {
    saveCalls++;
    savedDraft = draft;
    final error = failure;
    if (error != null) throw error;
    if (pendingSave case final pending?) return pending.future;
    final record = _record(
      date: draft.fecha,
      status: draft.estado,
      note: draft.nota,
    );
    records[formatLocalDate(draft.fecha)] = record;
    return record;
  }
}
