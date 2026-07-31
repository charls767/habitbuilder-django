import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../config/app_env.dart';
import '../storage/token_storage.dart';
import 'auth_session_controller.dart';
import 'jwt_interceptor.dart';

part 'dio_client.g.dart';

BaseOptions _baseOptions() => BaseOptions(
  baseUrl: AppEnv.apiBaseUrl,
  connectTimeout: AppEnv.connectTimeout,
  receiveTimeout: AppEnv.receiveTimeout,
  headers: const {'Content-Type': 'application/json'},
  responseDecoder: (bytes, _, _) => utf8.decode(bytes, allowMalformed: true),
);

/// Bare Dio instance retained for compatibility with the network provider.
/// The current backend has no refresh endpoint.
@Riverpod(keepAlive: true)
Dio refreshDio(Ref ref) => Dio(_baseOptions());

/// The Dio client every feature's remote data source should depend on.
///
/// Wires the JWT interceptor (attaches the access token and closes the session
/// on 401)
/// and, outside of release builds, request/response logging.
@Riverpod(keepAlive: true)
Dio dio(Ref ref) {
  final dio = Dio(_baseOptions());

  dio.interceptors.add(
    JwtInterceptor(
      tokenStorage: ref.watch(tokenStorageProvider),
      refreshDio: ref.watch(refreshDioProvider),
      onUnauthenticated: () => ref
          .read(authSessionControllerProvider.notifier)
          .markUnauthenticated(),
    ),
  );

  if (AppEnv.enableHttpLogs) {
    dio.interceptors.add(
      LogInterceptor(
        requestHeader: false,
        requestBody: false,
        responseHeader: false,
        responseBody: false,
        error: false,
      ),
    );
  }

  return dio;
}
