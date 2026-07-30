import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/dio_client.dart';
import '../../data/datasources/tracking_remote_data_source.dart';
import '../../data/repositories/tracking_repository_impl.dart';
import '../../domain/entities/registro_habito.dart';
import '../../domain/repositories/tracking_repository.dart';

part 'tracking_providers.g.dart';

@riverpod
TrackingRemoteDataSource trackingRemoteDataSource(Ref ref) {
  return TrackingRemoteDataSource(ref.watch(dioProvider));
}

@riverpod
TrackingRepository trackingRepository(Ref ref) {
  return TrackingRepositoryImpl(ref.watch(trackingRemoteDataSourceProvider));
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
    }
    return !state.hasError;
  }
}
