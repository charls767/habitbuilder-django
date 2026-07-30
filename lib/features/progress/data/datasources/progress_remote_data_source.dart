import 'package:dio/dio.dart';

import '../../../../core/network/api_exception.dart';
import '../../domain/entities/progress_summary.dart';
import '../models/progress_summary_dto.dart';

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
}
