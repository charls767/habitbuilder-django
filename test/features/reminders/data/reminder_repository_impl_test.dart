import 'package:flutter_test/flutter_test.dart';
import 'package:habitbuilder_mobile/features/reminders/data/datasources/reminder_remote_data_source.dart';
import 'package:habitbuilder_mobile/features/reminders/data/models/recordatorio_dto.dart';
import 'package:habitbuilder_mobile/features/reminders/data/repositories/reminder_repository_impl.dart';
import 'package:habitbuilder_mobile/features/reminders/domain/entities/recordatorio.dart';
import 'package:habitbuilder_mobile/features/reminders/domain/entities/reminder_time.dart';
import 'package:mocktail/mocktail.dart';

class _MockReminderRemoteDataSource extends Mock
    implements ReminderRemoteDataSource {}

class _FakeReminderRequestDto extends Fake implements ReminderRequestDto {}

void main() {
  late _MockReminderRemoteDataSource remote;
  late ReminderRepositoryImpl repository;

  setUpAll(() {
    registerFallbackValue(_FakeReminderRequestDto());
  });

  setUp(() {
    remote = _MockReminderRemoteDataSource();
    repository = ReminderRepositoryImpl(remote);
  });

  test('lists and maps zero or many reminders for one habit', () async {
    when(
      () => remote.listByHabit('habit-1'),
    ).thenAnswer((_) async => [_reminderDto()]);

    final reminders = await repository.listByHabit('habit-1');

    expect(reminders.single.id, 'reminder-1');
    expect(reminders.single.habitId, 'habit-1');
    expect(reminders.single.diasSemana, [1, 3, 5]);
    verify(() => remote.listByHabit('habit-1')).called(1);
  });

  test('creates using the complete writable reminder shape', () async {
    when(
      () => remote.create('habit-1', any()),
    ).thenAnswer((_) async => _reminderDto());
    final draft = _draft(activo: true);

    final reminder = await repository.create(habitId: 'habit-1', draft: draft);

    final request =
        verify(() => remote.create('habit-1', captureAny())).captured.single
            as ReminderRequestDto;
    expect(reminder.id, 'reminder-1');
    expect(request.toJson(), {
      'mensaje': 'Preparar el libro',
      'hora': '20:45',
      'diasSemana': [2, 4],
      'activo': true,
    });
  });

  test('updates activo without losing message, time or weekdays', () async {
    when(
      () => remote.update('reminder-1', any()),
    ).thenAnswer((_) async => _reminderDto(activo: false));
    final draft = _draft(activo: false);

    final reminder = await repository.update(
      reminderId: 'reminder-1',
      draft: draft,
    );

    final request =
        verify(() => remote.update('reminder-1', captureAny())).captured.single
            as ReminderRequestDto;
    expect(reminder.activo, isFalse);
    expect(request.toJson(), {
      'mensaje': 'Preparar el libro',
      'hora': '20:45',
      'diasSemana': [2, 4],
      'activo': false,
    });
  });

  test('delegates delete by reminder id', () async {
    when(() => remote.delete('reminder-1')).thenAnswer((_) async {});

    await repository.delete('reminder-1');

    verify(() => remote.delete('reminder-1')).called(1);
  });
}

ReminderDraft _draft({required bool activo}) {
  return ReminderDraft(
    mensaje: 'Preparar el libro',
    hora: ReminderTime.parse('20:45'),
    diasSemana: const [4, 2],
    activo: activo,
  );
}

RecordatorioDto _reminderDto({bool activo = true}) {
  return RecordatorioDto.fromJson({
    'id': 'reminder-1',
    'habitoId': 'habit-1',
    'mensaje': 'Hora de leer',
    'hora': '07:30',
    'diasSemana': [1, 3, 5],
    'activo': activo,
  });
}
