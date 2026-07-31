import '../../domain/entities/recordatorio.dart';
import '../../domain/entities/reminder_time.dart';

final class RecordatorioDto {
  RecordatorioDto._({
    required this.id,
    required this.habitId,
    required this.mensaje,
    required this.hora,
    required List<int> diasSemana,
    required this.activo,
  }) : diasSemana = List<int>.unmodifiable(diasSemana);

  factory RecordatorioDto.fromJson(Map<String, dynamic> json) {
    final entity = Recordatorio(
      id: _readString(json, 'id'),
      habitId: _readString(json, 'habitoId'),
      mensaje: _readString(json, 'mensaje'),
      hora: ReminderTime.parse(_readString(json, 'hora')),
      diasSemana: _readDays(json['diasSemana']),
      activo: _readBool(json, 'activo'),
    );

    return RecordatorioDto._(
      id: entity.id,
      habitId: entity.habitId,
      mensaje: entity.mensaje,
      hora: entity.hora,
      diasSemana: entity.diasSemana,
      activo: entity.activo,
    );
  }

  final String id;
  final String habitId;
  final String mensaje;
  final ReminderTime hora;
  final List<int> diasSemana;
  final bool activo;

  Recordatorio toEntity() {
    return Recordatorio(
      id: id,
      habitId: habitId,
      mensaje: mensaje,
      hora: hora,
      diasSemana: diasSemana,
      activo: activo,
    );
  }
}

final class ReminderRequestDto {
  ReminderRequestDto._({
    required this.mensaje,
    required this.hora,
    required List<int> diasSemana,
    required this.activo,
  }) : diasSemana = List<int>.unmodifiable(diasSemana);

  factory ReminderRequestDto.fromDraft(ReminderDraft draft) {
    return ReminderRequestDto._(
      mensaje: draft.mensaje,
      hora: draft.hora,
      diasSemana: draft.diasSemana,
      activo: draft.activo,
    );
  }

  final String mensaje;
  final ReminderTime hora;
  final List<int> diasSemana;
  final bool activo;

  Map<String, dynamic> toJson() {
    return {
      'mensaje': mensaje,
      'hora': hora.toString(),
      'diasSemana': List<int>.of(diasSemana),
      'activo': activo,
    };
  }
}

String _readString(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is! String) {
    throw FormatException('El campo $field debe ser string.');
  }
  return value;
}

bool _readBool(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is! bool) {
    throw FormatException('El campo $field debe ser bool.');
  }
  return value;
}

List<int> _readDays(Object? value) {
  if (value is! List<dynamic> || value.any((day) => day is! int)) {
    throw const FormatException('diasSemana debe ser una lista de enteros.');
  }
  return value.cast<int>();
}
