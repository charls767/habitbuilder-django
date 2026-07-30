import '../entities/registro_habito.dart';

abstract interface class TrackingRepository {
  Future<List<RegistroHabito>> listByHabit(
    String habitId, {
    required DateTime from,
    required DateTime to,
  });

  Future<RegistroHabito> upsert(RegistroHabitoDraft draft);
}
