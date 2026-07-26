import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitbuilder_mobile/core/config/app_env.dart';
import 'package:habitbuilder_mobile/core/network/auth_session_controller.dart';
import 'package:habitbuilder_mobile/core/storage/token_storage.dart';
import 'package:habitbuilder_mobile/features/auth/domain/entities/usuario.dart';
import 'package:habitbuilder_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:habitbuilder_mobile/features/auth/presentation/providers/auth_providers.dart';

void main() {
  test('login marks the shared session authenticated', () async {
    final repository = _FakeAuthRepository();
    final container = _container(repository);
    addTearDown(container.dispose);
    await container.read(authSessionControllerProvider.future);

    final success = await container
        .read(authControllerProvider.notifier)
        .login(email: 'camila@example.com', password: 'Segura123');

    expect(success, isTrue);
    expect(repository.loginCalls, 1);
    expect(container.read(authSessionControllerProvider).value, isTrue);
  });

  test('registration supplies versioned consent', () async {
    final repository = _FakeAuthRepository();
    final container = _container(repository);
    addTearDown(container.dispose);

    final success = await container
        .read(authControllerProvider.notifier)
        .register(
          nombre: 'Camila',
          email: 'camila@example.com',
          password: 'Segura123',
          aceptaTerminos: true,
          aceptaPrivacidad: true,
        );

    expect(success, isTrue);
    expect(repository.termsVersion, AppEnv.termsVersion);
    expect(repository.privacyVersion, AppEnv.privacyVersion);
  });

  test('error state can be cleared without retrying', () async {
    final repository = _FakeAuthRepository()..failure = StateError('failed');
    final container = _container(repository);
    addTearDown(container.dispose);

    final success = await container
        .read(authControllerProvider.notifier)
        .requestPasswordReset(email: 'camila@example.com');
    expect(success, isFalse);
    expect(container.read(authControllerProvider).hasError, isTrue);

    container.read(authControllerProvider.notifier).clearError();
    expect(container.read(authControllerProvider).hasError, isFalse);
  });

  test('confirmation delegates token and password', () async {
    final repository = _FakeAuthRepository();
    final container = _container(repository);
    addTearDown(container.dispose);

    final success = await container
        .read(authControllerProvider.notifier)
        .confirmPasswordReset(
          token: 'reset-token',
          newPassword: 'NuevaSegura123',
        );

    expect(success, isTrue);
    expect(repository.resetToken, 'reset-token');
    expect(repository.newPassword, 'NuevaSegura123');
  });
}

ProviderContainer _container(_FakeAuthRepository repository) {
  return ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(repository),
      tokenStorageProvider.overrideWithValue(_MemoryTokenStorage()),
    ],
  );
}

class _FakeAuthRepository implements AuthRepository {
  Object? failure;
  int loginCalls = 0;
  String? termsVersion;
  String? privacyVersion;
  String? resetToken;
  String? newPassword;

  void _throwIfNeeded() {
    final error = failure;
    if (error != null) throw error;
  }

  @override
  Future<void> confirmPasswordReset({
    required String token,
    required String newPassword,
  }) async {
    _throwIfNeeded();
    resetToken = token;
    this.newPassword = newPassword;
  }

  @override
  Future<void> login({required String email, required String password}) async {
    _throwIfNeeded();
    loginCalls++;
  }

  @override
  Future<void> logout() async {}

  @override
  Future<Usuario> register({
    required String nombre,
    required String email,
    required String password,
    required bool aceptaTerminos,
    required bool aceptaPrivacidad,
    required String versionTerminos,
    required String versionPrivacidad,
  }) async {
    _throwIfNeeded();
    termsVersion = versionTerminos;
    privacyVersion = versionPrivacidad;
    return Usuario(
      id: 'user-1',
      nombre: nombre,
      email: email,
      fechaRegistro: DateTime.utc(2026, 7, 26),
    );
  }

  @override
  Future<void> requestPasswordReset({required String email}) async {
    _throwIfNeeded();
  }
}

class _MemoryTokenStorage implements TokenStorage {
  @override
  Future<void> clear() async {}

  @override
  Future<String?> readAccessToken() async => null;

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {}
}
