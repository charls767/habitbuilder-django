import '../entities/perfil_usuario.dart';

abstract interface class ProfileRepository {
  Future<PerfilUsuario> getMyProfile();

  Future<PerfilUsuario> updateMyProfile({
    required String nombreCompleto,
    required String objetivoGeneral,
    required String zonaHoraria,
    required AccessibilityPreferences accessibility,
    required NotificationPreferences notifications,
  });
}
