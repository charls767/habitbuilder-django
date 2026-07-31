import '../domain/admin_entities.dart';
import 'admin_data_source.dart';

abstract interface class AdminRepository {
  Future<AdminUsage> usage({String? from, String? to});
  Future<List<AdminUser>> users({
    String? search,
    String? status,
    String? role,
    int offset = 0,
  });
  Future<void> changeUserStatus(String id, String status, String reason);
  Future<void> changeUserRole(String id, String role, String reason);
  Future<List<ModerationReport>> moderationQueue({
    String status = 'pendiente',
    int offset = 0,
  });
  Future<void> resolveModeration(String id, String resolution, String reason);
  Future<CommunityPostData> publication(String id);
  Future<List<AdminInspiration>> inspiration({
    String? type,
    String? search,
    bool? published,
    bool? featured,
    int offset = 0,
  });
  Future<AdminInspiration> createInspiration(Map<String, dynamic> data);
  Future<AdminInspiration> updateInspiration(
    String id,
    Map<String, dynamic> data,
  );
  Future<void> deleteInspiration(String id);
  Future<AdminAccessRequest> createAdminRequest(String reason);
  Future<AdminAccessRequest> myAdminRequest();
  Future<List<AdminAccessRequest>> adminRequests({
    String? status,
    int offset = 0,
  });
  Future<AdminAccessRequest> resolveAdminRequest(
    String id,
    String decision,
    String reason,
  );
}

class AdminRepositoryImpl implements AdminRepository {
  const AdminRepositoryImpl(this._remote);
  final AdminDataSource _remote;

  @override
  Future<AdminUsage> usage({String? from, String? to}) async =>
      AdminUsage.fromJson(await _remote.usage(from: from, to: to));

  @override
  Future<List<AdminUser>> users({
    String? search,
    String? status,
    String? role,
    int offset = 0,
  }) async => (await _remote.users(
    search: search,
    status: status,
    role: role,
    offset: offset,
  )).map(AdminUser.fromJson).toList();

  @override
  Future<void> changeUserStatus(String id, String status, String reason) =>
      _remote.changeUserStatus(id, status, reason);

  @override
  Future<void> changeUserRole(String id, String role, String reason) =>
      _remote.changeUserRole(id, role, reason);

  @override
  Future<List<ModerationReport>> moderationQueue({
    String status = 'pendiente',
    int offset = 0,
  }) async => (await _remote.moderationQueue(
    status: status,
    offset: offset,
  )).map(ModerationReport.fromJson).toList();

  @override
  Future<void> resolveModeration(String id, String resolution, String reason) =>
      _remote.resolveModeration(id, resolution, reason);

  @override
  Future<CommunityPostData> publication(String id) async =>
      CommunityPostData.fromJson(await _remote.getPublication(id));

  @override
  Future<List<AdminInspiration>> inspiration({
    String? type,
    String? search,
    bool? published,
    bool? featured,
    int offset = 0,
  }) async => (await _remote.inspiration(
    type: type,
    search: search,
    published: published,
    featured: featured,
    offset: offset,
  )).map(AdminInspiration.fromJson).toList();

  @override
  Future<AdminInspiration> createInspiration(Map<String, dynamic> data) async =>
      AdminInspiration.fromJson(await _remote.createInspiration(data));

  @override
  Future<AdminInspiration> updateInspiration(
    String id,
    Map<String, dynamic> data,
  ) async =>
      AdminInspiration.fromJson(await _remote.updateInspiration(id, data));

  @override
  Future<void> deleteInspiration(String id) => _remote.deleteInspiration(id);

  @override
  Future<AdminAccessRequest> createAdminRequest(String reason) async =>
      AdminAccessRequest.fromJson(await _remote.createAdminRequest(reason));

  @override
  Future<AdminAccessRequest> myAdminRequest() async =>
      AdminAccessRequest.fromJson(await _remote.myAdminRequest());

  @override
  Future<List<AdminAccessRequest>> adminRequests({
    String? status,
    int offset = 0,
  }) async => (await _remote.adminRequests(
    status: status,
    offset: offset,
  )).map(AdminAccessRequest.fromJson).toList();

  @override
  Future<AdminAccessRequest> resolveAdminRequest(
    String id,
    String decision,
    String reason,
  ) async => AdminAccessRequest.fromJson(
    await _remote.resolveAdminRequest(id, decision, reason),
  );
}

class CommunityPostData {
  const CommunityPostData({
    required this.author,
    required this.content,
    required this.createdAt,
    required this.status,
  });

  factory CommunityPostData.fromJson(Map<String, dynamic> json) =>
      CommunityPostData(
        author: json['autorNombre'] as String? ?? 'HabitBuilder',
        content: json['contenido'] as String? ?? '',
        createdAt:
            DateTime.tryParse(json['creadoEn'] as String? ?? '') ??
            DateTime.now(),
        status: json['estadoModeracion'] as String? ?? 'visible',
      );

  final String author;
  final String content;
  final DateTime createdAt;
  final String status;
}
