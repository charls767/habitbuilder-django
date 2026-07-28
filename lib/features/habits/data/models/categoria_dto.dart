import '../../domain/entities/categoria.dart';

class CategoriaDto {
  const CategoriaDto({
    required this.id,
    required this.nombre,
    this.colorHex,
    this.icono,
  });

  factory CategoriaDto.fromJson(Map<String, dynamic> json) {
    return CategoriaDto(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      colorHex: json['colorHex'] as String?,
      icono: json['icono'] as String?,
    );
  }

  final String id;
  final String nombre;
  final String? colorHex;
  final String? icono;

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    if (colorHex != null) 'colorHex': colorHex,
    if (icono != null) 'icono': icono,
  };

  Categoria toEntity() =>
      Categoria(id: id, nombre: nombre, colorHex: colorHex, icono: icono);
}
