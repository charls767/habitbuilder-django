import '../../../../core/storage/token_storage.dart';
import '../../domain/entities/usuario.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remote, this._tokenStorage);

  final AuthRemoteDataSource _remote;
  final TokenStorage _tokenStorage;

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
    final dto = await _remote.register(
      nombre: nombre,
      email: email,
      password: password,
      aceptaTerminos: aceptaTerminos,
      aceptaPrivacidad: aceptaPrivacidad,
      versionTerminos: versionTerminos,
      versionPrivacidad: versionPrivacidad,
    );
    return dto.toEntity();
  }

  @override
  Future<void> login({required String email, required String password}) async {
    final tokens = await _remote.login(email: email, password: password);
    await _tokenStorage.saveTokens(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken ?? '',
    );
  }

  @override
  Future<void> requestPasswordReset({required String email}) {
    return _remote.requestPasswordReset(email: email);
  }

  @override
  Future<void> confirmPasswordReset({
    required String token,
    required String newPassword,
  }) {
    return _remote.confirmPasswordReset(token: token, newPassword: newPassword);
  }

  @override
  Future<void> logout() => _tokenStorage.clear();
}
