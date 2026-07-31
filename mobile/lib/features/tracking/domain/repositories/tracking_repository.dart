import '../entities/registro_habito.dart';

abstract interface class TrackingRepository {
  Future<List<RegistroHabito>> listByHabit(
    String habitId, {
    required DateTime from,
    required DateTime to,
  });

  Future<RegistroHabito> upsert(RegistroHabitoDraft draft);
}

abstract interface class SyncableTrackingRepository
    implements TrackingRepository {
  Future<List<RegistroHabito>> refreshByHabit(
    String habitId, {
    required DateTime from,
    required DateTime to,
  });

  Future<TrackingSyncReport> syncPending();
}

class TrackingSyncReport {
  const TrackingSyncReport({
    required this.synced,
    required this.pending,
    required this.conflicts,
  });

  const TrackingSyncReport.empty() : synced = 0, pending = 0, conflicts = 0;

  final int synced;
  final int pending;
  final int conflicts;
}
