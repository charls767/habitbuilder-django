class Usuario {
  const Usuario({
    required this.id,
    required this.nombre,
    required this.email,
    required this.fechaRegistro,
  });

  final String id;
  final String nombre;
  final String email;
  final DateTime fechaRegistro;
}
