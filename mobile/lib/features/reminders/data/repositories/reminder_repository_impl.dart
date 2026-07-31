import '../../domain/entities/recordatorio.dart';
import '../../domain/repositories/reminder_repository.dart';
import '../datasources/reminder_remote_data_source.dart';
import '../models/recordatorio_dto.dart';

class ReminderRepositoryImpl implements ReminderRepository {
  ReminderRepositoryImpl(this._remote);

  final ReminderRemoteDataSource _remote;

  @override
  Future<List<Recordatorio>> listByHabit(String habitId) async {
    final dtos = await _remote.listByHabit(habitId);
    return dtos.map((dto) => dto.toEntity()).toList();
  }

  @override
  Future<Recordatorio> create({
    required String habitId,
    required ReminderDraft draft,
  }) async {
    final dto = await _remote.create(
      habitId,
      ReminderRequestDto.fromDraft(draft),
    );
    return dto.toEntity();
  }

  @override
  Future<Recordatorio> update({
    required String reminderId,
    required ReminderDraft draft,
  }) async {
    final dto = await _remote.update(
      reminderId,
      ReminderRequestDto.fromDraft(draft),
    );
    return dto.toEntity();
  }

  @override
  Future<void> delete(String reminderId) => _remote.delete(reminderId);
}
