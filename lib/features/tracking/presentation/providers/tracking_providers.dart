import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/dio_client.dart';
import '../../data/datasources/tracking_local_data_source.dart';
import '../../data/datasources/tracking_remote_data_source.dart';
import '../../data/repositories/offline_first_tracking_repository.dart';
import '../../data/repositories/tracking_repository_impl.dart';
import '../../domain/entities/registro_habito.dart';
import '../../domain/repositories/tracking_repository.dart';

part 'tracking_providers.g.dart';

@riverpod
TrackingRemoteDataSource trackingRemoteDataSource(Ref ref) {
  return TrackingRemoteDataSource(ref.watch(dioProvider));
}

@Riverpod(keepAlive: true)
TrackingLocalDataSource trackingLocalDataSource(Ref ref) {
  return SecureTrackingLocalDataSource(const FlutterSecureStorage());
}

@Riverpod(keepAlive: true)
TrackingRepository trackingRemoteRepository(Ref ref) {
  return TrackingRepositoryImpl(ref.watch(trackingRemoteDataSourceProvider));
}

@Riverpod(keepAlive: true)
TrackingRepository trackingRepository(Ref ref) {
  return OfflineFirstTrackingRepository(
    ref.watch(trackingLocalDataSourceProvider),
    ref.watch(trackingRemoteRepositoryProvider),
  );
}

typedef TrackingSyncRequest = Future<TrackingSyncReport> Function();

@Riverpod(keepAlive: true)
TrackingSyncRequest trackingSyncRequest(Ref ref) {
  return () {
    final repository = ref.read(trackingRepositoryProvider);
    if (repository is SyncableTrackingRepository) {
      return repository.syncPending();
    }
    return Future.value(const TrackingSyncReport.empty());
  };
}

typedef TrackingRefreshRequest =
    Future<List<RegistroHabito>> Function(
      String habitId, {
      required DateTime from,
      required DateTime to,
    });

@Riverpod(keepAlive: true)
TrackingRefreshRequest trackingRefreshRequest(Ref ref) {
  return (habitId, {required from, required to}) {
    final repository = ref.read(trackingRepositoryProvider);
    if (repository is SyncableTrackingRepository) {
      return repository.refreshByHabit(habitId, from: from, to: to);
    }
    return repository.listByHabit(habitId, from: from, to: to);
  };
}

@riverpod
Future<RegistroHabito?> trackingLog(
  Ref ref,
  String habitId,
  DateTime date,
) async {
  final normalized = DateTime(date.year, date.month, date.day);
  final records = await ref
      .watch(trackingRepositoryProvider)
      .listByHabit(habitId, from: normalized, to: normalized);
  return records.firstOrNull;
}

@riverpod
class TrackingController extends _$TrackingController {
  late String _habitId;

  @override
  FutureOr<void> build(String habitId) {
    _habitId = habitId;
  }

  Future<bool> save({
    required DateTime date,
    required EstadoRegistro status,
    String? note,
  }) async {
    if (state.isLoading) return false;

    final normalized = DateTime(date.year, date.month, date.day);
    final cleanedNote = note?.trim();
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(trackingRepositoryProvider)
          .upsert(
            RegistroHabitoDraft(
              habitId: _habitId,
              fecha: normalized,
              estado: status,
              nota: cleanedNote == null || cleanedNote.isEmpty
                  ? null
                  : cleanedNote,
            ),
          ),
    );
    if (!state.hasError) {
      ref.invalidate(trackingLogProvider(_habitId, normalized));
      unawaited(_sync(normalized));
    }
    return !state.hasError;
  }

  Future<void> _sync(DateTime date) async {
    try {
      final report = await ref.read(trackingSyncRequestProvider)();
      if (ref.mounted && (report.synced > 0 || report.conflicts > 0)) {
        ref.invalidate(trackingLogProvider(_habitId, date));
      }
    } on Object {
      return;
    }
  }
}
