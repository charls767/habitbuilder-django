import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitbuilder_mobile/core/network/api_exception.dart';
import 'package:habitbuilder_mobile/features/tracking/data/datasources/tracking_remote_data_source.dart';
import 'package:habitbuilder_mobile/features/tracking/data/models/registro_habito_dto.dart';
import 'package:habitbuilder_mobile/features/tracking/data/repositories/tracking_repository_impl.dart';
import 'package:habitbuilder_mobile/features/tracking/domain/entities/registro_habito.dart';

void main() {
  test('lists and upserts using the tracking HTTP contract', () async {
    final requests = <RequestOptions>[];
    final dio = Dio()
      ..httpClientAdapter = _CallbackAdapter((options) {
        requests.add(options);
        return _jsonResponse(
          options.method == 'POST' ? 201 : 200,
          options.method == 'GET' ? [_recordJson()] : _recordJson(),
        );
      });
    final dataSource = TrackingRemoteDataSource(dio);
    final draft = RegistroHabitoDraft(
      habitId: 'habit with spaces',
      fecha: DateTime(2026, 7, 30, 17),
      estado: EstadoRegistro.parcial,
      nota: 'Media sesion',
    );

    final listed = await dataSource.listByHabit(
      draft.habitId,
      from: DateTime(2026, 7, 1),
      to: DateTime(2026, 7, 31),
    );
    final saved = await dataSource.upsert(
      draft,
      RegistroHabitoRequestDto.fromDraft(draft),
    );

    expect(listed.single.id, 'log-1');
    expect(saved.estado, EstadoRegistro.completado);
    expect(requests[0].method, 'GET');
    expect(requests[0].path, '/v1/habitos/habit%20with%20spaces/registros');
    expect(requests[0].queryParameters, {
      'desde': '2026-07-01',
      'hasta': '2026-07-31',
    });
    expect(requests[1].method, 'POST');
    expect(requests[1].headers['Idempotency-Key'], isNull);
    expect(requests[1].data, {
      'fechaLocal': '2026-07-30',
      'estado': 'parcial',
      'nota': 'Media sesion',
    });
  });

  test('repository maps data source DTOs to domain entities', () async {
    final dio = Dio()
      ..httpClientAdapter = _CallbackAdapter(
        (options) => _jsonResponse(
          options.method == 'GET' ? 200 : 201,
          options.method == 'GET' ? [_recordJson()] : _recordJson(),
        ),
      );
    final repository = TrackingRepositoryImpl(TrackingRemoteDataSource(dio));

    final listed = await repository.listByHabit(
      'habit-1',
      from: DateTime(2026, 7, 30),
      to: DateTime(2026, 7, 30),
    );
    final saved = await repository.upsert(
      RegistroHabitoDraft(
        habitId: 'habit-1',
        fecha: DateTime(2026, 7, 30),
        estado: EstadoRegistro.completado,
      ),
    );

    expect(listed.single, isA<RegistroHabito>());
    expect(saved.id, 'log-1');
  });

  test('normalizes an API conflict', () async {
    final dio = Dio()
      ..httpClientAdapter = _CallbackAdapter(
        (_) => _jsonResponse(409, {
          'codigo': 'IDEMPOTENCY_KEY_REUSED',
          'mensaje': 'La clave ya corresponde a otro contenido.',
        }),
      );
    final dataSource = TrackingRemoteDataSource(dio);
    final draft = RegistroHabitoDraft(
      habitId: 'habit-1',
      fecha: DateTime(2026, 7, 30),
      estado: EstadoRegistro.omitido,
    );

    await expectLater(
      dataSource.upsert(draft, RegistroHabitoRequestDto.fromDraft(draft)),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 409)
            .having((error) => error.code, 'code', 'IDEMPOTENCY_KEY_REUSED'),
      ),
    );
  });
}

Map<String, dynamic> _recordJson() {
  return {
    'id': 'log-1',
    'habitoId': 'habit-1',
    'fechaLocal': '2026-07-30',
    'estado': 'hecho',
    'nota': null,
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
