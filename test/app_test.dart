import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitbuilder_mobile/app.dart';
import 'package:habitbuilder_mobile/core/network/auth_session_controller.dart';
import 'package:habitbuilder_mobile/core/router/app_router.dart';
import 'package:habitbuilder_mobile/core/router/app_routes.dart';
import 'package:habitbuilder_mobile/core/storage/token_storage.dart';

void main() {
  testWidgets('app boots and shows the scaffold placeholder', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: HabitBuilderApp()));

    expect(find.textContaining('HabitBuilder'), findsWidgets);
  });

  test('builds the habit-scoped reminder route', () {
    expect(
      AppRoutes.habitReminders('habit with spaces'),
      '/habits/habit%20with%20spaces/reminders',
    );
  });

  testWidgets('redirects unauthenticated reminder navigation to login', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        tokenStorageProvider.overrideWithValue(_MemoryTokenStorage()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authSessionControllerProvider.future);
    final router = container.read(appRouterProvider);
    addTearDown(router.dispose);

    router.go(AppRoutes.habitReminders('hab-1'));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(router.state.uri.path, AppRoutes.login);
    expect(find.text('Bienvenido de nuevo'), findsOneWidget);
  });
}

class _MemoryTokenStorage implements TokenStorage {
  @override
  Future<void> clear() async {}

  @override
  Future<String?> readAccessToken() async => null;

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {}
}
