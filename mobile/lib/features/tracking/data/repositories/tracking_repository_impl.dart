import '../../domain/entities/registro_habito.dart';
import '../../domain/repositories/tracking_repository.dart';
import '../datasources/tracking_remote_data_source.dart';
import '../models/registro_habito_dto.dart';

class TrackingRepositoryImpl implements TrackingRepository {
  const TrackingRepositoryImpl(this._remote);

  final TrackingRemoteDataSource _remote;

  @override
  Future<List<RegistroHabito>> listByHabit(
    String habitId, {
    required DateTime from,
    required DateTime to,
  }) async {
    final records = await _remote.listByHabit(habitId, from: from, to: to);
    return records.map((record) => record.toEntity()).toList(growable: false);
  }

  @override
  Future<RegistroHabito> upsert(RegistroHabitoDraft draft) async {
    final record = await _remote.upsert(
      draft,
      RegistroHabitoRequestDto.fromDraft(draft),
    );
    return record.toEntity();
  }
}
