import '../entities/recordatorio.dart';

abstract interface class ReminderRepository {
  Future<List<Recordatorio>> listByHabit(String habitId);

  Future<Recordatorio> create({
    required String habitId,
    required ReminderDraft draft,
  });

  Future<Recordatorio> update({
    required String reminderId,
    required ReminderDraft draft,
  });

  Future<void> delete(String reminderId);
}
