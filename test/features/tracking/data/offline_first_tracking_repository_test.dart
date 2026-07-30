import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:habitbuilder_mobile/core/network/api_exception.dart';
import 'package:habitbuilder_mobile/features/tracking/data/datasources/tracking_local_data_source.dart';
import 'package:habitbuilder_mobile/features/tracking/data/repositories/offline_first_tracking_repository.dart';
import 'package:habitbuilder_mobile/features/tracking/domain/entities/registro_habito.dart';
import 'package:habitbuilder_mobile/features/tracking/domain/repositories/tracking_repository.dart';

void main() {
  test(
    'hydrates an empty cache and then reads it without the network',
    () async {
      final local = _MemoryLocalDataSource();
      final remote = _FakeRemoteRepository(records: [_record()]);
      final repository = OfflineFirstTrackingRepository(local, remote);

      final first = await repository.listByHabit(
        'habit-1',
        from: DateTime(2026, 7, 30),
        to: DateTime(2026, 7, 30),
      );
      remote.failure = _networkFailure();
      final cached = await repository.listByHabit(
        'habit-1',
        from: DateTime(2026, 7, 30),
        to: DateTime(2026, 7, 30),
      );

      expect(first.single.id, 'server-log');
      expect(cached.single.id, 'server-log');
      expect(remote.listCalls, 1);
    },
  );

  test('refresh falls back only for transient failures', () async {
    final local = _MemoryLocalDataSource();
    await local.savePending(_draft());
    final remote = _FakeRemoteRepository()..failure = _networkFailure();
    final repository = OfflineFirstTrackingRepository(local, remote);

    expect(
      await repository.refreshByHabit(
        'habit-1',
        from: DateTime(2026, 7, 30),
        to: DateTime(2026, 7, 30),
      ),
      hasLength(1),
    );

    remote.failure = const ApiException(
      statusCode: 403,
      code: 'FORBIDDEN',
      message: 'Sin permiso',
    );
    await expectLater(
      repository.refreshByHabit(
        'habit-1',
        from: DateTime(2026, 7, 30),
        to: DateTime(2026, 7, 30),
      ),
      throwsA(isA<ApiException>()),
    );
  });

  test(
    'local writes return before sync and successful sync drains queue',
    () async {
      final local = _MemoryLocalDataSource();
      final remote = _FakeRemoteRepository();
      final repository = OfflineFirstTrackingRepository(local, remote);

      final saved = await repository.upsert(_draft());
      expect(saved.sincronizacion, EstadoSincronizacion.pendiente);
      expect(remote.upsertCalls, 0);

      final report = await repository.syncPending();

      expect(report.synced, 1);
      expect(report.pending, 0);
      expect(report.conflicts, 0);
      expect(await local.pendingWrites(), isEmpty);
      expect(
        local.records.single.sincronizacion,
        EstadoSincronizacion.sincronizado,
      );
    },
  );

  test('keeps transient failures pending for a later retry', () async {
    final local = _MemoryLocalDataSource();
    final remote = _FakeRemoteRepository()..failure = _networkFailure();
    final repository = OfflineFirstTrackingRepository(local, remote);
    await repository.upsert(_draft());

    final report = await repository.syncPending();

    expect(report.synced, 0);
    expect(report.pending, 1);
    expect(report.conflicts, 0);
    expect((await local.pendingWrites()).single.attempts, 1);
  });

  test('marks permanent client failures as visible conflicts', () async {
    final local = _MemoryLocalDataSource();
    final remote = _FakeRemoteRepository()
      ..failure = const ApiException(
        statusCode: 409,
        code: 'IDEMPOTENCY_KEY_REUSED',
        message: 'Contenido diferente',
      );
    final repository = OfflineFirstTrackingRepository(local, remote);
    await repository.upsert(_draft());

    final report = await repository.syncPending();

    expect(report.pending, 0);
    expect(report.conflicts, 1);
    expect(local.records.single.sincronizacion, EstadoSincronizacion.conflicto);
  });

  test('does not let an in-flight response overwrite a newer edit', () async {
    final local = _MemoryLocalDataSource();
    final firstResponse = Completer<RegistroHabito>();
    final remote = _FakeRemoteRepository(firstResponse: firstResponse);
    final repository = OfflineFirstTrackingRepository(local, remote);
    await repository.upsert(_draft(status: EstadoRegistro.parcial));

    final syncing = repository.syncPending();
    await remote.firstRequest;
    await repository.upsert(_draft(status: EstadoRegistro.omitido));
    firstResponse.complete(_record(status: EstadoRegistro.parcial));
    final report = await syncing;

    expect(remote.upsertCalls, 2);
    expect(report.synced, 1);
    expect(local.records.single.estado, EstadoRegistro.omitido);
    expect(
      local.records.single.sincronizacion,
      EstadoSincronizacion.sincronizado,
    );
    expect(await local.pendingWrites(), isEmpty);
  });
}

RegistroHabitoDraft _draft({
  EstadoRegistro status = EstadoRegistro.completado,
}) {
  return RegistroHabitoDraft(
    habitId: 'habit-1',
    fecha: DateTime(2026, 7, 30),
    estado: status,
  );
}

RegistroHabito _record({EstadoRegistro status = EstadoRegistro.completado}) {
  return RegistroHabito(
    id: 'server-log',
    habitId: 'habit-1',
    fecha: DateTime(2026, 7, 30),
    estado: status,
  );
}

ApiException _networkFailure() {
  return const ApiException(
    statusCode: null,
    code: 'ERROR_RED',
    message: 'Sin conexion',
  );
}

class _FakeRemoteRepository implements TrackingRepository {
  _FakeRemoteRepository({this.records = const [], this.firstResponse});

  final List<RegistroHabito> records;
  final Completer<RegistroHabito>? firstResponse;
  final Completer<void> _firstRequest = Completer<void>();
  Object? failure;
  int listCalls = 0;
  int upsertCalls = 0;

  Future<void> get firstRequest => _firstRequest.future;

  void _throwIfNeeded() {
    final error = failure;
    if (error != null) throw error;
  }

  @override
  Future<List<RegistroHabito>> listByHabit(
    String habitId, {
    required DateTime from,
    required DateTime to,
  }) async {
    listCalls++;
    _throwIfNeeded();
    return List.of(records);
  }

  @override
  Future<RegistroHabito> upsert(RegistroHabitoDraft draft) async {
    upsertCalls++;
    _throwIfNeeded();
    if (!_firstRequest.isCompleted) _firstRequest.complete();
    if (upsertCalls == 1 && firstResponse != null) {
      return firstResponse!.future;
    }
    return _record(status: draft.estado);
  }
}

class _MemoryLocalDataSource implements TrackingLocalDataSource {
  final records = <RegistroHabito>[];
  final queue = <PendingTrackingWrite>[];

  @override
  Future<List<RegistroHabito>> listByHabit(
    String habitId, {
    required DateTime from,
    required DateTime to,
  }) async {
    return records.where((record) => record.habitId == habitId).toList();
  }

  @override
  Future<RegistroHabito> savePending(RegistroHabitoDraft draft) async {
    final key = draft.idempotencyKey;
    final existing = records.where((record) => _key(record) == key).firstOrNull;
    final record = RegistroHabito(
      id: existing?.id ?? 'local:$key',
      habitId: draft.habitId,
      fecha: draft.fecha,
      estado: draft.estado,
      nota: draft.nota,
      sincronizacion: EstadoSincronizacion.pendiente,
    );
    records.removeWhere((item) => _key(item) == key);
    records.add(record);
    queue.removeWhere((item) => item.key == key);
    queue.add(PendingTrackingWrite(draft: draft));
    return record;
  }

  @override
  Future<List<PendingTrackingWrite>> pendingWrites({
    bool includeConflicts = false,
  }) async {
    return queue
        .where((write) => includeConflicts || !write.hasConflict)
        .toList();
  }

  @override
  Future<bool> markSynced(
    PendingTrackingWrite write,
    RegistroHabito remoteRecord,
  ) async {
    final current = queue.where((item) => item.key == write.key).firstOrNull;
    if (current == null || !current.hasSamePayload(write)) return false;
    queue.remove(current);
    records.removeWhere((item) => _key(item) == write.key);
    records.add(remoteRecord);
    return true;
  }

  @override
  Future<void> markFailed(
    PendingTrackingWrite write,
    String error, {
    required bool conflict,
  }) async {
    final current = queue.where((item) => item.key == write.key).firstOrNull;
    if (current == null || !current.hasSamePayload(write)) return;
    queue.remove(current);
    queue.add(current.failed(error, conflict: conflict));
    if (conflict) {
      final index = records.indexWhere((item) => _key(item) == write.key);
      records[index] = records[index].copyWith(
        sincronizacion: EstadoSincronizacion.conflicto,
      );
    }
  }

  @override
  Future<void> cacheRemote(List<RegistroHabito> remoteRecords) async {
    for (final remote in remoteRecords) {
      if (queue.any((write) => write.key == _key(remote))) continue;
      records.removeWhere((item) => _key(item) == _key(remote));
      records.add(remote);
    }
  }
}

String _key(RegistroHabito record) {
  return '${record.habitId}:${formatLocalDate(record.fecha)}';
}
