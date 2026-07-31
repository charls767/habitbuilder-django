import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../data/community_data_source.dart';
import '../data/community_repository.dart';
import '../domain/entities/community_content.dart';

final communityDataSourceProvider = Provider<CommunityDataSource>(
  (ref) => CommunityDataSource(ref.watch(dioProvider)),
);

final communityRepositoryProvider = Provider<CommunityRepository>(
  (ref) => CommunityRepositoryImpl(ref.watch(communityDataSourceProvider)),
);

final communityFeedProvider = FutureProvider.autoDispose<List<CommunityPost>>(
  (ref) => ref.watch(communityRepositoryProvider).listPosts(),
);

final communityCommentsProvider = FutureProvider.autoDispose
    .family<List<CommunityComment>, String>(
      (ref, postId) => ref.watch(communityRepositoryProvider).listComments(postId),
    );

final inspirationProvider = FutureProvider.autoDispose
    .family<List<InspirationItem>, InspirationType>(
      (ref, type) => ref.watch(communityRepositoryProvider).listInspiration(type),
    );
