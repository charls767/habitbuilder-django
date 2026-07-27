import '../entities/usuario.dart';

/// Contract the presentation layer depends on. `data/repositories` provides
/// the real implementation (talking to the API); tests can provide a fake.
abstract interface class AuthRepository {
  Future<Usuario> register({
    required String nombre,
    required String email,
    required String password,
    required bool aceptaTerminos,
    required bool aceptaPrivacidad,
    required String versionTerminos,
    required String versionPrivacidad,
  });

  /// Authenticates and persists the resulting token pair via `TokenStorage`.
  /// Does not, by itself, flip `AuthSessionController` — the caller
  /// (`AuthController`) does that once this completes successfully.
  Future<void> login({required String email, required String password});

  Future<void> requestPasswordReset({required String email});

  Future<void> confirmPasswordReset({
    required String token,
    required String newPassword,
  });

  Future<void> logout();
}
