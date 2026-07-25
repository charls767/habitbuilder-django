import 'package:dio/dio.dart';

/// Base HTTP client for the backend API.
///
/// `baseUrl` currently points at the local mock server (see HBM-7 / HBB-7 —
/// Prism serving `docs/openapi.yaml`). Swap it for the real backend URL once
/// deployed, ideally via a build-time environment variable rather than a
/// hardcoded literal.
///
/// The JWT interceptor (attach the stored access token, handle 401 refresh)
/// is intentionally not implemented here — that lands with the auth screens
/// in HBM-8, once there is a token to attach.
class ApiClient {
  ApiClient({String? baseUrl})
      : dio = Dio(
          BaseOptions(
            baseUrl: baseUrl ?? const String.fromEnvironment(
              'API_BASE_URL',
              defaultValue: 'http://localhost:4010',
            ),
          ),
        );

  final Dio dio;
}
