import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/config/app_env.dart';
import '../../../../core/network/auth_session_controller.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/token_storage.dart';
import '../../data/datasources/auth_remote_data_source.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';

part 'auth_providers.g.dart';

@riverpod
AuthRemoteDataSource authRemoteDataSource(Ref ref) {
  return AuthRemoteDataSource(ref.watch(dioProvider));
}

@riverpod
AuthRepository authRepository(Ref ref) {
  return AuthRepositoryImpl(
    ref.watch(authRemoteDataSourceProvider),
    ref.watch(tokenStorageProvider),
  );
}

/// Drives the login/register screens: exposes loading/error state around
/// the corresponding `AuthRepository` calls and, on a successful login,
/// flips `AuthSessionController` so the router redirects into the app.
@riverpod
class AuthController extends _$AuthController {
  @override
  FutureOr<void> build() {}

  void clearError() {
    if (state.hasError) {
      state = const AsyncData(null);
    }
  }

  Future<bool> login({required String email, required String password}) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref
          .read(authRepositoryProvider)
          .login(email: email, password: password),
    );
    state = result;
    if (result.hasError) return false;
    ref.read(authSessionControllerProvider.notifier).markAuthenticated();
    return true;
  }

  Future<bool> register({
    required String nombre,
    required String email,
    required String password,
    required bool aceptaTerminos,
    required bool aceptaPrivacidad,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref
          .read(authRepositoryProvider)
          .register(
            nombre: nombre,
            email: email,
            password: password,
            aceptaTerminos: aceptaTerminos,
            aceptaPrivacidad: aceptaPrivacidad,
            versionTerminos: AppEnv.termsVersion,
            versionPrivacidad: AppEnv.privacyVersion,
          ),
    );
    state = result.hasError
        ? AsyncError(result.error!, result.stackTrace!)
        : const AsyncData(null);
    return !result.hasError;
  }

  Future<bool> requestPasswordReset({required String email}) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).requestPasswordReset(email: email),
    );
    state = result;
    return !result.hasError;
  }

  Future<bool> confirmPasswordReset({
    required String token,
    required String newPassword,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref
          .read(authRepositoryProvider)
          .confirmPasswordReset(token: token, newPassword: newPassword),
    );
    state = result;
    return !result.hasError;
  }
}
