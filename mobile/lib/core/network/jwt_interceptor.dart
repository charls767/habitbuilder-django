import 'package:dio/dio.dart';

import '../storage/token_storage.dart';

/// Attaches the stored JWT access token to every request.
///
/// The backend contract currently exposes a single expiring session token
/// and no refresh endpoint. A 401 therefore ends the local session instead of
/// calling an unsupported refresh route.
class JwtInterceptor extends Interceptor {
  JwtInterceptor({
    required this.tokenStorage,
    required this.refreshDio,
    required this.onUnauthenticated,
  });

  final TokenStorage tokenStorage;

  /// Kept in the constructor for compatibility with existing dependency
  /// wiring and tests. The current backend has no refresh contract, so it is
  /// intentionally unused.
  final Dio refreshDio;

  final Future<void> Function() onUnauthenticated;

  static const _skipAuthKey = 'skipAuth';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final skipAuth = options.extra[_skipAuthKey] == true;
    if (!skipAuth) {
      final accessToken = await tokenStorage.readAccessToken();
      if (accessToken != null) {
        options.headers['Authorization'] = 'Bearer $accessToken';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final skipAuth = err.requestOptions.extra[_skipAuthKey] == true;

    if (err.response?.statusCode != 401 || skipAuth) {
      handler.next(err);
      return;
    }

    await onUnauthenticated();
    handler.next(err);
  }
}
