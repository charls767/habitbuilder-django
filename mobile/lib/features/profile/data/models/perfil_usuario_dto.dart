import '../../domain/entities/perfil_usuario.dart';

/// Wire shape for the backend `PerfilResponse` schema.
class PerfilUsuarioDto {
  const PerfilUsuarioDto({
    required this.usuarioId,
    required this.nombreCompleto,
    required this.zonaHoraria,
    required this.objetivoGeneral,
    required this.accessibility,
    required this.notifications,
    this.fotoUrl,
    this.biografia,
  });

  factory PerfilUsuarioDto.fromJson(Map<String, dynamic> json) {
    final accessibilityJson =
        json['accesibilidad'] as Map<String, dynamic>? ?? const {};
    final notificationsJson =
        json['notificaciones'] as Map<String, dynamic>? ?? const {};

    return PerfilUsuarioDto(
      usuarioId: json['usuarioId'] as String? ?? '',
      nombreCompleto: json['nombre'] as String,
      zonaHoraria: json['zonaHoraria'] as String,
      objetivoGeneral: json['objetivoGeneral'] as String? ?? '',
      fotoUrl: json['fotoUrl'] as String?,
      biografia: json['biografia'] as String?,
      accessibility: AccessibilityPreferences(
        textToSpeech: accessibilityJson['ttsHabilitado'] as bool? ?? false,
        textSize: TextSizePreference.fromApiValue(
          accessibilityJson['tamanoTexto'] as String?,
        ),
        highContrast: accessibilityJson['contrasteAlto'] as bool? ?? false,
      ),
      notifications: NotificationPreferences(
        enabled: true,
        habitReminders:
            notificationsJson['recordatoriosHabilitados'] as bool? ?? true,
        weeklySummary:
            notificationsJson['resumenProgresoHabilitado'] as bool? ?? true,
      ),
    );
  }

  final String usuarioId;
  final String nombreCompleto;
  final String zonaHoraria;
  final String objetivoGeneral;
  final AccessibilityPreferences accessibility;
  final NotificationPreferences notifications;
  final String? fotoUrl;
  final String? biografia;

  PerfilUsuario toEntity() => PerfilUsuario(
    usuarioId: usuarioId,
    nombreCompleto: nombreCompleto,
    zonaHoraria: zonaHoraria,
    objetivoGeneral: objetivoGeneral,
    accessibility: accessibility,
    notifications: notifications,
    fotoUrl: fotoUrl,
    biografia: biografia,
  );
}
