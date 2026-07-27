import 'package:flutter_test/flutter_test.dart';
import 'package:habitbuilder_mobile/features/profile/data/models/perfil_usuario_dto.dart';
import 'package:habitbuilder_mobile/features/profile/domain/entities/perfil_usuario.dart';

void main() {
  test('maps all Phase 1 profile preferences', () {
    final dto = PerfilUsuarioDto.fromJson({
      'usuarioId': 'usr_001',
      'nombreCompleto': 'Camila Acevedo',
      'objetivoGeneral': 'Dormir mejor',
      'zonaHoraria': 'America/Bogota',
      'accesibilidad': {
        'lectorTexto': true,
        'tamanoTexto': 'grande',
        'altoContraste': true,
      },
      'notificaciones': {
        'habilitadas': true,
        'recordatoriosHabitos': false,
        'resumenSemanal': true,
      },
    });

    final profile = dto.toEntity();

    expect(profile.objetivoGeneral, 'Dormir mejor');
    expect(profile.accessibility.textToSpeech, isTrue);
    expect(profile.accessibility.textSize, TextSizePreference.large);
    expect(profile.accessibility.highContrast, isTrue);
    expect(profile.notifications.habitReminders, isFalse);
  });

  test('uses safe preference defaults for an older backend payload', () {
    final profile = PerfilUsuarioDto.fromJson({
      'usuarioId': 'usr_001',
      'nombreCompleto': 'Camila Acevedo',
      'zonaHoraria': 'America/Bogota',
    }).toEntity();

    expect(profile.objetivoGeneral, isEmpty);
    expect(profile.accessibility.textSize, TextSizePreference.medium);
    expect(profile.notifications.enabled, isTrue);
  });
}
