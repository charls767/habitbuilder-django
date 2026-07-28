import '../../domain/entities/categoria.dart';
import '../../domain/entities/frecuencia.dart';
import '../../domain/entities/habito.dart';
import '../../domain/entities/meta_option.dart';
import '../../domain/repositories/habit_repository.dart';
import '../datasources/habit_remote_data_source.dart';
import '../models/frecuencia_dto.dart';
import '../models/habito_dto.dart';

class HabitRepositoryImpl implements HabitRepository {
  HabitRepositoryImpl(this._remote);

  final HabitRemoteDataSource _remote;

  @override
  Future<List<Categoria>> listCategories() async {
    final dtos = await _remote.listCategories();
    return dtos.map((dto) => dto.toEntity()).toList();
  }

  @override
  Future<List<MetaOption>> listGoalOptions() async {
    final dtos = await _remote.listGoalOptions();
    return dtos.map((dto) => dto.toEntity()).toList();
  }

  @override
  Future<List<Habito>> listHabits({HabitoEstado? estado}) async {
    final dtos = await _remote.listHabits(estado: estado?.apiValue);
    return dtos.map((dto) => dto.toEntity()).toList();
  }

  @override
  Future<Habito> getHabit(String habitId) async {
    final dto = await _remote.getHabit(habitId);
    return dto.toEntity();
  }

  @override
  Future<Habito> createHabit({
    required String nombre,
    required DateTime fechaInicio,
    required Frecuencia frecuencia,
    String? descripcion,
    String? categoriaId,
    String? metaId,
  }) async {
    final dto = await _remote.createHabit(
      HabitoCreateRequestDto(
        nombre: nombre,
        descripcion: descripcion,
        categoriaId: categoriaId,
        metaId: metaId,
        fechaInicio: fechaInicio,
        frecuencia: FrecuenciaDto.fromEntity(frecuencia),
      ),
    );
    return dto.toEntity();
  }

  @override
  Future<Habito> updateHabit({
    required String habitId,
    String? nombre,
    PatchValue<String?> descripcion = const PatchValue<String?>.absent(),
    PatchValue<String?> categoriaId = const PatchValue<String?>.absent(),
    PatchValue<String?> metaId = const PatchValue<String?>.absent(),
    DateTime? fechaInicio,
    Frecuencia? frecuencia,
  }) async {
    final request = HabitoUpdateRequestDto(
      nombre: nombre,
      descripcion: descripcion,
      categoriaId: categoriaId,
      metaId: metaId,
      fechaInicio: fechaInicio,
      frecuencia: frecuencia == null
          ? null
          : FrecuenciaDto.fromEntity(frecuencia),
    );
    if (!request.hasChanges) {
      throw ArgumentError('updateHabit requiere al menos un cambio.');
    }

    final dto = await _remote.updateHabit(habitId, request);
    return dto.toEntity();
  }

  @override
  Future<Habito> pauseHabit(
    String habitId,
    DateTime fechaInicio, {
    DateTime? fechaFin,
  }) async {
    final dto = await _remote.pauseHabit(
      habitId,
      fechaInicio,
      fechaFin: fechaFin,
    );
    return dto.toEntity();
  }

  @override
  Future<Habito> resumeHabit(String habitId) async {
    final dto = await _remote.resumeHabit(habitId);
    return dto.toEntity();
  }

  @override
  Future<Habito> completeHabit(String habitId) async {
    final dto = await _remote.completeHabit(habitId);
    return dto.toEntity();
  }

  @override
  Future<void> deleteHabit(String habitId) => _remote.deleteHabit(habitId);
}
