import 'package:dio/dio.dart';

import '../../../../core/network/api_exception.dart';
import '../../domain/entities/registro_habito.dart';
import '../models/registro_habito_dto.dart';

class TrackingRemoteDataSource {
  const TrackingRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<RegistroHabitoDto>> listByHabit(
    String habitId, {
    required DateTime from,
    required DateTime to,
  }) {
    return runApiCall(() async {
      final response = await _dio.get<List<dynamic>>(
        '/habits/${Uri.encodeComponent(habitId)}/logs',
        queryParameters: {
          'desde': formatLocalDate(from),
          'hasta': formatLocalDate(to),
        },
      );
      return (response.data ?? const [])
          .map(
            (item) => RegistroHabitoDto.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false);
    });
  }

  Future<RegistroHabitoDto> upsert(
    RegistroHabitoDraft draft,
    RegistroHabitoRequestDto request,
  ) {
    return runApiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/habits/${Uri.encodeComponent(draft.habitId)}/logs',
        data: request.toJson(),
        options: Options(headers: {'Idempotency-Key': draft.idempotencyKey}),
      );
      return RegistroHabitoDto.fromJson(response.data!);
    });
  }
}
