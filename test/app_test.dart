import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:habitbuilder_mobile/app.dart';
import 'package:habitbuilder_mobile/core/network/auth_session_controller.dart';
import 'package:habitbuilder_mobile/core/router/app_router.dart';
import 'package:habitbuilder_mobile/core/router/app_routes.dart';
import 'package:habitbuilder_mobile/core/storage/token_storage.dart';
import 'package:habitbuilder_mobile/features/habits/domain/entities/frecuencia.dart';
import 'package:habitbuilder_mobile/features/habits/domain/entities/habito.dart';
import 'package:habitbuilder_mobile/features/habits/presentation/providers/habit_providers.dart';
import 'package:habitbuilder_mobile/features/habits/presentation/screens/habits_list_screen.dart';
import 'package:habitbuilder_mobile/features/profile/domain/entities/perfil_usuario.dart';
import 'package:habitbuilder_mobile/features/profile/presentation/providers/profile_providers.dart';
import 'package:habitbuilder_mobile/features/reminders/application/reminder_reconciliation_coordinator.dart';
import 'package:habitbuilder_mobile/features/reminders/presentation/providers/reminder_providers.dart';
import 'package:habitbuilder_mobile/features/reminders/presentation/widgets/reminder_reconciliation_bootstrap.dart';

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

  testWidgets('habit reminder action opens its scoped route', (tester) async {
    final router = GoRouter(
      initialLocation: AppRoutes.habits,
      routes: [
        GoRoute(
          path: AppRoutes.habits,
          builder: (context, state) => const HabitsListScreen(),
        ),
        GoRoute(
          path: '/habits/:habitId/reminders',
          builder: (context, state) => Scaffold(
            body: Text('Recordatorios ${state.pathParameters['habitId']}'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          habitsListProvider.overrideWith((ref) async => [_habit()]),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Recordatorios para Leer'));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, AppRoutes.habitReminders('hab-1'));
    expect(find.text('Recordatorios hab-1'), findsOneWidget);
  });

  testWidgets(
    'authenticated startup, login and resume request reconciliation',
    (tester) async {
      final requests = <bool>[];
      final container = ProviderContainer(
        overrides: [
          tokenStorageProvider.overrideWithValue(
            _MemoryTokenStorage(accessToken: 'access'),
          ),
          habitsListProvider.overrideWith((ref) async => const []),
          myProfileProvider.overrideWith((ref) async => _profile()),
          reminderReconciliationRequestProvider.overrideWithValue(({
            bool requestPermission = false,
          }) async {
            requests.add(requestPermission);
            return const ReminderDeliveryState.delivered();
          }),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const HabitBuilderApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ReminderReconciliationBootstrap), findsOneWidget);
      expect(
        container.read(reminderReconciliationActivationProvider).enabled,
        isTrue,
      );
      expect(requests, [false]);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(requests, [false, false]);

      await container
          .read(authSessionControllerProvider.notifier)
          .markUnauthenticated();
      container
          .read(authSessionControllerProvider.notifier)
          .markAuthenticated();
      await tester.pump();
      expect(requests, [false, false, false]);
    },
  );
}

Habito _habit() {
  return Habito(
    id: 'hab-1',
    usuarioId: 'user-1',
    nombre: 'Leer',
    fechaInicio: DateTime(2026, 7, 29),
    frecuencia: Frecuencia.diaria(),
    estado: HabitoEstado.activo,
    pausas: const [],
    fechaCreacion: DateTime.utc(2026, 7, 29),
    fechaActualizacion: DateTime.utc(2026, 7, 29),
  );
}

class _MemoryTokenStorage implements TokenStorage {
  _MemoryTokenStorage({this.accessToken});

  String? accessToken;

  @override
  Future<void> clear() async {
    accessToken = null;
  }

  @override
  Future<String?> readAccessToken() async => accessToken;

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    this.accessToken = accessToken;
  }
}

PerfilUsuario _profile() {
  return const PerfilUsuario(
    usuarioId: 'user-1',
    nombreCompleto: 'Camila Acevedo',
    objetivoGeneral: 'Dormir mejor',
    zonaHoraria: 'America/Bogota',
    accessibility: AccessibilityPreferences.defaults(),
    notifications: NotificationPreferences.defaults(),
  );
}
