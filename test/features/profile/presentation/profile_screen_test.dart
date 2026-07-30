import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitbuilder_mobile/app.dart';
import 'package:habitbuilder_mobile/core/storage/token_storage.dart';
import 'package:habitbuilder_mobile/core/theme/app_theme.dart';
import 'package:habitbuilder_mobile/features/auth/domain/entities/usuario.dart';
import 'package:habitbuilder_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:habitbuilder_mobile/features/auth/presentation/providers/auth_providers.dart';
import 'package:habitbuilder_mobile/features/habits/domain/entities/habito.dart';
import 'package:habitbuilder_mobile/features/habits/presentation/providers/habit_providers.dart';
import 'package:habitbuilder_mobile/features/profile/domain/entities/perfil_usuario.dart';
import 'package:habitbuilder_mobile/features/profile/domain/repositories/profile_repository.dart';
import 'package:habitbuilder_mobile/features/profile/presentation/providers/profile_providers.dart';
import 'package:habitbuilder_mobile/features/profile/presentation/screens/profile_screen.dart';

void main() {
  testWidgets('loads, edits and saves all profile preferences', (tester) async {
    final repository = _FakeProfileRepository();
    await _pumpProfile(tester, repository);

    expect(find.text('Camila Acevedo'), findsWidgets);
    expect(find.text('Dormir mejor'), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Camila A.');
    await tester.enterText(fields.at(1), 'Dormir ocho horas');

    final timezone = find.byType(DropdownButtonFormField<String>);
    await tester.ensureVisible(timezone);
    await tester.tap(timezone);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Europe/Madrid').last);
    await tester.pump();

    await _tapVisible(tester, 'Lectura de texto');
    await _tapVisible(tester, 'Extra grande');
    await _tapVisible(tester, 'Alto contraste');
    await _tapVisible(tester, 'Permitir notificaciones');

    final saveButton = find.text('Guardar cambios');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(repository.updateCalls, 1);
    expect(repository.profile.nombreCompleto, 'Camila A.');
    expect(repository.profile.objetivoGeneral, 'Dormir ocho horas');
    expect(repository.profile.zonaHoraria, 'Europe/Madrid');
    expect(repository.profile.accessibility.textToSpeech, isTrue);
    expect(repository.profile.accessibility.textSize, TextSizePreference.large);
    expect(repository.profile.accessibility.highContrast, isTrue);
    expect(repository.profile.notifications.enabled, isFalse);
    expect(repository.profile.notifications.habitReminders, isFalse);
    expect(repository.profile.notifications.weeklySummary, isFalse);
  });

  testWidgets('validates required profile fields', (tester) async {
    final repository = _FakeProfileRepository();
    await _pumpProfile(tester, repository);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '');
    await tester.enterText(fields.at(1), '');
    expect(
      tester.widget<TextFormField>(fields.at(0)).controller?.text,
      isEmpty,
    );
    expect(
      tester.widget<TextFormField>(fields.at(1)).controller?.text,
      isEmpty,
    );
    FocusManager.instance.primaryFocus?.unfocus();
    tester.testTextInput.hide();
    expect(tester.state<FormState>(find.byType(Form)).validate(), isFalse);
    await tester.pump();
    await tester.ensureVisible(fields.at(0));
    await tester.pumpAndSettle();

    expect(find.text('Ingresa tu nombre completo'), findsOneWidget);
    expect(repository.updateCalls, 0);
  });

  testWidgets('cancel keeps the session and confirm logs out', (tester) async {
    final profileRepository = _FakeProfileRepository();
    final authRepository = _FakeAuthRepository();
    final storage = _MemoryTokenStorage(accessToken: 'access');
    await _pumpFullApp(tester, profileRepository, authRepository, storage);

    final logoutButton = find.byTooltip('Cerrar sesión');
    await tester.tap(logoutButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(authRepository.logoutCalls, 0);
    expect(find.text('Perfil'), findsWidgets);

    await tester.tap(logoutButton);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(authRepository.logoutCalls, 1);
    expect(storage.cleared, isTrue);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });

  testWidgets('applies text size and high contrast globally', (tester) async {
    final profileRepository = _FakeProfileRepository(
      profile: _profile(
        accessibility: const AccessibilityPreferences(
          textToSpeech: true,
          textSize: TextSizePreference.large,
          highContrast: true,
        ),
      ),
    );
    await _pumpFullApp(
      tester,
      profileRepository,
      _FakeAuthRepository(),
      _MemoryTokenStorage(accessToken: 'access'),
    );

    final context = tester.element(find.text('Perfil').first);
    expect(MediaQuery.textScalerOf(context).scale(10), 11.5);
    expect(
      Theme.of(context).colorScheme,
      AppTheme.light(highContrast: true).colorScheme,
    );
  });
}

Future<void> _tapVisible(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
}

Future<void> _pumpProfile(
  WidgetTester tester,
  _FakeProfileRepository repository,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        profileRepositoryProvider.overrideWithValue(repository),
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        tokenStorageProvider.overrideWithValue(_MemoryTokenStorage()),
      ],
      child: const MaterialApp(home: ProfileScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpFullApp(
  WidgetTester tester,
  _FakeProfileRepository profileRepository,
  _FakeAuthRepository authRepository,
  _MemoryTokenStorage storage,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        profileRepositoryProvider.overrideWithValue(profileRepository),
        authRepositoryProvider.overrideWithValue(authRepository),
        tokenStorageProvider.overrideWithValue(storage),
        habitsListProvider.overrideWith((ref) async => const <Habito>[]),
      ],
      child: const HabitBuilderApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Perfil').first);
  await tester.pumpAndSettle();
}

class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository({PerfilUsuario? profile})
    : profile = profile ?? _profile();

  PerfilUsuario profile;
  int updateCalls = 0;

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

PerfilUsuario _profile({AccessibilityPreferences? accessibility}) {
  return PerfilUsuario(
    usuarioId: 'user-1',
    nombreCompleto: 'Camila Acevedo',
    objetivoGeneral: 'Dormir mejor',
    zonaHoraria: 'America/Bogota',
    accessibility: accessibility ?? const AccessibilityPreferences.defaults(),
    notifications: const NotificationPreferences.defaults(),
  );
}
