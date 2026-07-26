import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitbuilder_mobile/core/network/jwt_interceptor.dart';
import 'package:habitbuilder_mobile/core/storage/token_storage.dart';

void main() {
  test('attaches the stored access token', () async {
    final storage = _MemoryTokenStorage(
      accessToken: 'access-one',
      refreshToken: 'refresh-one',
    );
    final adapter = _CallbackAdapter((options) {
      expect(options.headers['Authorization'], 'Bearer access-one');
      return _jsonResponse(200, '{"ok":true}');
    });
    final dio = Dio()..httpClientAdapter = adapter;
    dio.interceptors.add(
      JwtInterceptor(
        tokenStorage: storage,
        refreshDio: Dio(),
        onUnauthenticated: () async {},
      ),
    );

    final response = await dio.get<Map<String, dynamic>>('/protected');

    expect(response.data, {'ok': true});
  });

  test('does not attach a token when skipAuth is true', () async {
    final adapter = _CallbackAdapter((options) {
      expect(options.headers.containsKey('Authorization'), isFalse);
      return _jsonResponse(200, '{"ok":true}');
    });
    final dio = Dio()..httpClientAdapter = adapter;
    dio.interceptors.add(
      JwtInterceptor(
        tokenStorage: _MemoryTokenStorage(accessToken: 'secret'),
        refreshDio: Dio(),
        onUnauthenticated: () async {},
      ),
    );

    await dio.get<Map<String, dynamic>>(
      '/public',
      options: Options(extra: {'skipAuth': true}),
    );
  });

  test('refreshes tokens and retries once after a 401', () async {
    final storage = _MemoryTokenStorage(
      accessToken: 'expired',
      refreshToken: 'refresh-one',
    );
    var protectedCalls = 0;
    final mainDio = Dio()
      ..httpClientAdapter = _CallbackAdapter((options) {
        protectedCalls++;
        return _jsonResponse(401, '{"mensaje":"expired"}');
      });
    final refreshDio = Dio()
      ..httpClientAdapter = _CallbackAdapter((options) {
        if (options.path == '/auth/refresh') {
          expect(options.data, {'refreshToken': 'refresh-one'});
          return _jsonResponse(
            200,
            '{"accessToken":"access-two","refreshToken":"refresh-two"}',
          );
        }
        expect(options.headers['Authorization'], 'Bearer access-two');
        return _jsonResponse(200, '{"retried":true}');
      });
    mainDio.interceptors.add(
      JwtInterceptor(
        tokenStorage: storage,
        refreshDio: refreshDio,
        onUnauthenticated: () async {},
      ),
    );

    final response = await mainDio.get<Map<String, dynamic>>('/protected');

    expect(protectedCalls, 1);
    expect(response.data, {'retried': true});
    expect(await storage.readAccessToken(), 'access-two');
    expect(await storage.readRefreshToken(), 'refresh-two');
  });

  test(
    'marks the session unauthenticated when no refresh token exists',
    () async {
      var unauthenticated = false;
      final dio = Dio()
        ..httpClientAdapter = _CallbackAdapter(
          (options) => _jsonResponse(401, '{}'),
        );
      dio.interceptors.add(
        JwtInterceptor(
          tokenStorage: _MemoryTokenStorage(accessToken: 'expired'),
          refreshDio: Dio(),
          onUnauthenticated: () async {
            unauthenticated = true;
          },
        ),
      );

      await expectLater(
        dio.get<Map<String, dynamic>>('/protected'),
        throwsA(isA<DioException>()),
      );
      expect(unauthenticated, isTrue);
    },
  );

  test('clears the session when refresh fails', () async {
    final storage = _MemoryTokenStorage(
      accessToken: 'expired',
      refreshToken: 'bad-refresh',
    );
    var unauthenticated = false;
    final dio = Dio()
      ..httpClientAdapter = _CallbackAdapter(
        (options) => _jsonResponse(401, '{}'),
      );
    final refreshDio = Dio()
      ..httpClientAdapter = _CallbackAdapter(
        (options) => _jsonResponse(401, '{}'),
      );
    dio.interceptors.add(
      JwtInterceptor(
        tokenStorage: storage,
        refreshDio: refreshDio,
        onUnauthenticated: () async {
          unauthenticated = true;
          await storage.clear();
        },
      ),
    );

    await expectLater(
      dio.get<Map<String, dynamic>>('/protected'),
      throwsA(isA<DioException>()),
    );
    expect(unauthenticated, isTrue);
    expect(await storage.readAccessToken(), isNull);
  });
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
  _MemoryTokenStorage({this.accessToken, this.refreshToken});

  String? accessToken;
  String? refreshToken;

  @override
  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
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
