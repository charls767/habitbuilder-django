import 'package:dio/dio.dart';

import '../../../../core/network/api_exception.dart';
import '../models/recordatorio_dto.dart';

class ReminderRemoteDataSource {
  ReminderRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<RecordatorioDto>> listByHabit(String habitId) async {
    return runApiCall(() async {
      final response = await _dio.get<List<dynamic>>(
        '/v1/habitos/$habitId/recordatorios',
      );
      return response.data!
          .map((item) => RecordatorioDto.fromJson(item as Map<String, dynamic>))
          .toList();
    });
  }

  Future<RecordatorioDto> create(
    String habitId,
    ReminderRequestDto request,
  ) async {
    return runApiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/habitos/$habitId/recordatorios',
        data: request.toJson(),
      );
      return RecordatorioDto.fromJson(response.data!);
    });
  }

  Future<RecordatorioDto> update(
    String reminderId,
    ReminderRequestDto request,
  ) async {
    return runApiCall(() async {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/v1/recordatorios/$reminderId',
        data: request.toJson(),
      );
      return RecordatorioDto.fromJson(response.data!);
    });
  }

  Future<void> delete(String reminderId) async {
    await runApiCall(() => _dio.delete<void>('/v1/recordatorios/$reminderId'));
  }
}
