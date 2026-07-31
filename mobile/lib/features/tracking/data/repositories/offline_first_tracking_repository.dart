import '../../../../core/network/api_exception.dart';
import '../../domain/entities/registro_habito.dart';
import '../../domain/repositories/tracking_repository.dart';
import '../datasources/tracking_local_data_source.dart';

class OfflineFirstTrackingRepository implements SyncableTrackingRepository {
  OfflineFirstTrackingRepository(this._local, this._remote);

  final TrackingLocalDataSource _local;
  final TrackingRepository _remote;
  Future<TrackingSyncReport>? _activeSync;

  @override
  Future<List<RegistroHabito>> listByHabit(
    String habitId, {
    required DateTime from,
    required DateTime to,
  }) async {
    final cached = await _local.listByHabit(habitId, from: from, to: to);
    if (cached.isNotEmpty) return cached;
    return refreshByHabit(habitId, from: from, to: to);
  }

  @override
  Future<List<RegistroHabito>> refreshByHabit(
    String habitId, {
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final remote = await _remote.listByHabit(habitId, from: from, to: to);
      await _local.cacheRemote(remote);
    } on ApiException catch (error) {
      if (!_isTransient(error)) rethrow;
    }
    return _local.listByHabit(habitId, from: from, to: to);
  }

  @override
  Future<RegistroHabito> upsert(RegistroHabitoDraft draft) {
    return _local.savePending(draft);
  }

  @override
  Future<TrackingSyncReport> syncPending() {
    final active = _activeSync;
    if (active != null) return active;

    final operation = _syncPending();
    _activeSync = operation;
    return operation.whenComplete(() => _activeSync = null);
  }

  Future<TrackingSyncReport> _syncPending() async {
    var synced = 0;
    final attemptedPayloads = <String>{};

    while (true) {
      final writes = await _local.pendingWrites();
      final candidates = writes
          .where((write) => attemptedPayloads.add(_payloadKey(write)))
          .toList(growable: false);
      if (candidates.isEmpty) break;

      for (final write in candidates) {
        try {
          final record = await _remote.upsert(write.draft);
          if (await _local.markSynced(write, record)) synced++;
        } on ApiException catch (error) {
          await _local.markFailed(
            write,
            error.message,
            conflict: !_isTransient(error),
          );
        }
      }
    }

    final remaining = await _local.pendingWrites();
    return TrackingSyncReport(
      synced: synced,
      pending: remaining.length,
      conflicts: await _countConflicts(),
    );
  }

  Future<int> _countConflicts() async {
    var conflicts = 0;
    for (final write in await _local.pendingWrites(includeConflicts: true)) {
      if (write.hasConflict) conflicts++;
    }
    return conflicts;
  }
}

bool _isTransient(ApiException error) {
  final status = error.statusCode;
  return status == null ||
      status == 401 ||
      status == 408 ||
      status == 429 ||
      status >= 500;
}

String _payloadKey(PendingTrackingWrite write) {
  return '${write.key}|${write.draft.estado.apiValue}|${write.draft.nota ?? ''}';
}
