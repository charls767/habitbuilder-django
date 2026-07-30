import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitbuilder_mobile/core/network/api_exception.dart';
import 'package:habitbuilder_mobile/features/reminders/data/datasources/reminder_remote_data_source.dart';
import 'package:habitbuilder_mobile/features/reminders/data/models/recordatorio_dto.dart';
import 'package:habitbuilder_mobile/features/reminders/domain/entities/recordatorio.dart';
import 'package:habitbuilder_mobile/features/reminders/domain/entities/reminder_time.dart';

void main() {
  test('calls every reminder endpoint with exact method and payload', () async {
    final requests = <RequestOptions>[];
    final dio = Dio()
      ..httpClientAdapter = _CallbackAdapter((options) {
        requests.add(options);
        if (options.method == 'DELETE') {
          return ResponseBody.fromString('', 204);
        }
        return _jsonResponse(
          options.method == 'POST' ? 201 : 200,
          options.method == 'GET' ? [_reminderJson()] : _reminderJson(),
        );
      });
    final dataSource = ReminderRemoteDataSource(dio);
    final request = ReminderRequestDto.fromDraft(
      ReminderDraft(
        mensaje: 'Hora de leer',
        hora: ReminderTime.parse('07:30'),
        diasSemana: const [1, 3, 5],
        activo: false,
      ),
    );

    final listed = await dataSource.listByHabit('habit-1');
    final created = await dataSource.create('habit-1', request);
    final updated = await dataSource.update('reminder-1', request);
    await dataSource.delete('reminder-1');

    expect(listed.single.id, 'reminder-1');
    expect(created.id, 'reminder-1');
    expect(updated.id, 'reminder-1');
    expect(requests.map((item) => '${item.method} ${item.path}'), [
      'GET /v1/habitos/habit-1/recordatorios',
      'POST /v1/habitos/habit-1/recordatorios',
      'PATCH /v1/recordatorios/reminder-1',
      'DELETE /v1/recordatorios/reminder-1',
    ]);
    expect(requests[1].data, {
      'mensaje': 'Hora de leer',
      'hora': '07:30',
      'diasSemana': [1, 3, 5],
      'activo': false,
    });
    expect(requests[2].data, requests[1].data);
  });

  test(
    'normalizes 400, 404 and 409 without hiding backend conflicts',
    () async {
      for (final status in [400, 404, 409]) {
        final dio = Dio()
          ..httpClientAdapter = _CallbackAdapter(
            (_) => _jsonResponse(status, {
              'codigo': 'REMINDER_$status',
              'mensaje': 'Reminder request failed.',
            }),
          );
        final dataSource = ReminderRemoteDataSource(dio);
        final request = ReminderRequestDto.fromDraft(
          ReminderDraft(
            mensaje: 'Leer',
            hora: ReminderTime.parse('07:30'),
            diasSemana: const [1],
            activo: true,
          ),
        );

        await expectLater(
          dataSource.create('habit-1', request),
          throwsA(
            isA<ApiException>()
                .having((error) => error.statusCode, 'statusCode', status)
                .having((error) => error.code, 'code', 'REMINDER_$status'),
          ),
        );
      }
    },
  );
}

Map<String, dynamic> _reminderJson() {
  return {
    'id': 'reminder-1',
    'habitoId': 'habit-1',
    'mensaje': 'Hora de leer',
    'hora': '07:30',
    'diasSemana': [1, 3, 5],
    'activo': false,
  };
}

ResponseBody _jsonResponse(int status, Object body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

class _CallbackAdapter implements HttpClientAdapter {
  _CallbackAdapter(this.callback);

  final ResponseBody Function(RequestOptions options) callback;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return callback(options);
  }

  @override
  void close({bool force = false}) {}
}
