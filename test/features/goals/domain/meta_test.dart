import 'package:flutter_test/flutter_test.dart';
import 'package:habitbuilder_mobile/features/goals/domain/entities/meta.dart';

void main() {
  group('MetaEstado', () {
    for (final expectation in <(String, MetaEstado)>[
      ('en_progreso', MetaEstado.enProgreso),
      ('lograda', MetaEstado.lograda),
      ('pausada', MetaEstado.pausada),
      ('cancelada', MetaEstado.cancelada),
    ]) {
      test('maps ${expectation.$1} in both directions', () {
        expect(MetaEstado.fromApiValue(expectation.$1), expectation.$2);
        expect(expectation.$2.apiValue, expectation.$1);
      });
    }

    test('rejects unknown API states', () {
      expect(() => MetaEstado.fromApiValue('archivada'), throwsFormatException);
    });
  });

  test('Meta keeps contract fields and immutable unique habit ids', () {
    final habitIds = ['habit-1', 'habit-2', 'habit-1'];
    final goal = Meta(
      id: 'goal-1',
      usuarioId: 'user-1',
      nombre: 'Dormir mejor',
      descripcion: 'Descansar ocho horas',
      fechaObjetivo: DateTime(2026, 12, 31),
      estado: MetaEstado.enProgreso,
      habitoIds: habitIds,
      fechaCreacion: DateTime.utc(2026, 7, 1, 10),
      fechaActualizacion: DateTime.utc(2026, 7, 28, 11),
    );

    habitIds.add('habit-3');

    expect(goal.id, 'goal-1');
    expect(goal.usuarioId, 'user-1');
    expect(goal.nombre, 'Dormir mejor');
    expect(goal.descripcion, 'Descansar ocho horas');
    expect(goal.fechaObjetivo, DateTime(2026, 12, 31));
    expect(goal.estado, MetaEstado.enProgreso);
    expect(goal.habitoIds, ['habit-1', 'habit-2']);
    expect(() => goal.habitoIds.add('habit-4'), throwsUnsupportedError);
    expect(goal.fechaCreacion, DateTime.utc(2026, 7, 1, 10));
    expect(goal.fechaActualizacion, DateTime.utc(2026, 7, 28, 11));
  });
}
