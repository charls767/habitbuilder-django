import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitbuilder_mobile/core/network/api_exception.dart';
import 'package:habitbuilder_mobile/features/goals/data/datasources/goal_remote_data_source.dart';
import 'package:habitbuilder_mobile/features/goals/data/models/meta_dto.dart';

void main() {
  test('calls every goal endpoint with exact methods and payloads', () async {
    final requests = <RequestOptions>[];
    final dio = Dio()
      ..httpClientAdapter = _CallbackAdapter((options) {
        requests.add(options);
        if (options.path == '/goals' && options.method == 'GET') {
          return _jsonResponse(200, [_goalJson()]);
        }
        if (options.path == '/goals/goal-delete') {
          return ResponseBody.fromString('', 204);
        }
        return _jsonResponse(options.method == 'POST' ? 201 : 200, _goalJson());
      });
    final source = GoalRemoteDataSource(dio);

    final goals = await source.listGoals(estado: 'en_progreso');
    final goal = await source.getGoal('goal-1');
    final created = await source.createGoal(
      MetaCreateRequestDto(
        nombre: 'Dormir mejor',
        descripcion: 'Ocho horas',
        fechaObjetivo: DateTime(2026, 12, 31),
        habitoIds: const ['habit-1', 'habit-1'],
      ),
    );
    final updated = await source.updateGoal(
      'goal-1',
      const MetaUpdateRequestDto(estado: null),
    );
    await source.deleteGoal('goal-delete');
    final linked = await source.linkHabit('goal-1', 'habit-2');
    final unlinked = await source.unlinkHabit('goal-1', 'habit-2');

    expect(goals.single.id, 'goal-1');
    expect(goal.id, 'goal-1');
    expect(created.id, 'goal-1');
    expect(updated.id, 'goal-1');
    expect(linked.habitoIds, ['habit-1']);
    expect(unlinked.habitoIds, ['habit-1']);
    expect(requests.map((request) => '${request.method} ${request.path}'), [
      'GET /goals',
      'GET /goals/goal-1',
      'POST /goals',
      'PATCH /goals/goal-1',
      'DELETE /goals/goal-delete',
      'PUT /goals/goal-1/habits/habit-2',
      'DELETE /goals/goal-1/habits/habit-2',
    ]);
    expect(requests[0].queryParameters, {'estado': 'en_progreso'});
    expect(requests[2].data, {
      'nombre': 'Dormir mejor',
      'descripcion': 'Ocho horas',
      'fechaObjetivo': '2026-12-31',
      'habitoIds': ['habit-1'],
    });
    expect(requests[3].data, isEmpty);
    expect(requests[4].data, isNull);
    expect(requests[5].data, isNull);
    expect(requests[6].data, isNull);
  });

  test('omits the estado query when no filter is requested', () async {
    late RequestOptions captured;
    final dio = Dio()
      ..httpClientAdapter = _CallbackAdapter((options) {
        captured = options;
        return _jsonResponse(200, [_goalJson()]);
      });

    await GoalRemoteDataSource(dio).listGoals();

    expect(captured.queryParameters, isEmpty);
  });

  for (final errorCase
      in <
        ({
          String name,
          int status,
          String code,
          Future<Object?> Function(GoalRemoteDataSource source) invoke,
        })
      >[
        (
          name: 'list',
          status: 401,
          code: 'TOKEN_INVALIDO',
          invoke: (source) => source.listGoals(),
        ),
        (
          name: 'detail',
          status: 404,
          code: 'META_NO_ENCONTRADA',
          invoke: (source) => source.getGoal('missing'),
        ),
        (
          name: 'create',
          status: 400,
          code: 'VALIDACION_FALLIDA',
          invoke: (source) =>
              source.createGoal(MetaCreateRequestDto(nombre: '')),
        ),
        (
          name: 'update',
          status: 409,
          code: 'TRANSICION_INVALIDA',
          invoke: (source) =>
              source.updateGoal('goal-1', const MetaUpdateRequestDto()),
        ),
        (
          name: 'delete',
          status: 404,
          code: 'META_NO_ENCONTRADA',
          invoke: (source) => source.deleteGoal('missing'),
        ),
        (
          name: 'link',
          status: 404,
          code: 'HABITO_NO_ENCONTRADO',
          invoke: (source) => source.linkHabit('goal-1', 'missing'),
        ),
        (
          name: 'unlink',
          status: 409,
          code: 'VINCULO_INVALIDO',
          invoke: (source) => source.unlinkHabit('goal-1', 'habit-1'),
        ),
      ]) {
    test('normalizes ${errorCase.name} errors as ApiException', () async {
      final dio = Dio()
        ..httpClientAdapter = _CallbackAdapter(
          (_) => _jsonResponse(errorCase.status, {
            'codigo': errorCase.code,
            'mensaje': 'La operacion fue rechazada.',
            'errores': {'nombre': 'Valor invalido.'},
          }),
        );

      await expectLater(
        errorCase.invoke(GoalRemoteDataSource(dio)),
        throwsA(
          isA<ApiException>()
              .having(
                (error) => error.statusCode,
                'statusCode',
                errorCase.status,
              )
              .having((error) => error.code, 'code', errorCase.code)
              .having(
                (error) => error.errorFor('nombre'),
                'field error',
                'Valor invalido.',
              ),
        ),
      );
    });
  }
}

Map<String, dynamic> _goalJson() {
  return {
    'id': 'goal-1',
    'usuarioId': 'user-1',
    'nombre': 'Dormir mejor',
    'descripcion': null,
    'fechaObjetivo': null,
    'estado': 'en_progreso',
    'habitoIds': ['habit-1'],
    'campoNoConsumido': 0,
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
