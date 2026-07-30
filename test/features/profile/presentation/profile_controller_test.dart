import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitbuilder_mobile/core/network/auth_session_controller.dart';
import 'package:habitbuilder_mobile/core/storage/token_storage.dart';
import 'package:habitbuilder_mobile/features/auth/domain/entities/usuario.dart';
import 'package:habitbuilder_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:habitbuilder_mobile/features/auth/presentation/providers/auth_providers.dart';
import 'package:habitbuilder_mobile/features/profile/domain/entities/perfil_usuario.dart';
import 'package:habitbuilder_mobile/features/profile/domain/repositories/profile_repository.dart';
import 'package:habitbuilder_mobile/features/profile/presentation/providers/profile_providers.dart';
import 'package:habitbuilder_mobile/features/reminders/application/reminder_reconciliation_coordinator.dart';
import 'package:habitbuilder_mobile/features/reminders/presentation/providers/reminder_providers.dart';

void main() {
  test('updates profile preferences and refreshes my profile', () async {
    final repository = _FakeProfileRepository();
    final container = _container(repository);
    addTearDown(container.dispose);
    expect(
      (await container.read(myProfileProvider.future)).objetivoGeneral,
      'Dormir mejor',
    );

    await container
        .read(profileControllerProvider.notifier)
        .updateProfile(
          nombreCompleto: 'Camila Acevedo',
          objetivoGeneral: 'Dormir ocho horas',
          zonaHoraria: 'Europe/Madrid',
          accessibility: const AccessibilityPreferences(
            textToSpeech: true,
            textSize: TextSizePreference.large,
            highContrast: true,
          ),
          notifications: const NotificationPreferences(
            enabled: false,
            habitReminders: false,
            weeklySummary: false,
          ),
        );

    expect(repository.updateCalls, 1);
    expect(repository.profile.objetivoGeneral, 'Dormir ocho horas');
    expect(repository.profile.zonaHoraria, 'Europe/Madrid');
    expect(repository.profile.accessibility.highContrast, isTrue);
    expect(repository.profile.notifications.enabled, isFalse);
    expect(container.read(profileControllerProvider).hasError, isFalse);
  });

  test('logout clears repository and shared session state', () async {
    final profileRepository = _FakeProfileRepository();
    final authRepository = _FakeAuthRepository();
    final storage = _MemoryTokenStorage(accessToken: 'access');
    final container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWithValue(profileRepository),
        authRepositoryProvider.overrideWithValue(authRepository),
        tokenStorageProvider.overrideWithValue(storage),
      ],
    );
    addTearDown(container.dispose);
    expect(await container.read(authSessionControllerProvider.future), isTrue);

    await container.read(profileControllerProvider.notifier).logout();

    expect(authRepository.logoutCalls, 1);
    expect(storage.cleared, isTrue);
    expect(container.read(authSessionControllerProvider).value, isFalse);
  });

  test(
    'successful zone and notification update requests reconciliation',
    () async {
      final repository = _FakeProfileRepository();
      final requests = <bool>[];
      final container = ProviderContainer(
        overrides: [
          profileRepositoryProvider.overrideWithValue(repository),
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          tokenStorageProvider.overrideWithValue(_MemoryTokenStorage()),
          reminderReconciliationRequestProvider.overrideWithValue(({
            bool requestPermission = false,
          }) async {
            requests.add(requestPermission);
            return const ReminderDeliveryState.delivered();
          }),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(profileControllerProvider.notifier)
          .updateProfile(
            nombreCompleto: 'Camila Acevedo',
            objetivoGeneral: 'Dormir ocho horas',
            zonaHoraria: 'Europe/Madrid',
            accessibility: const AccessibilityPreferences.defaults(),
            notifications: const NotificationPreferences.defaults(),
          );

      expect(requests, [true]);

      repository.failure = StateError('backend');
      await container
          .read(profileControllerProvider.notifier)
          .updateProfile(
            nombreCompleto: 'Camila Acevedo',
            objetivoGeneral: 'No se guarda',
            zonaHoraria: 'Etc/UTC',
            accessibility: const AccessibilityPreferences.defaults(),
            notifications: const NotificationPreferences.defaults(),
          );
      expect(requests, [true]);
    },
  );
}

ProviderContainer _container(_FakeProfileRepository repository) {
  return ProviderContainer(
    overrides: [
      profileRepositoryProvider.overrideWithValue(repository),
      authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
      tokenStorageProvider.overrideWithValue(_MemoryTokenStorage()),
    ],
  );
}

class _FakeProfileRepository implements ProfileRepository {
  PerfilUsuario profile = _profile();
  int updateCalls = 0;
  Object? failure;

  @override
  Future<PerfilUsuario> getMyProfile() async => profile;

  @override
  Future<PerfilUsuario> updateMyProfile({
    required String nombreCompleto,
    required String objetivoGeneral,
    required String zonaHoraria,
    required AccessibilityPreferences accessibility,
    required NotificationPreferences notifications,
  }) async {
    final currentFailure = failure;
    if (currentFailure != null) throw currentFailure;
    updateCalls++;
    profile = PerfilUsuario(
      usuarioId: profile.usuarioId,
      nombreCompleto: nombreCompleto,
      objetivoGeneral: objetivoGeneral,
      zonaHoraria: zonaHoraria,
      accessibility: accessibility,
      notifications: notifications,
    );
    return profile;
  }
}

class _FakeAuthRepository implements AuthRepository {
  int logoutCalls = 0;

  @override
  Future<void> confirmPasswordReset({
    required String token,
    required String newPassword,
  }) async {}

  @override
  Future<void> login({required String email, required String password}) async {}

  @override
  Future<void> logout() async {
    logoutCalls++;
  }

  @override
  Future<Usuario> register({
    required String nombre,
    required String email,
    required String password,
    required bool aceptaTerminos,
    required bool aceptaPrivacidad,
    required String versionTerminos,
    required String versionPrivacidad,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> requestPasswordReset({required String email}) async {}
}

class _MemoryTokenStorage implements TokenStorage {
  _MemoryTokenStorage({this.accessToken});

  String? accessToken;
  bool cleared = false;

  @override
  Future<void> clear() async {
    accessToken = null;
    cleared = true;
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
