import 'package:dio/dio.dart';

import '../../../../core/network/api_exception.dart';
import '../models/categoria_dto.dart';
import '../models/habito_dto.dart';
import '../models/meta_option_dto.dart';

class HabitRemoteDataSource {
  HabitRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<CategoriaDto>> listCategories() async {
    // The backend stores categoria as a free-form string and does not expose
    // a category endpoint. Keep the picker useful without a guaranteed 404.
    return const [
      CategoriaDto(id: 'salud', nombre: 'Salud'),
      CategoriaDto(id: 'estudio', nombre: 'Estudio'),
      CategoriaDto(id: 'trabajo', nombre: 'Trabajo'),
      CategoriaDto(id: 'bienestar', nombre: 'Bienestar'),
      CategoriaDto(id: 'personal', nombre: 'Personal'),
    ];
  }

  Future<List<MetaOptionDto>> listGoalOptions() async {
    return runApiCall(() async {
      final response = await _dio.get<List<dynamic>>('/v1/metas');
      return response.data!
          .map((item) => MetaOptionDto.fromJson(item as Map<String, dynamic>))
          .toList();
    });
  }

  Future<List<HabitoDto>> listHabits({String? estado}) async {
    return runApiCall(() async {
      final response = await _dio.get<List<dynamic>>('/v1/habitos');
      final habits = response.data!
          .map((item) => HabitoDto.fromJson(item as Map<String, dynamic>))
          .toList();
      return estado == null
          ? habits
          : habits.where((habit) => habit.estado.apiValue == estado).toList();
    });
  }

  Future<HabitoDto> getHabit(String habitId) async {
    return runApiCall(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/v1/habitos/$habitId',
      );
      return HabitoDto.fromJson(response.data!);
    });
  }

  Future<HabitoDto> createHabit(HabitoCreateRequestDto request) async {
    return runApiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/habitos',
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
        '/v1/habitos/$habitId',
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
        '/v1/habitos/$habitId/pausar',
        data: {
          'inicio': _formatDate(fechaInicio),
          if (fechaFin != null) 'fin': _formatDate(fechaFin),
        },
      );
      return HabitoDto.fromJson(response.data!);
    });
  }

  Future<HabitoDto> resumeHabit(String habitId) async {
    return runApiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/habitos/$habitId/reanudar',
      );
      return HabitoDto.fromJson(response.data!);
    });
  }

  Future<HabitoDto> completeHabit(String habitId) async {
    return runApiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/habitos/$habitId/completar',
      );
      return HabitoDto.fromJson(response.data!);
    });
  }

  Future<void> deleteHabit(String habitId) async {
    await runApiCall(() => _dio.delete<void>('/v1/habitos/$habitId'));
  }
}

String _formatDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
