import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitbuilder_mobile/features/tracking/data/datasources/tracking_local_data_source.dart';
import 'package:habitbuilder_mobile/features/tracking/domain/entities/registro_habito.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  late _MemorySecureStorage storage;
  late SecureTrackingLocalDataSource local;

  setUp(() {
    storage = _MemorySecureStorage();
    local = SecureTrackingLocalDataSource(storage);
  });

  test('persists a pending write across data source instances', () async {
    final draft = _draft();
    final saved = await local.savePending(draft);
    final restored = SecureTrackingLocalDataSource(storage);

    expect(saved.id, 'local:habit-1:2026-07-30');
    expect(saved.sincronizacion, EstadoSincronizacion.pendiente);
    expect(
      (await restored.listByHabit(
        'habit-1',
        from: DateTime(2026, 7, 30),
        to: DateTime(2026, 7, 30),
      )).single.estado,
      EstadoRegistro.parcial,
    );
    expect((await restored.pendingWrites()).single.key, draft.idempotencyKey);
  });

  test('keeps only the latest write for one habit and day', () async {
    await local.savePending(_draft());
    final edited = _draft(status: EstadoRegistro.omitido, note: 'Cambio local');
    await local.savePending(edited);

    final records = await local.listByHabit(
      'habit-1',
      from: DateTime(2026, 7, 1),
      to: DateTime(2026, 7, 31),
    );
    final queue = await local.pendingWrites();

    expect(records, hasLength(1));
    expect(records.single.id, 'local:habit-1:2026-07-30');
    expect(records.single.estado, EstadoRegistro.omitido);
    expect(queue, hasLength(1));
    expect(queue.single.draft.nota, 'Cambio local');
  });

  test('ignores an obsolete remote acknowledgement', () async {
    final first = PendingTrackingWrite(draft: _draft());
    await local.savePending(first.draft);
    await local.savePending(_draft(status: EstadoRegistro.completado));

    final applied = await local.markSynced(first, _remoteRecord());

    expect(applied, isFalse);
    expect(
      (await local.pendingWrites()).single.draft.estado,
      isNot(first.draft.estado),
    );
    expect(
      (await local.listByHabit(
        'habit-1',
        from: DateTime(2026, 7, 30),
        to: DateTime(2026, 7, 30),
      )).single.sincronizacion,
      EstadoSincronizacion.pendiente,
    );
  });

  test('marks matching writes as synced and removes them from queue', () async {
    final draft = _draft();
    final write = PendingTrackingWrite(draft: draft);
    await local.savePending(draft);

    final applied = await local.markSynced(write, _remoteRecord());

    expect(applied, isTrue);
    expect(await local.pendingWrites(), isEmpty);
    final record = (await local.listByHabit(
      'habit-1',
      from: draft.fecha,
      to: draft.fecha,
    )).single;
    expect(record.id, 'server-log-1');
    expect(record.sincronizacion, EstadoSincronizacion.sincronizado);
  });

  test('persists conflicts and a new edit makes them retryable', () async {
    final draft = _draft();
    final write = PendingTrackingWrite(draft: draft);
    await local.savePending(draft);

    await local.markFailed(write, 'Conflicto', conflict: true);

    expect(await local.pendingWrites(), isEmpty);
    final conflicted = (await local.pendingWrites(
      includeConflicts: true,
    )).single;
    expect(conflicted.attempts, 1);
    expect(conflicted.lastError, 'Conflicto');
    expect(conflicted.hasConflict, isTrue);
    expect(
      (await local.listByHabit(
        'habit-1',
        from: draft.fecha,
        to: draft.fecha,
      )).single.sincronizacion,
      EstadoSincronizacion.conflicto,
    );

    await local.savePending(draft);
    expect((await local.pendingWrites()).single.hasConflict, isFalse);
  });

  test('remote refresh never overwrites an unsynced local edit', () async {
    await local.savePending(_draft(status: EstadoRegistro.omitido));

    await local.cacheRemote([_remoteRecord()]);

    final record = (await local.listByHabit(
      'habit-1',
      from: DateTime(2026, 7, 30),
      to: DateTime(2026, 7, 30),
    )).single;
    expect(record.estado, EstadoRegistro.omitido);
    expect(record.sincronizacion, EstadoSincronizacion.pendiente);
  });

  test('recovers safely from a malformed persisted state', () async {
    storage.values['tracking.offline_state.v1'] =
        '{"records":[{"syncStatus":"unknown"}],"queue":[]}';

    expect(
      await local.listByHabit(
        'habit-1',
        from: DateTime(2026, 7, 30),
        to: DateTime(2026, 7, 30),
      ),
      isEmpty,
    );
  });
}

RegistroHabitoDraft _draft({
  EstadoRegistro status = EstadoRegistro.parcial,
  String? note,
}) {
  return RegistroHabitoDraft(
    habitId: 'habit-1',
    fecha: DateTime(2026, 7, 30, 22),
    estado: status,
    nota: note,
  );
}

RegistroHabito _remoteRecord() {
  return RegistroHabito(
    id: 'server-log-1',
    habitId: 'habit-1',
    fecha: DateTime(2026, 7, 30),
    estado: EstadoRegistro.parcial,
  );
}

class _MemorySecureStorage extends Mock implements FlutterSecureStorage {
  _MemorySecureStorage() {
    when(() => read(key: any(named: 'key'))).thenAnswer((invocation) async {
      return values[invocation.namedArguments[#key] as String];
    });
    when(
      () => write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((invocation) async {
      final key = invocation.namedArguments[#key] as String;
      final value = invocation.namedArguments[#value] as String?;
      if (value == null) {
        values.remove(key);
      } else {
        values[key] = value;
      }
    });
  }

  final values = <String, String>{};
}
