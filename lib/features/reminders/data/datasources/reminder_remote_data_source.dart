import 'package:dio/dio.dart';

import '../../../../core/network/api_exception.dart';
import '../models/recordatorio_dto.dart';

class ReminderRemoteDataSource {
  ReminderRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<RecordatorioDto>> listByHabit(String habitId) async {
    return runApiCall(() async {
      final response = await _dio.get<List<dynamic>>(
        '/habits/$habitId/reminders',
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
        '/habits/$habitId/reminders',
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
        '/reminders/$reminderId',
        data: request.toJson(),
      );
      return RecordatorioDto.fromJson(response.data!);
    });
  }

  Future<void> delete(String reminderId) async {
    await runApiCall(() => _dio.delete<void>('/reminders/$reminderId'));
  }
}
