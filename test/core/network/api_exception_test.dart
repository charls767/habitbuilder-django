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

  test('parses list-shaped field errors and supplies a missing code', () {
    final request = RequestOptions(path: '/auth/register');
    final exception = ApiException.fromDioException(
      DioException(
        requestOptions: request,
        response: Response<Map<String, dynamic>>(
          requestOptions: request,
          statusCode: 422,
          data: {
            'mensaje': 'Revisa los campos.',
            'errores': [
              {'campo': 'email', 'mensaje': 'Correo invalido.'},
              {'campo': 42, 'mensaje': 'Ignored'},
              'invalid item',
            ],
          },
        ),
        type: DioExceptionType.badResponse,
      ),
    );

    expect(exception.statusCode, 422);
    expect(exception.code, 'ERROR_DESCONOCIDO');
    expect(exception.fieldErrors, {'email': 'Correo invalido.'});
    expect(exception.errorFor('missing'), isNull);
    expect(
      exception.toString(),
      'ApiException(422, ERROR_DESCONOCIDO, Revisa los campos.)',
    );
  });

  test('converts non-string map values to field error strings', () {
    final request = RequestOptions(path: '/profile');
    final exception = ApiException.fromDioException(
      DioException(
        requestOptions: request,
        response: Response<Map<String, dynamic>>(
          requestOptions: request,
          data: {
            'codigo': 'INVALID',
            'mensaje': 'Invalid profile.',
            'errores': {'timezone': 99},
          },
        ),
        type: DioExceptionType.badResponse,
      ),
    );

    expect(exception.errorFor('timezone'), '99');
  });

  test('runApiCall returns successful values', () async {
    final result = await runApiCall(() async => 42);

    expect(result, 42);
  });

  test('runApiCall converts DioException into ApiException', () async {
    final request = RequestOptions(path: '/auth/login');

    await expectLater(
      runApiCall<void>(
        () async => throw DioException(
          requestOptions: request,
          response: Response<Map<String, dynamic>>(
            requestOptions: request,
            statusCode: 401,
            data: {
              'codigo': 'INVALID_CREDENTIALS',
              'mensaje': 'Credenciales invalidas.',
            },
          ),
          type: DioExceptionType.badResponse,
        ),
      ),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 401)
            .having((error) => error.code, 'code', 'INVALID_CREDENTIALS'),
      ),
    );
  });
}
