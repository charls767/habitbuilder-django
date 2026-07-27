import 'package:dio/dio.dart';

import '../../../../core/network/api_exception.dart';
import '../models/token_pair_dto.dart';
import '../models/usuario_dto.dart';

/// Thin wrapper around the `/auth/*` endpoints. Knows nothing about token
/// storage or app-wide session state — that's `AuthRepositoryImpl`'s job.
class AuthRemoteDataSource {
  AuthRemoteDataSource(this._dio);

  final Dio _dio;

  Future<UsuarioDto> register({
    required String nombre,
    required String email,
    required String password,
    required bool aceptaTerminos,
    required bool aceptaPrivacidad,
    required String versionTerminos,
    required String versionPrivacidad,
  }) async {
    return runApiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/register',
        data: {
          'nombre': nombre,
          'email': email,
          'password': password,
          'aceptaTerminos': aceptaTerminos,
          'aceptaPrivacidad': aceptaPrivacidad,
          'versionTerminos': versionTerminos,
          'versionPrivacidad': versionPrivacidad,
        },
        options: Options(extra: const {'skipAuth': true}),
      );
      return UsuarioDto.fromJson(response.data!);
    });
  }

  Future<TokenPairDto> login({
    required String email,
    required String password,
  }) async {
    return runApiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'email': email, 'password': password},
        options: Options(extra: const {'skipAuth': true}),
      );
      return TokenPairDto.fromJson(response.data!);
    });
  }

  Future<void> requestPasswordReset({required String email}) async {
    await runApiCall(
      () => _dio.post<void>(
        '/auth/password-reset/request',
        data: {'email': email},
        options: Options(extra: const {'skipAuth': true}),
      ),
    );
  }

  Future<void> confirmPasswordReset({
    required String token,
    required String newPassword,
  }) async {
    await runApiCall(
      () => _dio.post<void>(
        '/auth/password-reset/confirm',
        data: {'token': token, 'newPassword': newPassword},
        options: Options(extra: const {'skipAuth': true}),
      ),
    );
  }
}
