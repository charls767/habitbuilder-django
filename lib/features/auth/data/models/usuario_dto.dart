import '../../domain/entities/usuario.dart';

/// Wire shape for the nested `RegistroUsuarioResponse.usuario` projection.
class UsuarioDto {
  const UsuarioDto({
    required this.id,
    required this.nombre,
    required this.email,
    required this.fechaRegistro,
  });

  factory UsuarioDto.fromJson(Map<String, dynamic> json) {
    final usuario = json['usuario'] is Map<String, dynamic>
        ? json['usuario'] as Map<String, dynamic>
        : json;
    return UsuarioDto(
      id: usuario['id'] as String,
      nombre: usuario['nombre'] as String,
      email: usuario['email'] as String,
      fechaRegistro:
          DateTime.tryParse(usuario['fechaRegistro'] as String? ?? '') ??
          DateTime.now().toUtc(),
    );
  }

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
