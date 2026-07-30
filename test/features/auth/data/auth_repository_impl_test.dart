import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitbuilder_mobile/core/storage/token_storage.dart';
import 'package:habitbuilder_mobile/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:habitbuilder_mobile/features/auth/data/repositories/auth_repository_impl.dart';

void main() {
  test(
    'executes the complete auth contract and stores the token pair',
    () async {
      final requests = <RequestOptions>[];
      final dio = Dio()
        ..httpClientAdapter = _CallbackAdapter((options) {
          requests.add(options);
          return switch (options.path) {
            '/v1/auth/register' => _jsonResponse(
              201,
              jsonEncode({
                'usuario': {
                  'id': 'user-1',
                  'nombre': 'Camila',
                  'email': 'camila@example.com',
                  'rol': 'regular',
                  'estado': 'activo',
                },
              }),
            ),
            '/v1/auth/login' => _jsonResponse(
              200,
              jsonEncode({
                'token': 'access',
                'expiraEn': '2026-07-26T13:00:00Z',
              }),
            ),
            '/v1/auth/reset/request' => _jsonResponse(200, '{}'),
            '/v1/auth/reset/confirm' => _jsonResponse(200, '{}'),
            _ => _jsonResponse(404, '{}'),
          };
        });
      final storage = _MemoryTokenStorage();
      final repository = AuthRepositoryImpl(AuthRemoteDataSource(dio), storage);

      final user = await repository.register(
        nombre: 'Camila',
        email: 'camila@example.com',
        password: 'Segura123',
        aceptaTerminos: true,
        aceptaPrivacidad: true,
        versionTerminos: '2026-01',
        versionPrivacidad: '2026-01',
      );
      await repository.login(
        email: 'camila@example.com',
        password: 'Segura123',
      );
      await repository.requestPasswordReset(email: 'camila@example.com');
      await repository.confirmPasswordReset(
        token: 'reset-token',
        newPassword: 'NuevaSegura123',
      );

      expect(user.id, 'user-1');
      expect(user.nombre, 'Camila');
      expect(user.fechaRegistro, isA<DateTime>());
      expect(storage.accessToken, 'access');
      expect(storage.refreshToken, isEmpty);
      expect(requests, hasLength(4));
      expect(requests.first.extra['skipAuth'], isTrue);
      expect(requests.first.data, containsPair('terminosAceptados', true));
      expect(requests[2].data, {'email': 'camila@example.com'});
      expect(requests[3].data, {
        'token': 'reset-token',
        'nuevaPassword': 'NuevaSegura123',
      });

      await repository.logout();
      expect(storage.cleared, isTrue);
    },
  );
}

ResponseBody _jsonResponse(int status, String body) {
  return ResponseBody.fromString(
    body,
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

class _CallbackAdapter implements HttpClientAdapter {
  _CallbackAdapter(this.callback);

  final ResponseBody Function(RequestOptions options) callback;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return callback(options);
  }

  @override
  void close({bool force = false}) {}
}

class _MemoryTokenStorage implements TokenStorage {
  String? accessToken;
  String? refreshToken;
  bool cleared = false;

  @override
  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
    cleared = true;
  }

  @override
  Future<String?> readAccessToken() async => accessToken;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
  }
}
