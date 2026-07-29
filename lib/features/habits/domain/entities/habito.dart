import 'frecuencia.dart';

enum HabitoEstado {
  activo('activo'),
  pausado('pausado'),
  completado('completado');

  const HabitoEstado(this.apiValue);

  factory HabitoEstado.fromApiValue(String value) {
    return values.firstWhere(
      (estado) => estado.apiValue == value,
      orElse: () =>
          throw FormatException('Estado de habito desconocido: $value'),
    );
  }

  final String apiValue;
}

/// Read-only pause history carried by the `Habito` response.
///
/// Pause/resume operations are intentionally outside this slice (HBM-11).
class PausaHabito {
  const PausaHabito({
    required this.id,
    required this.fechaInicio,
    this.fechaFin,
  });

  final String id;
  final DateTime fechaInicio;
  final DateTime? fechaFin;
}

class Habito {
  Habito({
    required this.id,
    required this.usuarioId,
    required this.nombre,
    required this.fechaInicio,
    required this.frecuencia,
    required this.estado,
    required List<PausaHabito> pausas,
    required this.fechaCreacion,
    required this.fechaActualizacion,
    this.descripcion,
    this.categoriaId,
    this.metaId,
    this.fechaCompletado,
  }) : pausas = List<PausaHabito>.unmodifiable(pausas);

  final String id;
  final String usuarioId;
  final String nombre;
  final String? descripcion;
  final String? categoriaId;
  final String? metaId;
  final DateTime fechaInicio;
  final Frecuencia frecuencia;
  final HabitoEstado estado;
  final List<PausaHabito> pausas;
  final DateTime? fechaCompletado;
  final DateTime fechaCreacion;
  final DateTime fechaActualizacion;
}
