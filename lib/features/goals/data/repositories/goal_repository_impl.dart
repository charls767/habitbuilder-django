import '../../domain/entities/meta.dart';
import '../../domain/repositories/goal_repository.dart';
import '../datasources/goal_remote_data_source.dart';
import '../models/meta_dto.dart';

class GoalRepositoryImpl implements GoalRepository {
  GoalRepositoryImpl(this._remote);

  final GoalRemoteDataSource _remote;

  @override
  Future<List<Meta>> listGoals({MetaEstado? estado}) async {
    final dtos = await _remote.listGoals(estado: estado?.apiValue);
    return dtos.map((dto) => dto.toEntity()).toList();
  }

  @override
  Future<Meta> getGoal(String goalId) async {
    final dto = await _remote.getGoal(goalId);
    return dto.toEntity();
  }

  @override
  Future<Meta> createGoal({
    required String nombre,
    String? descripcion,
    DateTime? fechaObjetivo,
    List<String> habitoIds = const [],
  }) async {
    final dto = await _remote.createGoal(
      MetaCreateRequestDto(
        nombre: nombre,
        descripcion: descripcion,
        fechaObjetivo: fechaObjetivo,
        habitoIds: habitoIds,
      ),
    );
    return dto.toEntity();
  }

  @override
  Future<Meta> updateGoal({
    required String goalId,
    String? nombre,
    GoalPatchValue<String?> descripcion =
        const GoalPatchValue<String?>.absent(),
    GoalPatchValue<DateTime?> fechaObjetivo =
        const GoalPatchValue<DateTime?>.absent(),
    MetaEstado? estado,
  }) async {
    final request = MetaUpdateRequestDto(
      nombre: nombre,
      descripcion: descripcion,
      fechaObjetivo: fechaObjetivo,
      estado: estado,
    );
    if (!request.hasChanges) {
      throw ArgumentError('updateGoal requiere al menos un cambio.');
    }

    final dto = await _remote.updateGoal(goalId, request);
    return dto.toEntity();
  }

  @override
  Future<void> deleteGoal(String goalId) => _remote.deleteGoal(goalId);

  @override
  Future<Meta> linkHabit(String goalId, String habitId) async {
    final dto = await _remote.linkHabit(goalId, habitId);
    return dto.toEntity();
  }

  @override
  Future<Meta> unlinkHabit(String goalId, String habitId) async {
    final dto = await _remote.unlinkHabit(goalId, habitId);
    return dto.toEntity();
  }
}
