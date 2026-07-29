import 'reminder_time.dart';

final class Recordatorio {
  Recordatorio({
    required this.id,
    required this.habitId,
    required String mensaje,
    required this.hora,
    required List<int> diasSemana,
    required this.activo,
  }) : mensaje = _validateMessage(mensaje),
       diasSemana = _validateDays(diasSemana);

  final String id;
  final String habitId;
  final String mensaje;
  final ReminderTime hora;
  final List<int> diasSemana;
  final bool activo;
}

final class ReminderDraft {
  ReminderDraft({
    required String mensaje,
    required this.hora,
    required List<int> diasSemana,
    required this.activo,
  }) : mensaje = _validateMessage(mensaje),
       diasSemana = _validateDays(diasSemana);

  final String mensaje;
  final ReminderTime hora;
  final List<int> diasSemana;
  final bool activo;
}

String _validateMessage(String message) {
  final trimmed = message.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError.value(
      message,
      'mensaje',
      'El mensaje no puede estar vacio.',
    );
  }
  return trimmed;
}

List<int> _validateDays(List<int> days) {
  if (days.isEmpty) {
    throw ArgumentError.value(
      days,
      'diasSemana',
      'Debe incluir al menos un dia.',
    );
  }
  if (days.any((day) => day < 1 || day > 7)) {
    throw ArgumentError.value(
      days,
      'diasSemana',
      'Cada dia debe estar entre 1 y 7.',
    );
  }
  if (days.toSet().length != days.length) {
    throw ArgumentError.value(
      days,
      'diasSemana',
      'Los dias no pueden repetirse.',
    );
  }

  final sorted = List<int>.of(days)..sort();
  return List<int>.unmodifiable(sorted);
}
