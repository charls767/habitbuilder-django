import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:habitbuilder_mobile/core/network/api_exception.dart';
import 'package:habitbuilder_mobile/features/admin/data/admin_repository.dart';
import 'package:habitbuilder_mobile/features/admin/domain/admin_entities.dart';
import 'package:habitbuilder_mobile/features/admin/presentation/admin_access_request_screen.dart';
import 'package:habitbuilder_mobile/features/admin/presentation/admin_providers.dart';
import 'package:habitbuilder_mobile/features/admin/presentation/admin_requests_screen.dart';

void main() {
  testWidgets('regular user can submit an administrator access request', (
    tester,
  ) async {
    final repository = _RequestRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [adminRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: AdminAccessRequestScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Solicita acceso administrativo'), findsOneWidget);
    await tester.enterText(
      find.byType(TextFormField),
      'Quiero apoyar la moderación de la comunidad.',
    );
    await tester.tap(find.text('Enviar solicitud'));
    await tester.pumpAndSettle();

    expect(repository.reason, contains('apoyar'));
    expect(find.text('Pendiente de revisión'), findsOneWidget);
  });

  testWidgets('administrator can approve a pending request', (tester) async {
    final repository = _RequestRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [adminRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: Scaffold(body: AdminRequestsScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ana'), findsOneWidget);
    await tester.tap(find.text('Aprobar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Validado por el equipo');
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(repository.decision, 'aprobar');
  });
}

final _request = AdminAccessRequest(
  id: 'request-1',
  userId: 'user-1',
  userName: 'Ana',
  userEmail: 'ana@example.com',
  reason: 'Apoyar la moderación',
  status: 'pendiente',
  createdAt: DateTime(2026, 7, 30),
);

class _RequestRepository implements AdminRepository {
  String? reason;
  String? decision;

  @override
  Future<AdminAccessRequest> createAdminRequest(String reason) async {
    this.reason = reason;
    return _request;
  }

  @override
  Future<AdminAccessRequest> myAdminRequest() async => throw const ApiException(
    statusCode: 404,
    code: 'not_found',
    message: 'No hay solicitud',
  );

  @override
  Future<AdminUsage> usage({String? from, String? to}) => _unimplemented();

  @override
  Future<List<AdminUser>> users({
    String? search,
    String? status,
    String? role,
    int offset = 0,
  }) => _unimplemented();

  @override
  Future<void> changeUserStatus(String id, String status, String reason) =>
      _unimplemented();

  @override
  Future<void> changeUserRole(String id, String role, String reason) =>
      _unimplemented();

  @override
  Future<List<ModerationReport>> moderationQueue({
    String status = 'pendiente',
    int offset = 0,
  }) => _unimplemented();

  @override
  Future<void> resolveModeration(String id, String resolution, String reason) =>
      _unimplemented();

  @override
  Future<CommunityPostData> publication(String id) => _unimplemented();

  @override
  Future<List<AdminInspiration>> inspiration({
    String? type,
    String? search,
    bool? published,
    bool? featured,
    int offset = 0,
  }) => _unimplemented();

  @override
  Future<AdminInspiration> createInspiration(Map<String, dynamic> data) =>
      _unimplemented();

  @override
  Future<AdminInspiration> updateInspiration(
    String id,
    Map<String, dynamic> data,
  ) => _unimplemented();

  @override
  Future<void> deleteInspiration(String id) => _unimplemented();

  @override
  Future<List<AdminAccessRequest>> adminRequests({
    String? status,
    int offset = 0,
  }) async => [_request];

  @override
  Future<AdminAccessRequest> resolveAdminRequest(
    String id,
    String decision,
    String reason,
  ) async {
    this.decision = decision;
    return _request;
  }
}

Future<T> _unimplemented<T>() => Future<T>.error(UnimplementedError());
