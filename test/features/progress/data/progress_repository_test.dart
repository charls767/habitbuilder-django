import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitbuilder_mobile/features/progress/data/datasources/progress_remote_data_source.dart';
import 'package:habitbuilder_mobile/features/progress/data/repositories/progress_repository_impl.dart';
import 'package:habitbuilder_mobile/features/progress/domain/entities/progress_summary.dart';

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
