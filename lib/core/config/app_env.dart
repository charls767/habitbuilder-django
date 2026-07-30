/// Runtime configuration for the HabitBuilder mobile client.
///
/// Values are injected at build/run time via `--dart-define`, e.g.:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
///
/// The default remains the local mock for UI-only work. Use the backend's
/// port 8080 explicitly for the real `/v1` contract.
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
