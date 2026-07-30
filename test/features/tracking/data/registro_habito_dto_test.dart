import 'package:flutter_test/flutter_test.dart';
import 'package:habitbuilder_mobile/features/tracking/data/models/registro_habito_dto.dart';
import 'package:habitbuilder_mobile/features/tracking/domain/entities/registro_habito.dart';

void main() {
  group('RegistroHabito', () {
    test('maps every API status and rejects unknown values', () {
      expect(EstadoRegistro.values.map((status) => status.apiValue), [
        'hecho',
        'parcial',
        'omitido',
      ]);
      expect(
        () => EstadoRegistro.fromApiValue('pendiente'),
        throwsFormatException,
      );
    });

    test('normalizes dates and builds a stable idempotency key', () {
      final draft = RegistroHabitoDraft(
        habitId: 'habit-1',
        fecha: DateTime(2026, 7, 30, 22, 45),
        estado: EstadoRegistro.parcial,
      );

      expect(draft.fecha, DateTime(2026, 7, 30));
      expect(draft.idempotencyKey, 'habit-1:2026-07-30');
      expect(formatLocalDate(DateTime(9, 2, 3)), '0009-02-03');
    });
  });

  group('RegistroHabitoDto', () {
    test('parses the response and converts it to an entity', () {
      final entity = RegistroHabitoDto.fromJson({
        'id': 'log-1',
        'habitoId': 'habit-1',
        'fecha': '2026-07-30',
        'estado': 'omitido',
        'nota': 'Dia de descanso',
      }).toEntity();

      expect(entity.id, 'log-1');
      expect(entity.habitId, 'habit-1');
      expect(entity.fecha, DateTime(2026, 7, 30));
      expect(entity.estado, EstadoRegistro.omitido);
      expect(entity.nota, 'Dia de descanso');
    });

    test('serializes the complete upsert request', () {
      final request = RegistroHabitoRequestDto.fromDraft(
        RegistroHabitoDraft(
          habitId: 'habit-1',
          fecha: DateTime(2026, 7, 30),
          estado: EstadoRegistro.completado,
          nota: 'Sesion completa',
        ),
      );

      expect(request.toJson(), {
        'fechaLocal': '2026-07-30',
        'estado': 'hecho',
        'nota': 'Sesion completa',
      });
    });
  });
}
