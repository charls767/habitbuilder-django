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

  Future<List<Map<String, dynamic>>> users({
    String? search,
    String? status,
    String? role,
    int offset = 0,
  }) {
    return runApiCall(() async {
      final response = await _dio.get<List<dynamic>>(
        '/v1/admin/usuarios',
        queryParameters: {
          'limit': 50,
          'offset': offset,
          ...?search == null || search.trim().isEmpty
              ? null
              : {'buscar': search.trim()},
          ...?status == null ? null : {'estado': status},
          ...?role == null ? null : {'rol': role},
        },
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

  Future<List<Map<String, dynamic>>> moderationQueue({
    String status = 'pendiente',
    int offset = 0,
  }) {
    return runApiCall(() async {
      final response = await _dio.get<List<dynamic>>(
        '/v1/admin/moderacion/reportes',
        queryParameters: {'estado': status, 'limit': 50, 'offset': offset},
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

  Future<Map<String, dynamic>> getPublication(String id) async {
    return runApiCall(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/v1/comunidad/publicaciones/$id',
      );
      return response.data!;
    });
  }

  Future<List<Map<String, dynamic>>> inspiration({
    String? type,
    String? search,
    bool? published,
    bool? featured,
    int offset = 0,
  }) {
    return runApiCall(() async {
      final response = await _dio.get<List<dynamic>>(
        '/v1/admin/inspiracion',
        queryParameters: {
          'limit': 50,
          'offset': offset,
          ...?type == null ? null : {'tipo': type},
          ...?search == null || search.trim().isEmpty
              ? null
              : {'buscar': search.trim()},
          ...?published == null ? null : {'publicado': published},
          ...?featured == null ? null : {'destacado': featured},
        },
      );
      return response.data!
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    });
  }

  Future<Map<String, dynamic>> createInspiration(
    Map<String, dynamic> data,
  ) async {
    return runApiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/admin/inspiracion',
        data: data,
      );
      return response.data!;
    });
  }

  Future<Map<String, dynamic>> updateInspiration(
    String id,
    Map<String, dynamic> data,
  ) async {
    return runApiCall(() async {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/v1/admin/inspiracion/$id',
        data: data,
      );
      return response.data!;
    });
  }

  Future<void> deleteInspiration(String id) =>
      runApiCall(() => _dio.delete<void>('/v1/admin/inspiracion/$id'));
}
