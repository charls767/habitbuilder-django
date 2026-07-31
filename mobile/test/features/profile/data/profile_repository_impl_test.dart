import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitbuilder_mobile/features/profile/data/datasources/profile_remote_data_source.dart';
import 'package:habitbuilder_mobile/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:habitbuilder_mobile/features/profile/domain/entities/perfil_usuario.dart';

void main() {
  test('loads and patches all profile preferences', () async {
    final requests = <RequestOptions>[];
    final dio = Dio()
      ..httpClientAdapter = _CallbackAdapter((options) {
        requests.add(options);
        return _jsonResponse(200, jsonEncode(_profileJson()));
      });
    final repository = ProfileRepositoryImpl(ProfileRemoteDataSource(dio));

    final profile = await repository.getMyProfile();
    final updated = await repository.updateMyProfile(
      nombreCompleto: 'Camila Acevedo',
      objetivoGeneral: 'Dormir ocho horas',
      zonaHoraria: 'Europe/Madrid',
      accessibility: const AccessibilityPreferences(
        textToSpeech: true,
        textSize: TextSizePreference.large,
        highContrast: true,
      ),
      notifications: const NotificationPreferences(
        enabled: true,
        habitReminders: false,
        weeklySummary: true,
      ),
    );

    expect(profile.usuarioId, isEmpty);
    expect(updated.accessibility.textSize, TextSizePreference.large);
    expect(requests.map((request) => request.method), ['GET', 'PATCH']);
    expect(requests.last.path, '/v1/usuarios/me');
    final patch = requests.last.data! as Map<String, dynamic>;
    expect(patch['zonaHoraria'], 'Europe/Madrid');
    expect(patch['accesibilidad'], {
      'ttsHabilitado': true,
      'tamanoTexto': 'extra_grande',
      'contrasteAlto': true,
    });
    expect(patch['notificaciones'], {
      'recordatoriosHabilitados': false,
      'resumenProgresoHabilitado': true,
    });
  });
}

Map<String, dynamic> _profileJson() {
  return {
    'nombre': 'Camila Acevedo',
    'objetivoGeneral': 'Dormir mejor',
    'zonaHoraria': 'America/Bogota',
    'fotoUrl': null,
    'biografia': 'Building better habits.',
    'accesibilidad': {
      'ttsHabilitado': true,
      'tamanoTexto': 'extra_grande',
      'contrasteAlto': true,
    },
    'notificaciones': {
      'recordatoriosHabilitados': false,
      'resumenProgresoHabilitado': true,
    },
  };
}

ResponseBody _jsonResponse(int status, String body) {
  return ResponseBody.fromString(
    body,
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

class _CallbackAdapter implements HttpClientAdapter {
  _CallbackAdapter(this.callback);

  final ResponseBody Function(RequestOptions options) callback;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return callback(options);
  }

  @override
  void close({bool force = false}) {}
}
