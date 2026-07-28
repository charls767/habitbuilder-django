import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitbuilder_mobile/core/network/api_exception.dart';
import 'package:habitbuilder_mobile/features/habits/data/datasources/habit_remote_data_source.dart';
import 'package:habitbuilder_mobile/features/habits/data/models/frecuencia_dto.dart';
import 'package:habitbuilder_mobile/features/habits/data/models/habito_dto.dart';
import 'package:habitbuilder_mobile/features/habits/data/repositories/habit_repository_impl.dart';
import 'package:habitbuilder_mobile/features/habits/domain/entities/habito.dart';
import 'package:mocktail/mocktail.dart';

class _MockHabitRemoteDataSource extends Mock
    implements HabitRemoteDataSource {}

void main() {
  group('HabitRemoteDataSource lifecycle', () {
    test(
      'uses the exact lifecycle endpoints, payloads and responses',
      () async {
        final requests = <RequestOptions>[];
        final dio = Dio()
          ..httpClientAdapter = _CallbackAdapter((options) {
            requests.add(options);
            if (options.method == 'DELETE') {
              return ResponseBody.fromString('', 204);
            }

            final state = switch (options.path) {
              '/habits/habit-1/pause' => 'pausado',
              '/habits/habit-1/complete' => 'completado',
              _ => 'activo',
            };
            return _jsonResponse(200, _habitJson(estado: state));
          });
        final dataSource = HabitRemoteDataSource(dio);

        final openPause = await dataSource.pauseHabit(
          'habit-1',
          DateTime(2026, 8, 1, 23, 45),
        );
        final boundedPause = await dataSource.pauseHabit(
          'habit-1',
          DateTime(2026, 8, 2),
          fechaFin: DateTime(2026, 8, 9),
        );
        final resumed = await dataSource.resumeHabit('habit-1');
        final completed = await dataSource.completeHabit('habit-1');
        await dataSource.deleteHabit('habit-1');

        expect(openPause.estado, HabitoEstado.pausado);
        expect(boundedPause.estado, HabitoEstado.pausado);
        expect(resumed.estado, HabitoEstado.activo);
        expect(completed.estado, HabitoEstado.completado);
        expect(requests.map((request) => '${request.method} ${request.path}'), [
          'POST /habits/habit-1/pause',
          'POST /habits/habit-1/pause',
          'POST /habits/habit-1/resume',
          'POST /habits/habit-1/complete',
          'DELETE /habits/habit-1',
        ]);
        expect(requests[0].data, {'fechaInicio': '2026-08-01'});
        expect(requests[1].data, {
          'fechaInicio': '2026-08-02',
          'fechaFin': '2026-08-09',
        });
        expect(
          (requests[0].data as Map<String, dynamic>),
          isNot(contains('usuarioId')),
        );
        expect(requests[2].data, isNull);
        expect(requests[3].data, isNull);
        expect(requests[4].data, isNull);
      },
    );

    for (final errorCase
        in <
          ({
            String name,
            int status,
            String code,
            Future<Object?> Function(HabitRemoteDataSource source) invoke,
          })
        >[
          (
            name: 'pause 400',
            status: 400,
            code: 'FECHA_INVALIDA',
            invoke: (source) =>
                source.pauseHabit('habit-1', DateTime(2026, 8, 1)),
          ),
          (
            name: 'resume 404',
            status: 404,
            code: 'HABITO_NO_ENCONTRADO',
            invoke: (source) => source.resumeHabit('habit-1'),
          ),
          (
            name: 'complete 409',
            status: 409,
            code: 'TRANSICION_INVALIDA',
            invoke: (source) => source.completeHabit('habit-1'),
          ),
          (
            name: 'delete 404',
            status: 404,
            code: 'HABITO_NO_ENCONTRADO',
            invoke: (source) => source.deleteHabit('habit-1'),
          ),
        ]) {
      test('${errorCase.name} remains an ApiException', () async {
        final dio = Dio()
          ..httpClientAdapter = _CallbackAdapter(
            (_) => _jsonResponse(errorCase.status, {
              'codigo': errorCase.code,
              'mensaje': 'La mutacion fue rechazada.',
            }),
          );

        await expectLater(
          errorCase.invoke(HabitRemoteDataSource(dio)),
          throwsA(
            isA<ApiException>()
                .having(
                  (error) => error.statusCode,
                  'statusCode',
                  errorCase.status,
                )
                .having((error) => error.code, 'code', errorCase.code),
          ),
        );
      });
    }
  });

  group('HabitRepositoryImpl lifecycle', () {
    late _MockHabitRemoteDataSource remote;
    late HabitRepositoryImpl repository;

    setUp(() {
      remote = _MockHabitRemoteDataSource();
      repository = HabitRepositoryImpl(remote);
    });

    test('delegates pause dates and maps the returned habit', () async {
      final dto = _habitDto(estado: HabitoEstado.pausado);
      when(
        () => remote.pauseHabit(
          'habit-1',
          DateTime(2026, 8, 1),
          fechaFin: DateTime(2026, 8, 9),
        ),
      ).thenAnswer((_) async => dto);

      final habit = await repository.pauseHabit(
        'habit-1',
        DateTime(2026, 8, 1),
        fechaFin: DateTime(2026, 8, 9),
      );

      expect(habit.id, 'habit-1');
      expect(habit.estado, HabitoEstado.pausado);
      verify(
        () => remote.pauseHabit(
          'habit-1',
          DateTime(2026, 8, 1),
          fechaFin: DateTime(2026, 8, 9),
        ),
      ).called(1);
    });

    test('delegates resume and maps the returned habit', () async {
      when(
        () => remote.resumeHabit('habit-1'),
      ).thenAnswer((_) async => _habitDto());

      final habit = await repository.resumeHabit('habit-1');

      expect(habit.estado, HabitoEstado.activo);
      verify(() => remote.resumeHabit('habit-1')).called(1);
    });

    test('delegates complete and maps the returned habit', () async {
      when(
        () => remote.completeHabit('habit-1'),
      ).thenAnswer((_) async => _habitDto(estado: HabitoEstado.completado));

      final habit = await repository.completeHabit('habit-1');

      expect(habit.estado, HabitoEstado.completado);
      verify(() => remote.completeHabit('habit-1')).called(1);
    });

    test(
      'delegates delete and returns only after the datasource succeeds',
      () async {
        when(() => remote.deleteHabit('habit-1')).thenAnswer((_) async {});

        await repository.deleteHabit('habit-1');

        verify(() => remote.deleteHabit('habit-1')).called(1);
      },
    );

    test(
      'does not turn datasource errors into successful transitions',
      () async {
        const expected = ApiException(
          statusCode: 409,
          code: 'TRANSICION_INVALIDA',
          message: 'La mutacion fue rechazada.',
        );
        when(() => remote.completeHabit('habit-1')).thenThrow(expected);

        await expectLater(
          repository.completeHabit('habit-1'),
          throwsA(same(expected)),
        );
      },
    );
  });
}

Map<String, dynamic> _habitJson({String estado = 'activo'}) {
  return {
    'id': 'habit-1',
    'usuarioId': 'user-1',
    'nombre': 'Leer',
    'descripcion': null,
    'categoriaId': null,
    'metaId': null,
    'fechaInicio': '2026-07-28',
    'frecuencia': {'tipo': 'diaria'},
    'estado': estado,
    'pausas': <Map<String, dynamic>>[],
    'fechaCompletado': estado == 'completado' ? '2026-08-10T12:00:00Z' : null,
    'fechaCreacion': '2026-07-01T00:00:00Z',
    'fechaActualizacion': '2026-07-28T00:00:00Z',
  };
}

HabitoDto _habitDto({HabitoEstado estado = HabitoEstado.activo}) {
  return HabitoDto(
    id: 'habit-1',
    usuarioId: 'user-1',
    nombre: 'Leer',
    fechaInicio: DateTime(2026, 7, 28),
    frecuencia: const FrecuenciaDiariaDto(),
    estado: estado,
    pausas: const [],
    fechaCompletado: estado == HabitoEstado.completado
        ? DateTime.utc(2026, 8, 10, 12)
        : null,
    fechaCreacion: DateTime.utc(2026, 7, 1),
    fechaActualizacion: DateTime.utc(2026, 7, 28),
  );
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
