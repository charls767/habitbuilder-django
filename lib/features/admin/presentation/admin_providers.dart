import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/dio_client.dart';
import '../data/admin_data_source.dart';
import '../data/admin_repository.dart';
import '../domain/admin_entities.dart';

final adminDataSourceProvider = Provider<AdminDataSource>(
  (ref) => AdminDataSource(ref.watch(dioProvider)),
);

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => AdminRepositoryImpl(ref.watch(adminDataSourceProvider)),
);

final adminAccessProvider = FutureProvider.autoDispose<bool>((ref) async {
  try {
    await ref.watch(adminRepositoryProvider).usage();
    return true;
  } on ApiException catch (error) {
    if (error.statusCode == 401 || error.statusCode == 403) return false;
    rethrow;
  }
});

final adminUsageProvider = FutureProvider.autoDispose<AdminUsage>(
  (ref) => ref.watch(adminRepositoryProvider).usage(),
);

final adminUsersProvider = FutureProvider.autoDispose<List<AdminUser>>(
  (ref) => ref.watch(adminRepositoryProvider).users(),
);

final moderationQueueProvider =
    FutureProvider.autoDispose<List<ModerationReport>>(
      (ref) => ref.watch(adminRepositoryProvider).moderationQueue(),
    );

final adminInspirationProvider = FutureProvider.autoDispose
    .family<List<AdminInspiration>, String>(
      (ref, search) =>
          ref.watch(adminRepositoryProvider).inspiration(search: search),
    );
