import 'package:flutter_test/flutter_test.dart';
import 'package:habitbuilder_mobile/features/reminders/data/models/recordatorio_dto.dart';
import 'package:habitbuilder_mobile/features/reminders/domain/entities/recordatorio.dart';
import 'package:habitbuilder_mobile/features/reminders/domain/entities/reminder_time.dart';

void main() {
  group('RecordatorioDto', () {
    test('parses every response field and maps a strict entity', () {
      final dto = RecordatorioDto.fromJson({
        'id': 'reminder-1',
        'habitoId': 'habit-1',
        'mensaje': 'Hora de leer',
        'hora': '07:30',
        'diasSemana': [5, 1, 3],
        'activo': true,
      });

      final entity = dto.toEntity();

      expect(entity.id, 'reminder-1');
      expect(entity.habitId, 'habit-1');
      expect(entity.mensaje, 'Hora de leer');
      expect(entity.hora, ReminderTime.parse('07:30'));
      expect(entity.diasSemana, [1, 3, 5]);
      expect(entity.activo, isTrue);
    });

    test('rejects malformed response values before presentation', () {
      for (final json in [
        _reminderJson()..['mensaje'] = '   ',
        _reminderJson()..['hora'] = '7:30',
        _reminderJson()..['diasSemana'] = [1, 1],
        _reminderJson()..['diasSemana'] = [0],
      ]) {
        expect(() => RecordatorioDto.fromJson(json), throwsA(anything));
      }
    });
  });

  test('ReminderRequestDto serializes every writable field exactly', () {
    final request = ReminderRequestDto.fromDraft(
      ReminderDraft(
        mensaje: '  Preparar el libro  ',
        hora: ReminderTime.parse('20:45'),
        diasSemana: const [4, 2],
        activo: false,
      ),
    );

    expect(request.toJson(), {
      'mensaje': 'Preparar el libro',
      'hora': '20:45',
      'diasSemana': [2, 4],
      'activo': false,
    });
  });
}

Map<String, dynamic> _reminderJson() {
  return {
    'id': 'reminder-1',
    'habitoId': 'habit-1',
    'mensaje': 'Leer',
    'hora': '07:30',
    'diasSemana': [1, 3, 5],
    'activo': true,
  };
}
