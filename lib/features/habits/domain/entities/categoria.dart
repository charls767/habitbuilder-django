class Categoria {
  const Categoria({
    required this.id,
    required this.nombre,
    this.colorHex,
    this.icono,
  });

  final String id;
  final String nombre;
  final String? colorHex;
  final String? icono;
}
