import 'package:dio/dio.dart';

import '../../../../core/network/api_exception.dart';

class CommunityDataSource {
  const CommunityDataSource(this._dio);

  final Dio _dio;

  Future<List<Map<String, dynamic>>> listPosts({String? type}) {
    return runApiCall(() async {
      final response = await _dio.get<List<dynamic>>(
        '/v1/comunidad/publicaciones',
        queryParameters: {'limit': 50, if (type != null) 'tipo': type},
      );
      return response.data!
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    });
  }

  Future<Map<String, dynamic>> createPost(String content) {
    return runApiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/comunidad/publicaciones',
        data: {'contenido': content},
      );
      return response.data!;
    });
  }

  Future<void> react(String postId) => runApiCall(
    () => _dio.post<void>('/v1/comunidad/publicaciones/$postId/reaccion'),
  );

  Future<void> unreact(String postId) => runApiCall(
    () => _dio.delete<void>('/v1/comunidad/publicaciones/$postId/reaccion'),
  );

  Future<List<Map<String, dynamic>>> listComments(String postId) {
    return runApiCall(() async {
      final response = await _dio.get<List<dynamic>>(
        '/v1/comunidad/publicaciones/$postId/comentarios',
      );
      return response.data!
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    });
  }

  Future<Map<String, dynamic>> createComment(String postId, String content) {
    return runApiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/comunidad/publicaciones/$postId/comentarios',
        data: {'contenido': content},
      );
      return response.data!;
    });
  }

  Future<void> report(String postId, String reason, String detail) =>
      runApiCall(
        () => _dio.post<void>(
          '/v1/comunidad/publicaciones/$postId/reportes',
          data: {
            'motivo': reason,
            if (detail.trim().isNotEmpty) 'detalle': detail,
          },
        ),
      );

  Future<List<Map<String, dynamic>>> listInspiration({String? type}) {
    return runApiCall(() async {
      final response = await _dio.get<List<dynamic>>(
        '/v1/inspiracion',
        queryParameters: {'limit': 50, if (type != null) 'tipo': type},
      );
      return response.data!
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    });
  }
}
