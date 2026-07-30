import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/entities/registro_habito.dart';

class PendingTrackingWrite {
  const PendingTrackingWrite({
    required this.draft,
    this.attempts = 0,
    this.lastError,
    this.hasConflict = false,
  });

  final RegistroHabitoDraft draft;
  final int attempts;
  final String? lastError;
  final bool hasConflict;

  String get key => draft.idempotencyKey;

  bool hasSamePayload(PendingTrackingWrite other) {
    return key == other.key &&
        draft.estado == other.draft.estado &&
        draft.nota == other.draft.nota;
  }

  PendingTrackingWrite failed(String error, {required bool conflict}) {
    return PendingTrackingWrite(
      draft: draft,
      attempts: attempts + 1,
      lastError: error,
      hasConflict: conflict,
    );
  }
}

abstract interface class TrackingLocalDataSource {
  Future<List<RegistroHabito>> listByHabit(
    String habitId, {
    required DateTime from,
    required DateTime to,
  });

  Future<RegistroHabito> savePending(RegistroHabitoDraft draft);

  Future<List<PendingTrackingWrite>> pendingWrites({
    bool includeConflicts = false,
  });

  Future<bool> markSynced(
    PendingTrackingWrite write,
    RegistroHabito remoteRecord,
  );

  Future<void> markFailed(
    PendingTrackingWrite write,
    String error, {
    required bool conflict,
  });

  Future<void> cacheRemote(List<RegistroHabito> records);
}

class SecureTrackingLocalDataSource implements TrackingLocalDataSource {
  SecureTrackingLocalDataSource(this._storage);

  static const _stateKey = 'tracking.offline_state.v1';

  final FlutterSecureStorage _storage;
  Future<void> _tail = Future.value();

  @override
  Future<List<RegistroHabito>> listByHabit(
    String habitId, {
    required DateTime from,
    required DateTime to,
  }) {
    return _serialized(() async {
      final state = await _readState();
      final fromDate = _dateOnly(from);
      final toDate = _dateOnly(to);
      final records =
          state.records
              .where(
                (record) =>
                    record.habitId == habitId &&
                    !record.fecha.isBefore(fromDate) &&
                    !record.fecha.isAfter(toDate),
              )
              .toList(growable: false)
            ..sort((left, right) => left.fecha.compareTo(right.fecha));
      return records;
    });
  }

  @override
  Future<RegistroHabito> savePending(RegistroHabitoDraft draft) {
    return _serialized(() async {
      final state = await _readState();
      final key = draft.idempotencyKey;
      final existing = state.recordFor(key);
      final record = RegistroHabito(
        id: existing?.id ?? 'local:$key',
        habitId: draft.habitId,
        fecha: draft.fecha,
        estado: draft.estado,
        nota: draft.nota,
        sincronizacion: EstadoSincronizacion.pendiente,
      );
      state.replaceRecord(record);
      state.replaceWrite(PendingTrackingWrite(draft: draft));
      await _writeState(state);
      return record;
    });
  }

  @override
  Future<List<PendingTrackingWrite>> pendingWrites({
    bool includeConflicts = false,
  }) {
    return _serialized(() async {
      final state = await _readState();
      return state.queue
          .where((write) => includeConflicts || !write.hasConflict)
          .toList(growable: false);
    });
  }

  @override
  Future<bool> markSynced(
    PendingTrackingWrite write,
    RegistroHabito remoteRecord,
  ) {
    return _serialized(() async {
      final state = await _readState();
      final current = state.writeFor(write.key);
      if (current == null || !current.hasSamePayload(write)) return false;

      state.removeWrite(write.key);
      state.removeRecord(write.key);
      state.replaceRecord(
        RegistroHabito(
          id: remoteRecord.id,
          habitId: write.draft.habitId,
          fecha: write.draft.fecha,
          estado: remoteRecord.estado,
          nota: remoteRecord.nota,
          sincronizacion: EstadoSincronizacion.sincronizado,
        ),
      );
      await _writeState(state);
      return true;
    });
  }

  @override
  Future<void> markFailed(
    PendingTrackingWrite write,
    String error, {
    required bool conflict,
  }) {
    return _serialized(() async {
      final state = await _readState();
      final current = state.writeFor(write.key);
      if (current == null || !current.hasSamePayload(write)) return;

      state.replaceWrite(current.failed(error, conflict: conflict));
      if (conflict) {
        final record = state.recordFor(write.key);
        if (record != null) {
          state.replaceRecord(
            record.copyWith(sincronizacion: EstadoSincronizacion.conflicto),
          );
        }
      }
      await _writeState(state);
    });
  }

  @override
  Future<void> cacheRemote(List<RegistroHabito> records) {
    return _serialized(() async {
      final state = await _readState();
      for (final record in records) {
        final key = _recordKey(record);
        if (state.writeFor(key) != null) continue;
        state.replaceRecord(
          record.copyWith(sincronizacion: EstadoSincronizacion.sincronizado),
        );
      }
      await _writeState(state);
    });
  }

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (_, _) {});
    return result;
  }

  Future<_TrackingState> _readState() async {
    final encoded = await _storage.read(key: _stateKey);
    if (encoded == null || encoded.isEmpty) return _TrackingState.empty();
    try {
      return _TrackingState.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );
    } on FormatException {
      return _TrackingState.empty();
    } on TypeError {
      return _TrackingState.empty();
    } on ArgumentError {
      return _TrackingState.empty();
    }
  }

  Future<void> _writeState(_TrackingState state) {
    return _storage.write(key: _stateKey, value: jsonEncode(state.toJson()));
  }
}

class _TrackingState {
  _TrackingState({required this.records, required this.queue});

  factory _TrackingState.empty() {
    return _TrackingState(records: [], queue: []);
  }

  factory _TrackingState.fromJson(Map<String, dynamic> json) {
    final records = (json['records'] as List<dynamic>? ?? const [])
        .map((item) => _recordFromJson(item as Map<String, dynamic>))
        .toList();
    final queue = (json['queue'] as List<dynamic>? ?? const [])
        .map((item) => _writeFromJson(item as Map<String, dynamic>))
        .toList();
    return _TrackingState(records: records, queue: queue);
  }

  final List<RegistroHabito> records;
  final List<PendingTrackingWrite> queue;

  RegistroHabito? recordFor(String key) {
    return records.where((record) => _recordKey(record) == key).firstOrNull;
  }

  PendingTrackingWrite? writeFor(String key) {
    return queue.where((write) => write.key == key).firstOrNull;
  }

  void replaceRecord(RegistroHabito record) {
    records.removeWhere((item) => _recordKey(item) == _recordKey(record));
    records.add(record);
  }

  void removeRecord(String key) {
    records.removeWhere((record) => _recordKey(record) == key);
  }

  void replaceWrite(PendingTrackingWrite write) {
    queue.removeWhere((item) => item.key == write.key);
    queue.add(write);
  }

  void removeWrite(String key) {
    queue.removeWhere((write) => write.key == key);
  }

  Map<String, dynamic> toJson() {
    return {
      'version': 1,
      'records': records.map(_recordToJson).toList(growable: false),
      'queue': queue.map(_writeToJson).toList(growable: false),
    };
  }
}

Map<String, dynamic> _recordToJson(RegistroHabito record) {
  return {
    'id': record.id,
    'habitId': record.habitId,
    'date': formatLocalDate(record.fecha),
    'status': record.estado.apiValue,
    'note': record.nota,
    'syncStatus': record.sincronizacion.name,
  };
}

RegistroHabito _recordFromJson(Map<String, dynamic> json) {
  return RegistroHabito(
    id: json['id'] as String,
    habitId: json['habitId'] as String,
    fecha: DateTime.parse(json['date'] as String),
    estado: EstadoRegistro.fromApiValue(json['status'] as String),
    nota: json['note'] as String?,
    sincronizacion: EstadoSincronizacion.values.byName(
      json['syncStatus'] as String,
    ),
  );
}

Map<String, dynamic> _writeToJson(PendingTrackingWrite write) {
  return {
    'habitId': write.draft.habitId,
    'date': formatLocalDate(write.draft.fecha),
    'status': write.draft.estado.apiValue,
    'note': write.draft.nota,
    'attempts': write.attempts,
    'lastError': write.lastError,
    'hasConflict': write.hasConflict,
  };
}

PendingTrackingWrite _writeFromJson(Map<String, dynamic> json) {
  return PendingTrackingWrite(
    draft: RegistroHabitoDraft(
      habitId: json['habitId'] as String,
      fecha: DateTime.parse(json['date'] as String),
      estado: EstadoRegistro.fromApiValue(json['status'] as String),
      nota: json['note'] as String?,
    ),
    attempts: json['attempts'] as int? ?? 0,
    lastError: json['lastError'] as String?,
    hasConflict: json['hasConflict'] as bool? ?? false,
  );
}

String _recordKey(RegistroHabito record) {
  return '${record.habitId}:${formatLocalDate(record.fecha)}';
}

DateTime _dateOnly(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}
