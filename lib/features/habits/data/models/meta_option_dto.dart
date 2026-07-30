import '../../domain/entities/meta_option.dart';

/// Minimal projection parsed from each `MetaResponse` returned by `GET /v1/metas`.
class MetaOptionDto {
  const MetaOptionDto({required this.id, required this.nombre});

  factory MetaOptionDto.fromJson(Map<String, dynamic> json) {
    return MetaOptionDto(
      id: json['id'] as String,
      nombre: (json['nombre'] ?? json['descripcion']) as String,
    );
  }

  final String id;
  final String nombre;

  MetaOption toEntity() => MetaOption(id: id, nombre: nombre);
}
