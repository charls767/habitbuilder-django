import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitbuilder_mobile/features/progress/data/datasources/progress_remote_data_source.dart';
import 'package:habitbuilder_mobile/features/progress/data/repositories/progress_repository_impl.dart';
import 'package:habitbuilder_mobile/features/progress/domain/entities/progress_summary.dart';
import 'package:habitbuilder_mobile/features/progress/domain/entities/statistics_summary.dart';

void main() {
  test(
    'maps the provisional progress contract through the repository',
    () async {
      RequestOptions? captured;
      final dio = Dio()
        ..httpClientAdapter = _CallbackAdapter((options) {
          captured = options;
          return _jsonResponse(200, _summaryJson());
        });
      final repository = ProgressRepositoryImpl(ProgressRemoteDataSource(dio));

      final summary = await repository.getSummary(ProgressPeriod.month);

      expect(captured?.path, '/progress');
      expect(captured?.queryParameters, {'periodo': 'mes'});
      expect(summary.period, ProgressPeriod.week);
      expect(summary.completionRate, 0.84);
      expect(summary.currentStreak, 12);
      expect(summary.longestStreak, 28);
      expect(summary.days.single.date, DateTime(2026, 7, 30));
      expect(summary.days.single.completed, 4);
    },
  );

  test('rejects unknown period values instead of guessing', () async {
    final json = _summaryJson()..['periodo'] = 'trimestre';
    final dio = Dio()
      ..httpClientAdapter = _CallbackAdapter((_) => _jsonResponse(200, json));
    final repository = ProgressRepositoryImpl(ProgressRemoteDataSource(dio));

    await expectLater(
      repository.getSummary(ProgressPeriod.week),
      throwsA(isA<StateError>()),
    );
  });

  test('maps statistics and sends only active filters', () async {
    RequestOptions? captured;
    final dio = Dio()
      ..httpClientAdapter = _CallbackAdapter((options) {
        captured = options;
        return _jsonResponse(200, _statisticsJson());
      });
    final repository = ProgressRepositoryImpl(ProgressRemoteDataSource(dio));

    final statistics = await repository.getStatistics(
      const StatisticsFilter(period: ProgressPeriod.month, habitId: 'hab_001'),
    );

    expect(captured?.path, '/statistics');
    expect(captured?.queryParameters, {'periodo': 'mes', 'habitId': 'hab_001'});
    expect(statistics.sufficientData, isTrue);
    expect(statistics.mostConsistent?.name, 'Leer 20 minutos');
    expect(statistics.mostSkipped?.value, 3);
    expect(statistics.habits.single.streak, 12);
  });

  test('supports an insufficient statistics response', () async {
    final json = _statisticsJson()
      ..['suficientesDatos'] = false
      ..['habitoMasConstante'] = null
      ..['habitoMasOmitido'] = null
      ..['habitos'] = <Object>[];
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

Map<String, dynamic> _summaryJson() {
  return {
    'periodo': 'semana',
    'desde': '2026-07-27',
    'hasta': '2026-08-02',
    'porcentajeCumplimiento': 0.84,
    'rachaActual': 12,
    'rachaMasLarga': 28,
    'completados': 28,
    'programados': 35,
    'cambioPeriodoAnterior': 0.06,
    'dias': [
      {
        'fecha': '2026-07-30',
        'porcentajeCumplimiento': 0.8,
        'completados': 4,
        'programados': 5,
      },
    ],
  };
}

Map<String, dynamic> _statisticsJson() {
  return {
    'periodo': 'mes',
    'desde': '2026-07-01',
    'hasta': '2026-07-31',
    'porcentajeCumplimiento': 0.84,
    'mejorRacha': 12,
    'suficientesDatos': true,
    'habitoMasConstante': {
      'id': 'hab_001',
      'nombre': 'Leer 20 minutos',
      'valor': 0.92,
    },
    'habitoMasOmitido': {'id': 'hab_002', 'nombre': 'Meditar', 'valor': 3},
    'habitos': [
      {
        'id': 'hab_001',
        'nombre': 'Leer 20 minutos',
        'porcentajeCumplimiento': 0.92,
        'racha': 12,
        'omitidos': 1,
      },
    ],
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
