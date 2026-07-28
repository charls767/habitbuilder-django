import '../entities/categoria.dart';
import '../entities/frecuencia.dart';
import '../entities/habito.dart';
import '../entities/meta_option.dart';

/// Represents whether a nullable PATCH field is absent or explicitly present.
class PatchValue<T> {
  const PatchValue.absent() : isPresent = false, value = null;

  const PatchValue.present(this.value) : isPresent = true;

  final bool isPresent;
  final T? value;
}

abstract interface class HabitRepository {
  Future<List<Categoria>> listCategories();

  Future<List<MetaOption>> listGoalOptions();

  Future<List<Habito>> listHabits({HabitoEstado? estado});

  Future<Habito> getHabit(String habitId);

  Future<Habito> createHabit({
    required String nombre,
    required DateTime fechaInicio,
    required Frecuencia frecuencia,
    String? descripcion,
    String? categoriaId,
    String? metaId,
  });

  Future<Habito> updateHabit({
    required String habitId,
    String? nombre,
    PatchValue<String?> descripcion = const PatchValue<String?>.absent(),
    PatchValue<String?> categoriaId = const PatchValue<String?>.absent(),
    PatchValue<String?> metaId = const PatchValue<String?>.absent(),
    DateTime? fechaInicio,
    Frecuencia? frecuencia,
  });

  Future<Habito> pauseHabit(
    String habitId,
    DateTime fechaInicio, {
    DateTime? fechaFin,
  });

  Future<Habito> resumeHabit(String habitId);

  Future<Habito> completeHabit(String habitId);

  Future<void> deleteHabit(String habitId);
}
