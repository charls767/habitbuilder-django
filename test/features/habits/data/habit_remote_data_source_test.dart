import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitbuilder_mobile/core/network/api_exception.dart';
import 'package:habitbuilder_mobile/features/habits/data/datasources/habit_remote_data_source.dart';
import 'package:habitbuilder_mobile/features/habits/data/models/frecuencia_dto.dart';
import 'package:habitbuilder_mobile/features/habits/data/models/habito_dto.dart';

void main() {
  test(
    'calls every supported endpoint with the exact method and payload',
    () async {
      final requests = <RequestOptions>[];
      final dio = Dio()
        ..httpClientAdapter = _CallbackAdapter((options) {
          requests.add(options);
          if (options.path == '/v1/metas') {
            return _jsonResponse(200, [
              {
                'id': 'goal-1',
                'descripcion': 'Dormir mejor',
                'fechaObjetivo': '2026-12-31',
                'estado': 'en_progreso',
                'creadoEn': '2026-07-01T00:00:00Z',
              },
            ]);
          }
          if (options.method == 'DELETE') {
            return ResponseBody.fromString('', 204);
          }
          return _jsonResponse(
            options.method == 'POST' ? 201 : 200,
            options.path == '/v1/habitos' && options.method == 'GET'
                ? [_habitJson()]
                : _habitJson(),
          );
        });
      final dataSource = HabitRemoteDataSource(dio);

      final categories = await dataSource.listCategories();
      final goals = await dataSource.listGoalOptions();
      final habits = await dataSource.listHabits(estado: 'activo');
      final habit = await dataSource.getHabit('habit-1');
      final created = await dataSource.createHabit(
        HabitoCreateRequestDto(
          nombre: 'Leer',
          fechaInicio: DateTime(2026, 7, 28),
          frecuencia: const FrecuenciaDiariaDto(),
        ),
      );
      final updated = await dataSource.updateHabit(
        'habit-1',
        const HabitoUpdateRequestDto(nombre: 'Leer mas'),
      );
      await dataSource.deleteHabit('habit-1');

      expect(categories.first.id, 'salud');
      expect(goals.single.nombre, 'Dormir mejor');
      expect(habits.single.id, 'habit-1');
      expect(habit.id, 'habit-1');
      expect(created.id, 'habit-1');
      expect(updated.id, 'habit-1');

      expect(requests.map((request) => '${request.method} ${request.path}'), [
        'GET /v1/metas',
        'GET /v1/habitos',
        'GET /v1/habitos/habit-1',
        'POST /v1/habitos',
        'PATCH /v1/habitos/habit-1',
        'DELETE /v1/habitos/habit-1',
      ]);
      expect(requests[1].queryParameters, isEmpty);
      expect(requests[3].data, {
        'nombre': 'Leer',
        'fechaInicio': '2026-07-28',
        'frecuencia': {'tipo': 'diaria'},
      });
      expect(requests[4].data, {'nombre': 'Leer mas'});
    },
  );

  test('omits the estado query when no filter is requested', () async {
    late RequestOptions captured;
    final dio = Dio()
      ..httpClientAdapter = _CallbackAdapter((options) {
        captured = options;
        return _jsonResponse(200, [_habitJson()]);
      });

    await HabitRemoteDataSource(dio).listHabits();

    expect(captured.queryParameters, isEmpty);
  });

  test('normalizes Dio errors through ApiException', () async {
    final dio = Dio()
      ..httpClientAdapter = _CallbackAdapter(
        (_) => _jsonResponse(404, {
          'codigo': 'HABITO_NO_ENCONTRADO',
          'mensaje': 'El habito no existe.',
        }),
      );

    await expectLater(
      HabitRemoteDataSource(dio).getHabit('missing'),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 404)
            .having((error) => error.code, 'code', 'HABITO_NO_ENCONTRADO'),
      ),
    );
  });
}

Map<String, dynamic> _habitJson() {
  return {
    'id': 'habit-1',
    'usuarioId': 'user-1',
    'nombre': 'Leer',
    'descripcion': null,
    'categoriaId': null,
    'metaId': null,
    'fechaInicio': '2026-07-28',
    'frecuencia': {'tipo': 'diaria'},
    'estado': 'activo',
    'pausas': <Map<String, dynamic>>[],
    'fechaCompletado': null,
    'fechaCreacion': '2026-07-01T00:00:00Z',
    'fechaActualizacion': '2026-07-28T00:00:00Z',
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
