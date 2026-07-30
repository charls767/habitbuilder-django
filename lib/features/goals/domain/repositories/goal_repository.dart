import '../entities/meta.dart';

/// Represents whether a nullable goal PATCH field is absent or explicitly sent.
class GoalPatchValue<T> {
  const GoalPatchValue.absent() : isPresent = false, value = null;

  const GoalPatchValue.present(this.value) : isPresent = true;

  final bool isPresent;
  final T? value;
}

abstract interface class GoalRepository {
  Future<List<Meta>> listGoals({MetaEstado? estado});

  Future<Meta> getGoal(String goalId);

  Future<Meta> createGoal({
    required String nombre,
    String? descripcion,
    DateTime? fechaObjetivo,
    List<String> habitoIds = const [],
  });

  Future<Meta> updateGoal({
    required String goalId,
    String? nombre,
    GoalPatchValue<String?> descripcion =
        const GoalPatchValue<String?>.absent(),
    GoalPatchValue<DateTime?> fechaObjetivo =
        const GoalPatchValue<DateTime?>.absent(),
    MetaEstado? estado,
  });

  Future<void> deleteGoal(String goalId);

  Future<Meta> linkHabit(String goalId, String habitId);

  Future<void> unlinkHabit(String goalId, String habitId);
}
