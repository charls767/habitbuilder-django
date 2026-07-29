import 'package:flutter_test/flutter_test.dart';
import 'package:habitbuilder_mobile/features/habits/domain/entities/frecuencia.dart';
import 'package:habitbuilder_mobile/features/habits/domain/entities/habito.dart';

void main() {
  test('HabitoEstado maps exact API values and rejects unknown values', () {
    expect(HabitoEstado.activo.apiValue, 'activo');
    expect(HabitoEstado.pausado.apiValue, 'pausado');
    expect(HabitoEstado.completado.apiValue, 'completado');
    expect(HabitoEstado.fromApiValue('pausado'), HabitoEstado.pausado);
    expect(() => HabitoEstado.fromApiValue('archivado'), throwsFormatException);
  });

  test(
    'Habito keeps its complete response state and protects pause history',
    () {
      final pauses = [
        PausaHabito(
          id: 'pause-1',
          fechaInicio: DateTime(2026, 8),
          fechaFin: DateTime(2026, 8, 3),
        ),
      ];
      final habit = Habito(
        id: 'habit-1',
        usuarioId: 'user-1',
        nombre: 'Meditar',
        descripcion: 'Diez minutos',
        categoriaId: 'cat-1',
        metaId: 'goal-1',
        fechaInicio: DateTime(2026, 7, 28),
        frecuencia: Frecuencia.diaria(),
        estado: HabitoEstado.completado,
        pausas: pauses,
        fechaCompletado: DateTime.utc(2026, 9),
        fechaCreacion: DateTime.utc(2026, 7, 1),
        fechaActualizacion: DateTime.utc(2026, 9),
      );
      pauses.clear();

      expect(habit.id, 'habit-1');
      expect(habit.usuarioId, 'user-1');
      expect(habit.descripcion, 'Diez minutos');
      expect(habit.categoriaId, 'cat-1');
      expect(habit.metaId, 'goal-1');
      expect(habit.fechaInicio, DateTime(2026, 7, 28));
      expect(habit.estado, HabitoEstado.completado);
      expect(habit.fechaCompletado, DateTime.utc(2026, 9));
      expect(habit.pausas, hasLength(1));
      expect(habit.pausas.single.id, 'pause-1');
      expect(() => habit.pausas.clear(), throwsUnsupportedError);
    },
  );
}
