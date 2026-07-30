import '../../domain/entities/perfil_usuario.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_data_source.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(this._remote);

  final ProfileRemoteDataSource _remote;

  @override
  Future<PerfilUsuario> getMyProfile() async {
    final dto = await _remote.getMyProfile();
    return dto.toEntity();
  }

  @override
  Future<PerfilUsuario> updateMyProfile({
    required String nombreCompleto,
    required String objetivoGeneral,
    required String zonaHoraria,
    required AccessibilityPreferences accessibility,
    required NotificationPreferences notifications,
  }) async {
    final dto = await _remote.updateMyProfile({
      'objetivoGeneral': objetivoGeneral,
      'zonaHoraria': zonaHoraria,
      'accesibilidad': {
        'ttsHabilitado': accessibility.textToSpeech,
        'tamanoTexto': accessibility.textSize.apiValue,
        'contrasteAlto': accessibility.highContrast,
      },
      'notificaciones': {
        'recordatoriosHabilitados': notifications.habitReminders,
        'resumenProgresoHabilitado': notifications.weeklySummary,
      },
    });
    return dto.toEntity();
  }
}
