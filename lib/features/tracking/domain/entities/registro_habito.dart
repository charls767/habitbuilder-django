enum EstadoRegistro {
  completado('completado'),
  parcial('parcial'),
  omitido('omitido');

  const EstadoRegistro(this.apiValue);

  factory EstadoRegistro.fromApiValue(String value) {
    return values.firstWhere(
      (estado) => estado.apiValue == value,
      orElse: () =>
          throw FormatException('Estado de registro desconocido: $value'),
    );
  }

  final String apiValue;
}

class RegistroHabito {
  const RegistroHabito({
    required this.id,
    required this.habitId,
    required this.fecha,
    required this.estado,
    this.nota,
  });

  final String id;
  final String habitId;
  final DateTime fecha;
  final EstadoRegistro estado;
  final String? nota;
}

class RegistroHabitoDraft {
  RegistroHabitoDraft({
    required this.habitId,
    required DateTime fecha,
    required this.estado,
    this.nota,
  }) : fecha = DateTime(fecha.year, fecha.month, fecha.day);

  final String habitId;
  final DateTime fecha;
  final EstadoRegistro estado;
  final String? nota;

  String get idempotencyKey => '$habitId:${formatLocalDate(fecha)}';
}

String formatLocalDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
