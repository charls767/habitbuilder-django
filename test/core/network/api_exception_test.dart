import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitbuilder_mobile/core/network/api_exception.dart';

void main() {
  test('parses API code, message and field errors', () {
    final request = RequestOptions(path: '/auth/register');
    final dioError = DioException(
      requestOptions: request,
      response: Response<Map<String, dynamic>>(
        requestOptions: request,
        statusCode: 400,
        data: {
          'codigo': 'VALIDACION_FALLIDA',
          'mensaje': 'Revisa los campos enviados.',
          'errores': {
            'email': 'El formato del correo no es válido.',
            'password': 'La contraseña es débil.',
          },
        },
      ),
      type: DioExceptionType.badResponse,
    );

    final exception = ApiException.fromDioException(dioError);

    expect(exception.statusCode, 400);
    expect(exception.code, 'VALIDACION_FALLIDA');
    expect(exception.errorFor('email'), 'El formato del correo no es válido.');
    expect(exception.errorFor('password'), 'La contraseña es débil.');
  });

  test('uses a safe network fallback for an unknown response', () {
    final exception = ApiException.fromDioException(
      DioException(
        requestOptions: RequestOptions(path: '/auth/login'),
        message: 'Connection timed out',
        type: DioExceptionType.connectionTimeout,
      ),
    );

    expect(exception.code, 'ERROR_RED');
    expect(exception.fieldErrors, isEmpty);
  });
}
