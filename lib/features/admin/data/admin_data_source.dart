import 'package:dio/dio.dart';

import '../../../../core/network/api_exception.dart';

class AdminDataSource {
  const AdminDataSource(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> usage({String? from, String? to}) {
    return runApiCall(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/v1/admin/reportes/uso',
        queryParameters: {
          ...?from == null ? null : {'desde': from},
          ...?to == null ? null : {'hasta': to},
        },
      );
      return response.data!;
    });
  }

  Future<List<Map<String, dynamic>>> users() {
    return runApiCall(() async {
      final response = await _dio.get<List<dynamic>>(
        '/v1/admin/usuarios',
        queryParameters: const {'limit': 50, 'offset': 0},
      );
      return response.data!
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    });
  }

  Future<void> changeUserStatus(String id, String status, String reason) =>
      runApiCall(
        () => _dio.patch<void>(
          '/v1/admin/usuarios/$id/estado',
          data: {'estado': status, 'razon': reason},
        ),
      );

  Future<void> changeUserRole(String id, String role, String reason) =>
      runApiCall(
        () => _dio.patch<void>(
          '/v1/admin/usuarios/$id/rol',
          data: {'rol': role, 'razon': reason},
        ),
      );

  Future<List<Map<String, dynamic>>> moderationQueue() {
    return runApiCall(() async {
      final response = await _dio.get<List<dynamic>>(
        '/v1/admin/moderacion/reportes',
        queryParameters: const {
          'estado': 'pendiente',
          'limit': 50,
          'offset': 0,
        },
      );
      return response.data!
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    });
  }

  Future<void> resolveModeration(String id, String resolution, String reason) =>
      runApiCall(
        () => _dio.patch<void>(
          '/v1/admin/moderacion/reportes/$id',
          data: {'resolucion': resolution, 'razon': reason},
        ),
      );
}
