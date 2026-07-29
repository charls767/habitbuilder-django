import 'package:dio/dio.dart';

import '../../../../core/network/api_exception.dart';
import '../models/meta_dto.dart';

class GoalRemoteDataSource {
  GoalRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<MetaDto>> listGoals({String? estado}) async {
    return runApiCall(() async {
      final response = await _dio.get<List<dynamic>>(
        '/goals',
        queryParameters: estado == null ? null : {'estado': estado},
      );
      return response.data!
          .map((item) => MetaDto.fromJson(item as Map<String, dynamic>))
          .toList();
    });
  }

  Future<MetaDto> getGoal(String goalId) async {
    return runApiCall(() async {
      final response = await _dio.get<Map<String, dynamic>>('/goals/$goalId');
      return MetaDto.fromJson(response.data!);
    });
  }

  Future<MetaDto> createGoal(MetaCreateRequestDto request) async {
    return runApiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/goals',
        data: request.toJson(),
      );
      return MetaDto.fromJson(response.data!);
    });
  }

  Future<MetaDto> updateGoal(
    String goalId,
    MetaUpdateRequestDto request,
  ) async {
    return runApiCall(() async {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/goals/$goalId',
        data: request.toJson(),
      );
      return MetaDto.fromJson(response.data!);
    });
  }

  Future<void> deleteGoal(String goalId) async {
    await runApiCall(() => _dio.delete<void>('/goals/$goalId'));
  }

  Future<MetaDto> linkHabit(String goalId, String habitId) async {
    return runApiCall(() async {
      final response = await _dio.put<Map<String, dynamic>>(
        '/goals/$goalId/habits/$habitId',
      );
      return MetaDto.fromJson(response.data!);
    });
  }

  Future<MetaDto> unlinkHabit(String goalId, String habitId) async {
    return runApiCall(() async {
      final response = await _dio.delete<Map<String, dynamic>>(
        '/goals/$goalId/habits/$habitId',
      );
      return MetaDto.fromJson(response.data!);
    });
  }
}
