import '../domain/entities/community_content.dart';
import 'community_data_source.dart';

abstract interface class CommunityRepository {
  Future<List<CommunityPost>> listPosts();
  Future<CommunityPost> createPost(String content);
  Future<void> react(String postId, {required bool reacted});
  Future<List<CommunityComment>> listComments(String postId);
  Future<CommunityComment> createComment(String postId, String content);
  Future<void> report(String postId, String reason, String detail);
  Future<List<InspirationItem>> listInspiration(InspirationType type);
}

class CommunityRepositoryImpl implements CommunityRepository {
  const CommunityRepositoryImpl(this._remote);

  final CommunityDataSource _remote;

  @override
  Future<List<CommunityPost>> listPosts() async =>
      (await _remote.listPosts()).map(_postFromJson).toList();

  @override
  Future<CommunityPost> createPost(String content) async =>
      _postFromJson(await _remote.createPost(content));

  @override
  Future<void> react(String postId, {required bool reacted}) =>
      reacted ? _remote.unreact(postId) : _remote.react(postId);

  @override
  Future<List<CommunityComment>> listComments(String postId) async =>
      (await _remote.listComments(postId)).map(_commentFromJson).toList();

  @override
  Future<CommunityComment> createComment(String postId, String content) async =>
      _commentFromJson(await _remote.createComment(postId, content));

  @override
  Future<void> report(String postId, String reason, String detail) =>
      _remote.report(postId, reason, detail);

  @override
  Future<List<InspirationItem>> listInspiration(InspirationType type) async =>
      (await _remote.listInspiration(
        type: type == InspirationType.all ? null : type.apiValue,
      )).map(_inspirationFromJson).toList();
}

CommunityPost _postFromJson(Map<String, dynamic> json) => CommunityPost(
  id: json['id'] as String,
  authorName: json['autorNombre'] as String? ?? 'HabitBuilder',
  content: json['contenido'] as String? ?? '',
  createdAt: DateTime.parse(json['creadoEn'] as String),
  updatedAt: DateTime.parse(json['actualizadoEn'] as String),
  reactions: (json['reacciones'] as num?)?.toInt() ?? 0,
  comments: (json['comentarios'] as num?)?.toInt() ?? 0,
  reacted: json['reaccionada'] as bool? ?? false,
  habitId: json['habitoId'] as String?,
);

CommunityComment _commentFromJson(Map<String, dynamic> json) =>
    CommunityComment(
      id: json['id'] as String,
      postId: json['publicacionId'] as String,
      authorName: json['autorNombre'] as String? ?? 'HabitBuilder',
      content: json['contenido'] as String? ?? '',
      createdAt: DateTime.parse(json['creadoEn'] as String),
    );

InspirationItem _inspirationFromJson(Map<String, dynamic> json) {
  final rawType = json['tipo'] as String? ?? 'articulo';
  final type = InspirationType.values.firstWhere(
    (value) => value.apiValue == rawType,
    orElse: () => InspirationType.article,
  );
  return InspirationItem(
    id: json['id'] as String,
    type: type,
    title: json['titulo'] as String? ?? '',
    summary: json['resumen'] as String? ?? '',
    url: json['url'] as String? ?? '',
    author: json['autor'] as String? ?? '',
    featured: json['destacado'] as bool? ?? false,
    createdAt: DateTime.parse(json['creadoEn'] as String),
    updatedAt: DateTime.parse(json['actualizadoEn'] as String),
    imageUrl: json['imagenUrl'] as String?,
  );
}
