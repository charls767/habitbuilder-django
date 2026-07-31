enum MetaEstado {
  enProgreso('en_progreso'),
  lograda('lograda'),
  pausada('pausada'),
  cancelada('cancelada');

  const MetaEstado(this.apiValue);

  factory MetaEstado.fromApiValue(String value) {
    return values.firstWhere(
      (estado) => estado.apiValue == value,
      orElse: () => throw FormatException('Estado de meta desconocido: $value'),
    );
  }

  final String apiValue;
}

class Meta {
  Meta({
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

  final String id;
  final String usuarioId;
  final String nombre;
  final String? descripcion;
  final DateTime? fechaObjetivo;
  final MetaEstado estado;
  final List<String> habitoIds;
  final DateTime fechaCreacion;
  final DateTime fechaActualizacion;
}
