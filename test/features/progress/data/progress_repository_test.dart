import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitbuilder_mobile/features/progress/data/datasources/progress_remote_data_source.dart';
import 'package:habitbuilder_mobile/features/progress/data/repositories/progress_repository_impl.dart';
import 'package:habitbuilder_mobile/features/progress/domain/entities/progress_summary.dart';
import 'package:habitbuilder_mobile/features/progress/domain/entities/statistics_summary.dart';

void main() {
  test('maps and aggregates the final HBB-34 progress contract', () async {
    RequestOptions? captured;
    final dio = Dio()
      ..httpClientAdapter = _CallbackAdapter((options) {
        captured = options;
        return _jsonResponse(200, _progressJson());
      });
    final repository = ProgressRepositoryImpl(ProgressRemoteDataSource(dio));

    final summary = await repository.getSummary(ProgressPeriod.month);

    expect(captured?.path, '/v1/progreso');
    expect(captured?.queryParameters, {'periodo': 'mes'});
    expect(summary.period, ProgressPeriod.month);
    expect(summary.from, DateTime(2026, 7, 1));
    expect(summary.to, DateTime(2026, 7, 31));
    expect(summary.completionRate, closeTo(0.84, 0.001));
    expect(summary.currentStreak, 12);
    expect(summary.longestStreak, 28);
    expect(summary.habits, hasLength(2));
    expect(
      summary.habits.first.habitId,
      '00000000-0000-0000-0000-000000000001',
    );
    expect(summary.habits.first.completionRate, closeTo(0.84, 0.001));
    expect(summary.habits.last.hasData, isFalse);
  });

  test('uses the explicit backend state for empty progress', () async {
    final json = [_progressJson().first]
      ..first['estado'] = 'sin_datos'
      ..first['porcentaje'] = 0;
    final dio = Dio()
      ..httpClientAdapter = _CallbackAdapter((_) => _jsonResponse(200, json));
    final repository = ProgressRepositoryImpl(ProgressRemoteDataSource(dio));

    final summary = await repository.getSummary(ProgressPeriod.week);

    expect(summary.hasData, isFalse);
    expect(summary.completionRate, 0);
  });

  test('maps statistics and sends only HBB-34 filter names', () async {
    RequestOptions? captured;
    final dio = Dio()
      ..httpClientAdapter = _CallbackAdapter((options) {
        captured = options;
        return _jsonResponse(200, _statisticsJson());
      });
    final repository = ProgressRepositoryImpl(ProgressRemoteDataSource(dio));

    final statistics = await repository.getStatistics(
      const StatisticsFilter(
        period: ProgressPeriod.month,
        habitId: '00000000-0000-0000-0000-000000000001',
        categoryId: 'bienestar',
      ),
    );

    expect(captured?.path, '/v1/estadisticas');
    expect(captured?.queryParameters, {
      'periodo': 'mes',
      'habitoId': '00000000-0000-0000-0000-000000000001',
      'categoria': 'bienestar',
    });
    expect(statistics.period, ProgressPeriod.month);
    expect(statistics.completionRate, closeTo(0.84, 0.001));
    expect(statistics.sufficientData, isTrue);
    expect(statistics.mostConsistent?.name, 'Leer 20 minutos');
    expect(statistics.mostSkipped?.value, 3);
    expect(statistics.habits.single.streak, 12);
    expect(statistics.habits.single.completed, 28);
  });

  test('uses estado insuficiente instead of inferring missing data', () async {
    final json = _statisticsJson()
      ..['estado'] = 'insuficiente'
      ..['masConsistentes'] = <Object>[]
      ..['masOmitidos'] = <Object>[];
    final dio = Dio()
      ..httpClientAdapter = _CallbackAdapter((_) => _jsonResponse(200, json));
    final repository = ProgressRepositoryImpl(ProgressRemoteDataSource(dio));

    final statistics = await repository.getStatistics(
      const StatisticsFilter(period: ProgressPeriod.week),
    );

    expect(statistics.sufficientData, isFalse);
    expect(statistics.mostConsistent, isNull);
    expect(statistics.habits, isEmpty);
  });
}

List<Map<String, dynamic>> _progressJson() {
  return [
    {
      'habitoId': '00000000-0000-0000-0000-000000000001',
      'periodoDesde': '2026-07-01',
      'periodoHasta': '2026-07-31',
      'rachaActual': 12,
      'rachaMasLarga': 28,
      'porcentaje': 84,
      'estado': 'con_datos',
    },
    {
      'habitoId': '00000000-0000-0000-0000-000000000002',
      'periodoDesde': '2026-07-01',
      'periodoHasta': '2026-07-31',
      'rachaActual': 0,
      'rachaMasLarga': 0,
      'porcentaje': 0,
      'estado': 'sin_datos',
    },
  ];
}

Map<String, dynamic> _statisticsJson() {
  final habit = {
    'habitoId': '00000000-0000-0000-0000-000000000001',
    'nombre': 'Leer 20 minutos',
    'porcentaje': 92,
    'rachaMasLarga': 12,
    'totalHecho': 28,
    'totalOmitido': 3,
  };
  return {
    'periodoDesde': '2026-07-01',
    'periodoHasta': '2026-07-31',
    'porcentaje': 84,
    'mejorRacha': 12,
    'masConsistentes': [habit],
    'masOmitidos': [habit],
    'estado': 'con_datos',
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
