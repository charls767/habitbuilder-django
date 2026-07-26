import 'package:dio/dio.dart';

import '../storage/token_storage.dart';

/// Attaches the stored JWT access token to every request and transparently
/// refreshes it on a 401, retrying the original call once.
///
/// If the refresh itself fails (expired/invalid refresh token),
/// [onUnauthenticated] is invoked (clearing the stored tokens) so the app
/// can redirect to the login screen — see `AuthSessionController` and
/// `lib/core/router/app_router.dart`.
class JwtInterceptor extends Interceptor {
  JwtInterceptor({
    required this.tokenStorage,
    required this.refreshDio,
    required this.onUnauthenticated,
  });

  final TokenStorage tokenStorage;

  /// A bare [Dio] instance (no interceptors attached) pointed at the same
  /// base URL, used only for the `/auth/refresh` call and for retrying the
  /// original request — avoids re-entering this interceptor recursively.
  final Dio refreshDio;

  final Future<void> Function() onUnauthenticated;

  static const _skipAuthKey = 'skipAuth';
  static const _isRetryKey = 'isRetry';

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
    final isRetry = err.requestOptions.extra[_isRetryKey] == true;
    final skipAuth = err.requestOptions.extra[_skipAuthKey] == true;

    if (err.response?.statusCode != 401 || isRetry || skipAuth) {
      handler.next(err);
      return;
    }

    final refreshToken = await tokenStorage.readRefreshToken();
    if (refreshToken == null) {
      await onUnauthenticated();
      handler.next(err);
      return;
    }

    try {
      final response = await refreshDio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
        options: Options(extra: {_skipAuthKey: true}),
      );

      final data = response.data!;
      await tokenStorage.saveTokens(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
      );

      final retryOptions = err.requestOptions
        ..extra[_isRetryKey] = true
        ..headers['Authorization'] = 'Bearer ${data['accessToken']}';

      final retryResponse = await refreshDio.fetch<dynamic>(retryOptions);
      handler.resolve(retryResponse);
    } on Object {
      await onUnauthenticated();
      handler.next(err);
    }
  }
}
