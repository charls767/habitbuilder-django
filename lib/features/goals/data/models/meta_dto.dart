import '../../domain/entities/meta.dart';
import '../../domain/repositories/goal_repository.dart';

class MetaDto {
  MetaDto({
    required this.id,
    required this.usuarioId,
    required this.nombre,
    required this.estado,
    required List<String> habitoIds,
    required this.fechaCreacion,
    required this.fechaActualizacion,
    this.descripcion,
    this.fechaObjetivo,
  }) : habitoIds = List<String>.unmodifiable(habitoIds.toSet());

  factory MetaDto.fromJson(Map<String, dynamic> json) {
    return MetaDto(
      id: json['id'] as String,
      usuarioId: json['usuarioId'] as String? ?? '',
      nombre: (json['nombre'] ?? json['descripcion']) as String,
      descripcion: json['descripcion'] as String?,
      fechaObjetivo: _parseNullableDate(json['fechaObjetivo']),
      estado: MetaEstado.fromApiValue(json['estado'] as String),
      habitoIds: (json['habitoIds'] as List<dynamic>? ?? const [])
          .cast<String>(),
      fechaCreacion: DateTime.parse(
        (json['creadoEn'] ?? json['fechaCreacion']) as String,
      ),
      fechaActualizacion: DateTime.parse(
        (json['actualizadoEn'] ??
                json['fechaActualizacion'] ??
                json['creadoEn'])
            as String,
      ),
    );
  }

  final String id;
  final String usuarioId;
  final String nombre;
  final String? descripcion;
  final DateTime? fechaObjetivo;
  final MetaEstado estado;
  final List<String> habitoIds;
  final DateTime fechaCreacion;
  final DateTime fechaActualizacion;

  Meta toEntity() => Meta(
    id: id,
    usuarioId: usuarioId,
    nombre: nombre,
    descripcion: descripcion,
    fechaObjetivo: fechaObjetivo,
    estado: estado,
    habitoIds: habitoIds,
    fechaCreacion: fechaCreacion,
    fechaActualizacion: fechaActualizacion,
  );
}

class MetaCreateRequestDto {
  MetaCreateRequestDto({
    required this.nombre,
    this.descripcion,
    this.fechaObjetivo,
    List<String> habitoIds = const [],
  }) : habitoIds = List<String>.unmodifiable(habitoIds.toSet());

  final String nombre;
  final String? descripcion;
  final DateTime? fechaObjetivo;
  final List<String> habitoIds;

  Map<String, dynamic> toJson() => {
    'descripcion': (descripcion == null || descripcion!.trim().isEmpty)
        ? nombre
        : descripcion,
    if (fechaObjetivo != null) 'fechaObjetivo': _formatDate(fechaObjetivo!),
  };
}

class MetaUpdateRequestDto {
  const MetaUpdateRequestDto({
    this.nombre,
    this.descripcion = const GoalPatchValue<String?>.absent(),
    this.fechaObjetivo = const GoalPatchValue<DateTime?>.absent(),
    this.estado,
  });

  final String? nombre;
  final GoalPatchValue<String?> descripcion;
  final GoalPatchValue<DateTime?> fechaObjetivo;
  final MetaEstado? estado;

  Map<String, dynamic> toJson() => {
    if (descripcion.isPresent || nombre != null)
      'descripcion': (descripcion.isPresent && descripcion.value != null)
          ? descripcion.value
          : nombre,
    if (fechaObjetivo.isPresent)
      'fechaObjetivo': fechaObjetivo.value == null
          ? null
          : _formatDate(fechaObjetivo.value!),
  };

  Map<String, dynamic> stateJson() => {'estado': estado!.apiValue};

  bool get hasChanges => toJson().isNotEmpty || estado != null;
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
