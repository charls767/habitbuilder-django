import 'package:dio/dio.dart';

import '../../../../core/network/api_exception.dart';
import '../models/categoria_dto.dart';
import '../models/habito_dto.dart';
import '../models/meta_option_dto.dart';

class HabitRemoteDataSource {
  HabitRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<CategoriaDto>> listCategories() async {
    return runApiCall(() async {
      final response = await _dio.get<List<dynamic>>('/categories');
      return response.data!
          .map((item) => CategoriaDto.fromJson(item as Map<String, dynamic>))
          .toList();
    });
  }

  Future<List<MetaOptionDto>> listGoalOptions() async {
    return runApiCall(() async {
      final response = await _dio.get<List<dynamic>>('/goals');
      return response.data!
          .map((item) => MetaOptionDto.fromJson(item as Map<String, dynamic>))
          .toList();
    });
  }

  Future<List<HabitoDto>> listHabits({String? estado}) async {
    return runApiCall(() async {
      final response = await _dio.get<List<dynamic>>(
        '/habits',
        queryParameters: estado == null ? null : {'estado': estado},
      );
      return response.data!
          .map((item) => HabitoDto.fromJson(item as Map<String, dynamic>))
          .toList();
    });
  }

  Future<HabitoDto> getHabit(String habitId) async {
    return runApiCall(() async {
      final response = await _dio.get<Map<String, dynamic>>('/habits/$habitId');
      return HabitoDto.fromJson(response.data!);
    });
  }

  Future<HabitoDto> createHabit(HabitoCreateRequestDto request) async {
    return runApiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/habits',
        data: request.toJson(),
      );
      return HabitoDto.fromJson(response.data!);
    });
  }

  Future<HabitoDto> updateHabit(
    String habitId,
    HabitoUpdateRequestDto request,
  ) async {
    return runApiCall(() async {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/habits/$habitId',
        data: request.toJson(),
      );
      return HabitoDto.fromJson(response.data!);
    });
  }

  Future<HabitoDto> pauseHabit(
    String habitId,
    DateTime fechaInicio, {
    DateTime? fechaFin,
  }) async {
    return runApiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/habits/$habitId/pause',
        data: {
          'fechaInicio': _formatDate(fechaInicio),
          if (fechaFin != null) 'fechaFin': _formatDate(fechaFin),
        },
      );
      return HabitoDto.fromJson(response.data!);
    });
  }

  Future<HabitoDto> resumeHabit(String habitId) async {
    return runApiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/habits/$habitId/resume',
      );
      return HabitoDto.fromJson(response.data!);
    });
  }

  Future<HabitoDto> completeHabit(String habitId) async {
    return runApiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/habits/$habitId/complete',
      );
      return HabitoDto.fromJson(response.data!);
    });
  }

  Future<void> deleteHabit(String habitId) async {
    await runApiCall(() => _dio.delete<void>('/habits/$habitId'));
  }
}

String _formatDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
