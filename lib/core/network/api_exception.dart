import 'package:dio/dio.dart';

Future<T> runApiCall<T>(Future<T> Function() request) async {
  try {
    return await request();
  } on DioException catch (error) {
    throw ApiException.fromDioException(error);
  }
}

/// Normalized error surfaced to the domain/presentation layers, so features
/// never need to know about `DioException` or the raw `{codigo, mensaje}`
/// error shape returned by the API (see `Error` schema in `docs/openapi.yaml`).
class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
    this.fieldErrors = const {},
  });

  factory ApiException.fromDioException(DioException error) {
    final response = error.response;
    final data = response?.data;

    if (data is Map<String, dynamic> && data['mensaje'] is String) {
      return ApiException(
        statusCode: response?.statusCode,
        code: data['codigo'] as String? ?? 'ERROR_DESCONOCIDO',
        message: data['mensaje'] as String,
        fieldErrors: _parseFieldErrors(data['errores']),
      );
    }

    return ApiException(
      statusCode: response?.statusCode,
      code: 'ERROR_RED',
      message: error.message ?? 'Ocurrió un error de red inesperado.',
    );
  }

  final int? statusCode;
  final String code;
  final String message;
  final Map<String, String> fieldErrors;

  String? errorFor(String field) => fieldErrors[field];

  @override
  String toString() => 'ApiException($statusCode, $code, $message)';

  static Map<String, String> _parseFieldErrors(Object? rawErrors) {
    if (rawErrors is Map<String, dynamic>) {
      return rawErrors.map(
        (field, message) => MapEntry(field, message.toString()),
      );
    }

    if (rawErrors is List<dynamic>) {
      final parsed = <String, String>{};
      for (final item in rawErrors) {
        if (item is Map<String, dynamic>) {
          final field = item['campo'];
          final message = item['mensaje'];
          if (field is String && message is String) {
            parsed[field] = message;
          }
        }
      }
      return parsed;
    }

    return const {};
  }
}
