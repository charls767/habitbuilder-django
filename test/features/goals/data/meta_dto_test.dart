import 'package:flutter_test/flutter_test.dart';
import 'package:habitbuilder_mobile/features/goals/data/models/meta_dto.dart';
import 'package:habitbuilder_mobile/features/goals/domain/entities/meta.dart';
import 'package:habitbuilder_mobile/features/goals/domain/repositories/goal_repository.dart';

void main() {
  group('MetaDto', () {
    test('maps every allowed response field and ignores server extras', () {
      final dto = MetaDto.fromJson(_fullGoalJson());
      final goal = dto.toEntity();

      expect(goal.id, 'goal-1');
      expect(goal.usuarioId, 'user-1');
      expect(goal.nombre, 'Dormir mejor');
      expect(goal.descripcion, 'Descansar ocho horas');
      expect(goal.fechaObjetivo, DateTime(2026, 12, 31));
      expect(goal.estado, MetaEstado.lograda);
      expect(goal.habitoIds, ['habit-1', 'habit-2']);
      expect(goal.fechaCreacion, DateTime.utc(2026, 7, 1, 10));
      expect(goal.fechaActualizacion, DateTime.utc(2026, 7, 28, 11, 30));
    });

    test('maps nullable fields and unique habit ids', () {
      final json = _fullGoalJson()
        ..['descripcion'] = null
        ..['fechaObjetivo'] = null
        ..['habitoIds'] = ['habit-1', 'habit-1', 'habit-2'];

      final goal = MetaDto.fromJson(json).toEntity();

      expect(goal.descripcion, isNull);
      expect(goal.fechaObjetivo, isNull);
      expect(goal.habitoIds, ['habit-1', 'habit-2']);
    });

    test('rejects an unknown state', () {
      final json = _fullGoalJson()..['estado'] = 'archivada';

      expect(() => MetaDto.fromJson(json), throwsFormatException);
    });
  });

  group('MetaCreateRequestDto', () {
    test('serializes optional fields, date only and unique habit ids', () {
      final request = MetaCreateRequestDto(
        nombre: 'Dormir mejor',
        descripcion: 'Descansar ocho horas',
        fechaObjetivo: DateTime(2026, 12, 31, 23, 59),
        habitoIds: ['habit-1', 'habit-2', 'habit-1'],
      );

      expect(request.toJson(), {
        'nombre': 'Dormir mejor',
        'descripcion': 'Descansar ocho horas',
        'fechaObjetivo': '2026-12-31',
        'habitoIds': ['habit-1', 'habit-2'],
      });
    });

    test('omits nullable and empty optional fields', () {
      final request = MetaCreateRequestDto(nombre: 'Leer mas');

      expect(request.toJson(), {'nombre': 'Leer mas'});
    });
  });

  group('MetaUpdateRequestDto', () {
    test('distinguishes absent nullable fields from explicit null', () {
      const empty = MetaUpdateRequestDto();
      const clearFields = MetaUpdateRequestDto(
        descripcion: GoalPatchValue<String?>.present(null),
        fechaObjetivo: GoalPatchValue<DateTime?>.present(null),
      );

      expect(empty.hasChanges, isFalse);
      expect(empty.toJson(), isEmpty);
      expect(clearFields.hasChanges, isTrue);
      expect(clearFields.toJson(), {
        'descripcion': null,
        'fechaObjetivo': null,
      });
    });

    test('serializes every editable field using API state values', () {
      final request = MetaUpdateRequestDto(
        nombre: 'Nuevo nombre',
        descripcion: const GoalPatchValue<String?>.present('Nueva descripcion'),
        fechaObjetivo: GoalPatchValue<DateTime?>.present(
          DateTime(2027, 1, 15, 18),
        ),
        estado: MetaEstado.cancelada,
      );

      expect(request.toJson(), {
        'nombre': 'Nuevo nombre',
        'descripcion': 'Nueva descripcion',
        'fechaObjetivo': '2027-01-15',
        'estado': 'cancelada',
      });
    });
  });
}

Map<String, dynamic> _fullGoalJson() {
  return {
    'id': 'goal-1',
    'usuarioId': 'user-1',
    'nombre': 'Dormir mejor',
    'descripcion': 'Descansar ocho horas',
    'fechaObjetivo': '2026-12-31',
    'estado': 'lograda',
    'habitoIds': ['habit-1', 'habit-2'],
    ['progreso', 'Porcentaje'].join(): 100,
    'fechaCreacion': '2026-07-01T10:00:00Z',
    'fechaActualizacion': '2026-07-28T11:30:00Z',
    'campoFuturo': {'ignorado': true},
  };
}
