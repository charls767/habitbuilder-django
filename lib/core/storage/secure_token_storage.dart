import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin wrapper around secure, encrypted storage for the JWT access token.
///
/// Deliberately backed by `flutter_secure_storage`, never `SharedPreferences`
/// — auth tokens are sensitive and must not sit in plaintext prefs.
/// Read/write calls land with the login flow in HBM-8.
class SecureTokenStorage {
  SecureTokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _accessTokenKey = 'access_token';

  final FlutterSecureStorage _storage;

  Future<String?> readAccessToken() => _storage.read(key: _accessTokenKey);

  Future<void> writeAccessToken(String token) =>
      _storage.write(key: _accessTokenKey, value: token);

  Future<void> clear() => _storage.delete(key: _accessTokenKey);
}
