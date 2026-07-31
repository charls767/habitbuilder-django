import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:habitbuilder_mobile/features/admin/data/admin_data_source.dart';
import 'package:habitbuilder_mobile/features/admin/data/admin_repository.dart';

void main() {
  test('maps admin reports, users and moderation contracts', () async {
    final requests = <String>[];
    final dio = Dio()
      ..httpClientAdapter = _CallbackAdapter((options) {
        requests.add('${options.method} ${options.path}');
        if (options.path == '/v1/admin/reportes/uso') {
          return _jsonResponse({
            'periodoDesde': '2026-07-01T00:00:00Z',
            'periodoHasta': '2026-07-30T00:00:00Z',
            'usuariosRegistrados': 4,
            'usuariosActivos': 3,
            'habitosCreados': 8,
            'registrosCreados': 20,
            'publicaciones': 2,
          });
        }
        if (options.path == '/v1/admin/usuarios') {
          return _jsonResponse([
            {'id': 'user-1', 'nombre': 'Ana', 'email': 'ana@example.com', 'rol': 'admin', 'estado': 'activo'},
          ]);
        }
        if (options.path == '/v1/admin/moderacion/reportes') {
          return _jsonResponse([
            {'id': 'report-1', 'publicacionId': 'post-1', 'motivo': 'spam', 'detalle': '', 'estado': 'pendiente', 'creadoEn': '2026-07-30T10:00:00Z'},
          ]);
        }
        return ResponseBody.fromString('', 204);
      });

    final repository = AdminRepositoryImpl(AdminDataSource(dio));
    final usage = await repository.usage();
    final users = await repository.users();
    await repository.changeUserStatus('user-1', 'suspendido', 'inactividad');
    await repository.changeUserRole('user-1', 'regular', 'delegacion');
    final reports = await repository.moderationQueue();
    await repository.resolveModeration('report-1', 'descartar', 'revisado');

    expect(usage.activeUsers, 3);
    expect(users.single.role, 'admin');
    expect(reports.single.reason, 'spam');
    expect(requests, contains('GET /v1/admin/reportes/uso'));
    expect(requests, contains('GET /v1/admin/usuarios'));
    expect(requests, contains('PATCH /v1/admin/usuarios/user-1/estado'));
    expect(requests, contains('PATCH /v1/admin/usuarios/user-1/rol'));
    expect(requests, contains('GET /v1/admin/moderacion/reportes'));
    expect(requests, contains('PATCH /v1/admin/moderacion/reportes/report-1'));
  });
}

class _CallbackAdapter implements HttpClientAdapter {
  _CallbackAdapter(this.callback);
  final ResponseBody Function(RequestOptions options) callback;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => callback(options);

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonResponse(Object body) => ResponseBody.fromString(
  jsonEncode(body),
  200,
  headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
);
