import '../../domain/entities/habito.dart';
import '../../domain/repositories/habit_repository.dart';
import 'frecuencia_dto.dart';

class PausaHabitoDto {
  const PausaHabitoDto({
    required this.id,
    required this.fechaInicio,
    this.fechaFin,
  });

  factory PausaHabitoDto.fromJson(Map<String, dynamic> json) {
    return PausaHabitoDto(
      id: json['id'] as String,
      fechaInicio: DateTime.parse(json['fechaInicio'] as String),
      fechaFin: _parseNullableDate(json['fechaFin']),
    );
  }

  final String id;
  final DateTime fechaInicio;
  final DateTime? fechaFin;

  Map<String, dynamic> toJson() => {
    'id': id,
    'fechaInicio': _formatDate(fechaInicio),
    'fechaFin': fechaFin == null ? null : _formatDate(fechaFin!),
  };

  PausaHabito toEntity() =>
      PausaHabito(id: id, fechaInicio: fechaInicio, fechaFin: fechaFin);
}

class HabitoDto {
  HabitoDto({
    required this.id,
    required this.usuarioId,
    required this.nombre,
    required this.fechaInicio,
    required this.frecuencia,
    required this.estado,
    required List<PausaHabitoDto> pausas,
    required this.fechaCreacion,
    required this.fechaActualizacion,
    this.descripcion,
    this.categoriaId,
    this.metaId,
    this.fechaCompletado,
  }) : pausas = List<PausaHabitoDto>.unmodifiable(pausas);

  factory HabitoDto.fromJson(Map<String, dynamic> json) {
    return HabitoDto(
      id: json['id'] as String,
      usuarioId: json['usuarioId'] as String,
      nombre: json['nombre'] as String,
      descripcion: json['descripcion'] as String?,
      categoriaId: json['categoriaId'] as String?,
      metaId: json['metaId'] as String?,
      fechaInicio: DateTime.parse(json['fechaInicio'] as String),
      frecuencia: FrecuenciaDto.fromJson(
        json['frecuencia'] as Map<String, dynamic>,
      ),
      estado: HabitoEstado.fromApiValue(json['estado'] as String),
      pausas: (json['pausas'] as List<dynamic>)
          .map((item) => PausaHabitoDto.fromJson(item as Map<String, dynamic>))
          .toList(),
      fechaCompletado: _parseNullableDate(json['fechaCompletado']),
      fechaCreacion: DateTime.parse(json['fechaCreacion'] as String),
      fechaActualizacion: DateTime.parse(json['fechaActualizacion'] as String),
    );
  }

  final String id;
  final String usuarioId;
  final String nombre;
  final String? descripcion;
  final String? categoriaId;
  final String? metaId;
  final DateTime fechaInicio;
  final FrecuenciaDto frecuencia;
  final HabitoEstado estado;
  final List<PausaHabitoDto> pausas;
  final DateTime? fechaCompletado;
  final DateTime fechaCreacion;
  final DateTime fechaActualizacion;

  Map<String, dynamic> toJson() => {
    'id': id,
    'usuarioId': usuarioId,
    'nombre': nombre,
    'descripcion': descripcion,
    'categoriaId': categoriaId,
    'metaId': metaId,
    'fechaInicio': _formatDate(fechaInicio),
    'frecuencia': frecuencia.toJson(),
    'estado': estado.apiValue,
    'pausas': pausas.map((pausa) => pausa.toJson()).toList(),
    'fechaCompletado': fechaCompletado?.toIso8601String(),
    'fechaCreacion': fechaCreacion.toIso8601String(),
    'fechaActualizacion': fechaActualizacion.toIso8601String(),
  };

  Habito toEntity() => Habito(
    id: id,
    usuarioId: usuarioId,
    nombre: nombre,
    descripcion: descripcion,
    categoriaId: categoriaId,
    metaId: metaId,
    fechaInicio: fechaInicio,
    frecuencia: frecuencia.toEntity(),
    estado: estado,
    pausas: pausas.map((pausa) => pausa.toEntity()).toList(),
    fechaCompletado: fechaCompletado,
    fechaCreacion: fechaCreacion,
    fechaActualizacion: fechaActualizacion,
  );
}

class HabitoCreateRequestDto {
  const HabitoCreateRequestDto({
    required this.nombre,
    required this.fechaInicio,
    required this.frecuencia,
    this.descripcion,
    this.categoriaId,
    this.metaId,
  });

  final String nombre;
  final String? descripcion;
  final String? categoriaId;
  final String? metaId;
  final DateTime fechaInicio;
  final FrecuenciaDto frecuencia;

  Map<String, dynamic> toJson() => {
    'nombre': nombre,
    if (descripcion != null) 'descripcion': descripcion,
    if (categoriaId != null) 'categoriaId': categoriaId,
    if (metaId != null) 'metaId': metaId,
    'fechaInicio': _formatDate(fechaInicio),
    'frecuencia': frecuencia.toJson(),
  };
}

class HabitoUpdateRequestDto {
  const HabitoUpdateRequestDto({
    this.nombre,
    this.descripcion = const PatchValue<String?>.absent(),
    this.categoriaId = const PatchValue<String?>.absent(),
    this.metaId = const PatchValue<String?>.absent(),
    this.fechaInicio,
    this.frecuencia,
  });

  final String? nombre;
  final PatchValue<String?> descripcion;
  final PatchValue<String?> categoriaId;
  final PatchValue<String?> metaId;
  final DateTime? fechaInicio;
  final FrecuenciaDto? frecuencia;

  Map<String, dynamic> toJson() => {
    if (nombre != null) 'nombre': nombre,
    if (descripcion.isPresent) 'descripcion': descripcion.value,
    if (categoriaId.isPresent) 'categoriaId': categoriaId.value,
    if (metaId.isPresent) 'metaId': metaId.value,
    if (fechaInicio != null) 'fechaInicio': _formatDate(fechaInicio!),
    if (frecuencia != null) 'frecuencia': frecuencia!.toJson(),
  };

  bool get hasChanges => toJson().isNotEmpty;
}

DateTime? _parseNullableDate(Object? value) {
  return value is String ? DateTime.parse(value) : null;
}

String _formatDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
