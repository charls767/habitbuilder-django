import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:habitbuilder_mobile/features/community/data/community_data_source.dart';
import 'package:habitbuilder_mobile/features/community/data/community_repository.dart';
import 'package:habitbuilder_mobile/features/community/domain/entities/community_content.dart';

void main() {
  test('decodes raw UTF-8 inspiration bytes', () async {
    final dio =
        Dio(
            BaseOptions(
              responseDecoder: (bytes, _, _) =>
                  utf8.decode(bytes, allowMalformed: true),
            ),
          )
          ..httpClientAdapter = _CallbackAdapter((options) {
            final body = jsonEncode([
              {
                'id': 'content-utf8',
                'tipo': 'articulo',
                'titulo': 'Cómo crear un hábito',
                'resumen': 'Lectura de 5 minutos.',
                'url': 'internal-content-id',
                'autor': 'Dra. Ana Soto',
                'destacado': true,
                'creadoEn': '2026-07-30T10:00:00Z',
                'actualizadoEn': '2026-07-30T10:00:00Z',
              },
            ]);
            return ResponseBody(
              Stream.value(Uint8List.fromList(utf8.encode(body))),
              200,
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
              },
            );
          });

    final result = await CommunityDataSource(dio).listInspiration();

    expect(result.single['titulo'], 'Cómo crear un hábito');
  });

  test(
    'maps feed, inspiration and protected interactions to API paths',
    () async {
      final requests = <String>[];
      final dio = Dio()
        ..httpClientAdapter = _CallbackAdapter((options) {
          requests.add('${options.method} ${options.path}');
          if (options.path == '/v1/comunidad/publicaciones') {
            if (options.method == 'POST') {
              return _jsonResponse({
                'id': 'post-2',
                'autorNombre': 'Ana',
                'contenido': 'nuevo',
                'creadoEn': '2026-07-30T10:00:00Z',
                'actualizadoEn': '2026-07-30T10:00:00Z',
                'reacciones': 0,
                'comentarios': 0,
                'reaccionada': false,
              });
            }
            return _jsonResponse([
              {
                'id': 'post-1',
                'autorNombre': 'Ana',
                'contenido': 'avance',
                'creadoEn': '2026-07-30T10:00:00Z',
                'actualizadoEn': '2026-07-30T10:00:00Z',
                'reacciones': 1,
                'comentarios': 0,
                'reaccionada': false,
              },
            ]);
          }
          if (options.path == '/v1/inspiracion') {
            return _jsonResponse([
              {
                'id': 'content-1',
                'tipo': 'video',
                'titulo': 'Constancia',
                'resumen': 'Un paso cada dia',
                'url': 'https://example.com',
                'autor': 'HabitBuilder',
                'destacado': true,
                'creadoEn': '2026-07-30T10:00:00Z',
                'actualizadoEn': '2026-07-30T10:00:00Z',
              },
            ]);
          }
          if (options.path == '/v1/inspiracion/content-1') {
            return _jsonResponse({
              'id': 'content-1',
              'tipo': 'video',
              'titulo': 'Constancia',
              'resumen': 'Un paso cada dia',
              'url': 'https://example.com',
              'autor': 'HabitBuilder',
              'destacado': true,
              'creadoEn': '2026-07-30T10:00:00Z',
              'actualizadoEn': '2026-07-30T10:00:00Z',
            });
          }
          if (options.path.endsWith('/comentarios') &&
              options.method == 'GET') {
            return _jsonResponse([
              {
                'id': 'comment-1',
                'publicacionId': 'post-1',
                'autorNombre': 'Luis',
                'contenido': 'Buen avance',
                'creadoEn': '2026-07-30T11:00:00Z',
              },
            ]);
          }
          if (options.path.endsWith('/comentarios') &&
              options.method == 'POST') {
            return _jsonResponse({
              'id': 'comment-2',
              'publicacionId': 'post-1',
              'autorNombre': 'Ana',
              'contenido': 'Gracias',
              'creadoEn': '2026-07-30T11:00:00Z',
            });
          }
          return _jsonResponse(<String, dynamic>{});
        });

      final repository = CommunityRepositoryImpl(CommunityDataSource(dio));
      final posts = await repository.listPosts();
      final createdPost = await repository.createPost('nuevo');
      final inspiration = await repository.listInspiration(
        InspirationType.video,
      );
      final detail = await repository.getInspiration('content-1');
      await repository.react('post-1', reacted: false);
      await repository.react('post-1', reacted: true);
      final comments = await repository.listComments('post-1');
      final createdComment = await repository.createComment(
        'post-1',
        'Gracias',
      );
      await repository.report('post-1', 'spam', '');

      expect(posts.single.authorName, 'Ana');
      expect(createdPost.id, 'post-2');
      expect(inspiration.single.type, InspirationType.video);
      expect(detail.title, 'Constancia');
      expect(comments.single.content, 'Buen avance');
      expect(createdComment.id, 'comment-2');
      expect(requests, contains('GET /v1/comunidad/publicaciones'));
      expect(requests, contains('GET /v1/inspiracion'));
      expect(requests, contains('GET /v1/inspiracion/content-1'));
      expect(
        requests,
        contains('POST /v1/comunidad/publicaciones/post-1/reaccion'),
      );
      expect(
        requests,
        contains('DELETE /v1/comunidad/publicaciones/post-1/reaccion'),
      );
      expect(
        requests,
        contains('GET /v1/comunidad/publicaciones/post-1/comentarios'),
      );
      expect(
        requests,
        contains('POST /v1/comunidad/publicaciones/post-1/comentarios'),
      );
      expect(
        requests,
        contains('POST /v1/comunidad/publicaciones/post-1/reportes'),
      );
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

ResponseBody _jsonResponse(Object body) => ResponseBody.fromString(
  jsonEncode(body),
  200,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);
