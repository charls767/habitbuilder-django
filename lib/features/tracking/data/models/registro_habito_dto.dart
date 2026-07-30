import '../../domain/entities/registro_habito.dart';

class RegistroHabitoDto {
  const RegistroHabitoDto({
    required this.id,
    required this.habitId,
    required this.fecha,
    required this.estado,
    this.nota,
  });

  factory RegistroHabitoDto.fromJson(Map<String, dynamic> json) {
    return RegistroHabitoDto(
      id: json['id'] as String,
      habitId: json['habitoId'] as String,
      fecha: DateTime.parse(json['fecha'] as String),
      estado: EstadoRegistro.fromApiValue(json['estado'] as String),
      nota: json['nota'] as String?,
    );
  }

  final String id;
  final String habitId;
  final DateTime fecha;
  final EstadoRegistro estado;
  final String? nota;

  RegistroHabito toEntity() => RegistroHabito(
    id: id,
    habitId: habitId,
    fecha: fecha,
    estado: estado,
    nota: nota,
  );
}

class RegistroHabitoRequestDto {
  const RegistroHabitoRequestDto({
    required this.fecha,
    required this.estado,
    this.nota,
  });

  factory RegistroHabitoRequestDto.fromDraft(RegistroHabitoDraft draft) {
    return RegistroHabitoRequestDto(
      fecha: draft.fecha,
      estado: draft.estado,
      nota: draft.nota,
    );
  }

  final DateTime fecha;
  final EstadoRegistro estado;
  final String? nota;

  Map<String, dynamic> toJson() => {
    'fecha': formatLocalDate(fecha),
    'estado': estado.apiValue,
    'nota': nota,
  };
}
