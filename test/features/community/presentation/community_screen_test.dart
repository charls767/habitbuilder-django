import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:habitbuilder_mobile/features/community/data/community_repository.dart';
import 'package:habitbuilder_mobile/features/community/domain/entities/community_content.dart';
import 'package:habitbuilder_mobile/features/community/presentation/community_providers.dart';
import 'package:habitbuilder_mobile/features/community/presentation/community_screen.dart';

void main() {
  testWidgets('renders forum and inspiration flows', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repository = _FakeCommunityRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          communityRepositoryProvider.overrideWithValue(repository),
          communityFeedProvider.overrideWith((ref) async => [_post]),
          inspirationProvider(
            InspirationType.all,
          ).overrideWith((ref) async => [_inspiration]),
        ],
        child: const MaterialApp(home: CommunityScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Comunidad'), findsNWidgets(2));
    expect(find.text('Foro'), findsOneWidget);
    expect(find.textContaining('Insp'), findsOneWidget);
    expect(find.text('avance'), findsOneWidget);
    await tester.tap(find.byTooltip('Ver comentarios'));
    await tester.pumpAndSettle();
    expect(find.text('Comentarios'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Buen trabajo');
    await tester.tap(find.byTooltip('Enviar comentario'));
    await tester.pumpAndSettle();
    expect(repository.createdComment, 'Buen trabajo');
    Navigator.of(tester.element(find.text('Comentarios'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Inspírate'));
    await tester.pumpAndSettle();
    expect(find.text('Constancia'), findsOneWidget);
    await tester.tap(find.text('Constancia'));
    await tester.pumpAndSettle();
    expect(find.textContaining('https://example.com'), findsOneWidget);
  });
}

final _post = CommunityPost(
  id: 'post-1',
  authorName: 'Ana',
  content: 'avance',
  createdAt: DateTime.utc(2026, 7, 30),
  updatedAt: DateTime.utc(2026, 7, 30),
  reactions: 1,
  comments: 1,
  reacted: false,
);

final _inspiration = InspirationItem(
  id: 'content-1',
  type: InspirationType.article,
  title: 'Constancia',
  summary: 'Un paso cada dia',
  url: 'https://example.com',
  author: 'HabitBuilder',
  featured: true,
  createdAt: DateTime.utc(2026, 7, 30),
  updatedAt: DateTime.utc(2026, 7, 30),
);

class _FakeCommunityRepository implements CommunityRepository {
  String? createdComment;

  @override
  Future<List<CommunityPost>> listPosts() async => [_post];

  @override
  Future<CommunityPost> createPost(String content) async => _post;

  @override
  Future<void> react(String postId, {required bool reacted}) async {}

  @override
  Future<List<CommunityComment>> listComments(String postId) async => const [];

  @override
  Future<CommunityComment> createComment(String postId, String content) async {
    createdComment = content;
    return CommunityComment(
      id: 'comment-1',
      postId: postId,
      authorName: 'Ana',
      content: content,
      createdAt: DateTime.utc(2026, 7, 30),
    );
  }

  @override
  Future<void> report(String postId, String reason, String detail) async {}

  @override
  Future<List<InspirationItem>> listInspiration(InspirationType type) async => [
    _inspiration,
  ];
}
