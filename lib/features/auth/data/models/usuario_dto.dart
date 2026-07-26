import '../../domain/entities/usuario.dart';

/// Wire shape for the `Usuario` schema in `docs/openapi.yaml`.
class UsuarioDto {
  const UsuarioDto({
    required this.id,
    required this.nombre,
    required this.email,
    required this.fechaRegistro,
  });

  factory UsuarioDto.fromJson(Map<String, dynamic> json) => UsuarioDto(
    id: json['id'] as String,
    nombre: json['nombre'] as String,
    email: json['email'] as String,
    fechaRegistro: DateTime.parse(json['fechaRegistro'] as String),
  );

  final String id;
  final String nombre;
  final String email;
  final DateTime fechaRegistro;

  Usuario toEntity() => Usuario(
    id: id,
    nombre: nombre,
    email: email,
    fechaRegistro: fechaRegistro,
  );
}
