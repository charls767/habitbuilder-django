import '../domain/admin_entities.dart';
import 'admin_data_source.dart';

abstract interface class AdminRepository {
  Future<AdminUsage> usage({String? from, String? to});
  Future<List<AdminUser>> users();
  Future<void> changeUserStatus(String id, String status, String reason);
  Future<void> changeUserRole(String id, String role, String reason);
  Future<List<ModerationReport>> moderationQueue();
  Future<void> resolveModeration(String id, String resolution, String reason);
}

class AdminRepositoryImpl implements AdminRepository {
  const AdminRepositoryImpl(this._remote);
  final AdminDataSource _remote;

  @override
  Future<AdminUsage> usage({String? from, String? to}) async =>
      AdminUsage.fromJson(await _remote.usage(from: from, to: to));

  @override
  Future<List<AdminUser>> users() async =>
      (await _remote.users()).map(AdminUser.fromJson).toList();

  @override
  Future<void> changeUserStatus(String id, String status, String reason) =>
      _remote.changeUserStatus(id, status, reason);

  @override
  Future<void> changeUserRole(String id, String role, String reason) =>
      _remote.changeUserRole(id, role, reason);

  @override
  Future<List<ModerationReport>> moderationQueue() async =>
      (await _remote.moderationQueue()).map(ModerationReport.fromJson).toList();

  @override
  Future<void> resolveModeration(String id, String resolution, String reason) =>
      _remote.resolveModeration(id, resolution, reason);
}
