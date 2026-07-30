import 'package:dio/dio.dart';

import '../../../../core/network/api_exception.dart';
import '../models/meta_dto.dart';

class GoalRemoteDataSource {
  GoalRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<MetaDto>> listGoals({String? estado}) async {
    return runApiCall(() async {
      final response = await _dio.get<List<dynamic>>('/v1/metas');
      final goals = response.data!
          .map((item) => MetaDto.fromJson(item as Map<String, dynamic>))
          .toList();
      return estado == null
          ? goals
          : goals.where((goal) => goal.estado.apiValue == estado).toList();
    });
  }

  Future<MetaDto> getGoal(String goalId) async {
    return runApiCall(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/v1/metas/$goalId',
      );
      return MetaDto.fromJson(response.data!);
    });
  }

  Future<MetaDto> createGoal(MetaCreateRequestDto request) async {
    return runApiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/metas',
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
      Response<Map<String, dynamic>>? response;
      if (request.toJson().isNotEmpty) {
        response = await _dio.patch<Map<String, dynamic>>(
          '/v1/metas/$goalId',
          data: request.toJson(),
        );
      }
      if (request.estado != null) {
        response = await _dio.patch<Map<String, dynamic>>(
          '/v1/metas/$goalId/estado',
          data: request.stateJson(),
        );
      }
      response ??= await _dio.get<Map<String, dynamic>>('/v1/metas/$goalId');
      return MetaDto.fromJson(response.data!);
    });
  }

  Future<void> deleteGoal(String goalId) async {
    await runApiCall(
      () => _dio.patch<void>(
        '/v1/metas/$goalId/estado',
        data: const {'estado': 'cancelada'},
      ),
    );
  }

  Future<MetaDto> linkHabit(String goalId, String habitId) async {
    return runApiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/metas/$goalId/habitos',
        data: {
          'habitoIds': [habitId],
        },
      );
      return MetaDto.fromJson(response.data!);
    });
  }

  Future<void> unlinkHabit(String goalId, String habitId) async {
    await runApiCall(
      () => _dio.delete<void>('/v1/metas/$goalId/habitos/$habitId'),
    );
  }
}
