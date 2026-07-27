/// Runtime configuration for the HabitBuilder mobile client.
///
/// Values are injected at build/run time via `--dart-define`, e.g.:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4010
///
/// The default points at the local Prism mock server (see
/// `docs/openapi.yaml` and `npm run mock:api`) so the app is never blocked
/// on the real backend.
abstract final class AppEnv {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:4010',
  );

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);

  static const bool enableHttpLogs = bool.fromEnvironment(
    'ENABLE_HTTP_LOGS',
    defaultValue: true,
  );

  static const String termsVersion = String.fromEnvironment(
    'TERMS_VERSION',
    defaultValue: '2026-01',
  );

  static const String privacyVersion = String.fromEnvironment(
    'PRIVACY_VERSION',
    defaultValue: '2026-01',
  );
}
