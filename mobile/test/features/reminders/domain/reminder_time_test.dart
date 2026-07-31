import 'package:flutter_test/flutter_test.dart';
import 'package:habitbuilder_mobile/features/reminders/domain/entities/recordatorio.dart';
import 'package:habitbuilder_mobile/features/reminders/domain/entities/reminder_time.dart';

void main() {
  group('ReminderTime', () {
    test('accepts wall-clock boundaries and exposes canonical parts', () {
      final startOfDay = ReminderTime.parse('00:00');
      final endOfDay = ReminderTime.parse('23:59');

      expect(startOfDay.hour, 0);
      expect(startOfDay.minute, 0);
      expect(startOfDay.toString(), '00:00');
      expect(endOfDay.hour, 23);
      expect(endOfDay.minute, 59);
      expect(endOfDay.toString(), '23:59');
    });

    test('rejects malformed or out-of-range values', () {
      for (final value in [
        '',
        '7:00',
        '07:0',
        '07:000',
        '24:00',
        '23:60',
        '-1:00',
        '07.00',
        ' 07:00 ',
      ]) {
        expect(
          () => ReminderTime.parse(value),
          throwsFormatException,
          reason: 'expected "$value" to be rejected',
        );
      }
    });
  });

  group('ReminderDraft', () {
    test('trims message and stores sorted immutable ISO weekdays', () {
      final sourceDays = [5, 1, 3];
      final draft = ReminderDraft(
        mensaje: '  Hora de leer  ',
        hora: ReminderTime.parse('07:30'),
        diasSemana: sourceDays,
        activo: true,
      );
      sourceDays.add(7);

      expect(draft.mensaje, 'Hora de leer');
      expect(draft.hora.toString(), '07:30');
      expect(draft.diasSemana, [1, 3, 5]);
      expect(draft.activo, isTrue);
      expect(() => draft.diasSemana.add(7), throwsUnsupportedError);
    });

    test('rejects empty or whitespace-only messages', () {
      for (final message in ['', ' ', '\n\t']) {
        expect(
          () => ReminderDraft(
            mensaje: message,
            hora: ReminderTime.parse('07:30'),
            diasSemana: const [1],
            activo: true,
          ),
          throwsArgumentError,
        );
      }
    });

    test('rejects empty, duplicate or out-of-range ISO weekdays', () {
      for (final days in <List<int>>[
        [],
        [0],
        [8],
        [1, 1],
        [1, 7, 8],
      ]) {
        expect(
          () => ReminderDraft(
            mensaje: 'Leer',
            hora: ReminderTime.parse('07:30'),
            diasSemana: days,
            activo: true,
          ),
          throwsArgumentError,
          reason: 'expected $days to be rejected',
        );
      }
    });
  });

  test('Recordatorio preserves identity and validated writable state', () {
    final reminder = Recordatorio(
      id: 'reminder-1',
      habitId: 'habit-1',
      mensaje: '  Preparar el libro  ',
      hora: ReminderTime.parse('20:30'),
      diasSemana: const [4, 2],
      activo: false,
    );

    expect(reminder.id, 'reminder-1');
    expect(reminder.habitId, 'habit-1');
    expect(reminder.mensaje, 'Preparar el libro');
    expect(reminder.hora.toString(), '20:30');
    expect(reminder.diasSemana, [2, 4]);
    expect(reminder.activo, isFalse);
    expect(() => reminder.diasSemana.clear(), throwsUnsupportedError);
  });
}
