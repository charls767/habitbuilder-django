import 'package:dio/dio.dart';

import '../../../../core/network/api_exception.dart';
import '../../domain/entities/progress_summary.dart';
import '../../domain/entities/statistics_summary.dart';
import '../models/progress_summary_dto.dart';
import '../models/statistics_summary_dto.dart';

class ProgressRemoteDataSource {
  const ProgressRemoteDataSource(this._dio);

  final Dio _dio;

  Future<ProgressSummaryDto> getSummary(ProgressPeriod period) {
    return runApiCall(() async {
      final response = await _dio.get<List<dynamic>>(
        '/v1/progreso',
        queryParameters: {'periodo': period.apiValue},
      );
      return ProgressSummaryDto.fromJson(response.data!, period);
    });
  }

  Future<StatisticsSummaryDto> getStatistics(StatisticsFilter filter) {
    return runApiCall(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/v1/estadisticas',
        queryParameters: {
          'periodo': filter.period.apiValue,
          if (filter.habitId != null) 'habitoId': filter.habitId,
          if (filter.categoryId != null) 'categoria': filter.categoryId,
        },
      );
      return StatisticsSummaryDto.fromJson(response.data!, filter.period);
    });
  }
}
