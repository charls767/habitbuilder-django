import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:habitbuilder_mobile/features/admin/data/admin_repository.dart';
import 'package:habitbuilder_mobile/features/admin/domain/admin_entities.dart';
import 'package:habitbuilder_mobile/features/admin/presentation/admin_providers.dart';
import 'package:habitbuilder_mobile/features/admin/presentation/admin_screen.dart';

void main() {
  testWidgets('renders usage, user actions and moderation actions', (
    tester,
  ) async {
    final repository = _FakeAdminRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminRepositoryProvider.overrideWithValue(repository),
          adminAccessProvider.overrideWith((ref) async => true),
          adminUsageProvider.overrideWith((ref) async => _usage),
          adminUsersProvider.overrideWith((ref) async => [_user]),
          moderationQueueProvider.overrideWith((ref) async => [_report]),
        ],
        child: const MaterialApp(home: AdminScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Usuarios activos'), findsOneWidget);
    await tester.tap(find.text('Usuarios'));
    await tester.pumpAndSettle();
    expect(find.text('Ana'), findsOneWidget);
    await tester.tap(find.byTooltip('Suspender usuario'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'incumplimiento');
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    expect(repository.statusChanges, 1);

    await tester.tap(find.byIcon(Icons.flag_outlined));
    await tester.pumpAndSettle();
    expect(find.textContaining('post-1'), findsOneWidget);
    await tester.tap(find.byTooltip('Resolver reporte'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ocultar publicaci\u00F3n'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'revisado');
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    expect(repository.resolutions, 1);
  });
}

final _usage = AdminUsage(
  registeredUsers: 4,
  activeUsers: 3,
  habits: 8,
  records: 20,
  publications: 2,
  from: _dateFrom,
  to: _dateTo,
);

final _dateFrom = DateTime(2026, 7, 1);
final _dateTo = DateTime(2026, 7, 30);

const _user = AdminUser(
  id: 'user-1',
  name: 'Ana',
  email: 'ana@example.com',
  role: 'admin',
  status: 'activo',
);

final _report = ModerationReport(
  id: 'report-1',
  publicationId: 'post-1',
  reason: 'spam',
  detail: '',
  status: 'pendiente',
  createdAt: _dateTo,
);

class _FakeAdminRepository implements AdminRepository {
  int statusChanges = 0;
  int resolutions = 0;

  @override
  Future<AdminUsage> usage({String? from, String? to}) async => _usage;

  @override
  Future<List<AdminUser>> users({
    String? search,
    String? status,
    String? role,
    int offset = 0,
  }) async => [_user];

  @override
  Future<void> changeUserStatus(String id, String status, String reason) async {
    statusChanges++;
  }

  @override
  Future<void> changeUserRole(String id, String role, String reason) async {}

  @override
  Future<List<ModerationReport>> moderationQueue({
    String status = 'pendiente',
    int offset = 0,
  }) async => [_report];

  @override
  Future<void> resolveModeration(
    String id,
    String resolution,
    String reason,
  ) async {
    resolutions++;
  }

  @override
  Future<CommunityPostData> publication(String id) async => CommunityPostData(
    author: 'Ana',
    content: 'Contenido de prueba',
    createdAt: _dateTo,
    status: 'visible',
  );

  @override
  Future<List<AdminInspiration>> inspiration({
    String? type,
    String? search,
    bool? published,
    bool? featured,
    int offset = 0,
  }) async => [];

  @override
  Future<AdminInspiration> createInspiration(Map<String, dynamic> data) async =>
      throw UnimplementedError();

  @override
  Future<AdminInspiration> updateInspiration(
    String id,
    Map<String, dynamic> data,
  ) async => throw UnimplementedError();

  @override
  Future<void> deleteInspiration(String id) async {}
}
