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
      final response = await _dio.get<Map<String, dynamic>>(
        '/progress',
        queryParameters: {'periodo': period.apiValue},
      );
      return ProgressSummaryDto.fromJson(response.data!);
    });
  }

  Future<StatisticsSummaryDto> getStatistics(StatisticsFilter filter) {
    return runApiCall(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/statistics',
        queryParameters: {
          'periodo': filter.period.apiValue,
          if (filter.habitId != null) 'habitId': filter.habitId,
          if (filter.categoryId != null) 'categoryId': filter.categoryId,
        },
      );
      return StatisticsSummaryDto.fromJson(response.data!);
    });
  }
}
