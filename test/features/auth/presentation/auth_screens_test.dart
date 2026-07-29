import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:habitbuilder_mobile/app.dart';
import 'package:habitbuilder_mobile/core/network/api_exception.dart';
import 'package:habitbuilder_mobile/core/storage/token_storage.dart';
import 'package:habitbuilder_mobile/features/auth/domain/entities/usuario.dart';
import 'package:habitbuilder_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:habitbuilder_mobile/features/auth/presentation/providers/auth_providers.dart';
import 'package:habitbuilder_mobile/features/habits/domain/entities/habito.dart';
import 'package:habitbuilder_mobile/features/habits/presentation/providers/habit_providers.dart';
import 'package:habitbuilder_mobile/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:habitbuilder_mobile/features/profile/domain/entities/perfil_usuario.dart';
import 'package:habitbuilder_mobile/features/profile/presentation/providers/profile_providers.dart';

void main() {
  testWidgets('login validates fields and opens the authenticated area', (
    tester,
  ) async {
    final repository = _FakeAuthRepository();
    await _pumpApp(tester, repository);

    await _tapVisible(tester, 'Iniciar sesión');
    await tester.pump();
    expect(find.text('Ingresa un correo válido'), findsOneWidget);
    expect(find.text('Ingresa tu contraseña'), findsOneWidget);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'camila@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'Segura123');
    await _tapVisible(tester, 'Iniciar sesión');
    await tester.pumpAndSettle();

    expect(repository.loginCalls, 1);
    expect(find.text('Hábitos del día'), findsOneWidget);
  });

  testWidgets('login uses generic credentials and explicit suspension errors', (
    tester,
  ) async {
    final repository = _FakeAuthRepository()
      ..failure = const ApiException(
        statusCode: 401,
        code: 'USUARIO_NO_EXISTE',
        message: 'The user does not exist.',
      );
    await _pumpApp(tester, repository);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'unknown@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'Segura123');
    await _tapVisible(tester, 'Iniciar sesión');
    await tester.pump();
    expect(
      find.text('El correo o la contraseña no son válidos.'),
      findsOneWidget,
    );

    repository.failure = const ApiException(
      statusCode: 423,
      code: 'CUENTA_SUSPENDIDA',
      message: 'Suspended.',
    );
    await _tapVisible(tester, 'Iniciar sesión');
    await tester.pump();
    expect(find.textContaining('cuenta está suspendida'), findsOneWidget);
  });

  testWidgets('registration requires and submits versioned consent', (
    tester,
  ) async {
    final repository = _FakeAuthRepository();
    await _pumpApp(tester, repository);

    await _tapVisible(tester, 'Crear cuenta');
    await tester.pumpAndSettle();
    final createButton = find.widgetWithText(FilledButton, 'Crear cuenta');
    expect(tester.widget<FilledButton>(createButton).onPressed, isNull);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Camila');
    await tester.enterText(fields.at(1), 'camila@example.com');
    await tester.enterText(fields.at(2), 'Segura123');
    await tester.enterText(fields.at(3), 'Segura123');
    final termsLabel = find.text('Acepto los términos de uso');
    final privacyLabel = find.text('Acepto la política de privacidad');
    await tester.ensureVisible(termsLabel);
    await tester.tap(termsLabel);
    await tester.pump();
    await tester.ensureVisible(privacyLabel);
    await tester.tap(privacyLabel);
    await tester.pump();
    await tester.ensureVisible(createButton);
    await tester.tap(createButton);
    await tester.pumpAndSettle();

    expect(repository.registerCalls, 1);
    expect(repository.acceptedTerms, isTrue);
    expect(repository.acceptedPrivacy, isTrue);
    expect(repository.termsVersion, isNotEmpty);
    expect(repository.privacyVersion, isNotEmpty);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });

  testWidgets(
    'registration shows backend field errors without clearing input',
    (tester) async {
      final repository = _FakeAuthRepository()
        ..failure = const ApiException(
          statusCode: 422,
          code: 'VALIDACION_FALLIDA',
          message: 'Check the fields.',
          fieldErrors: {'email': 'El correo ya está registrado.'},
        );
      await _pumpApp(tester, repository);
      await _tapVisible(tester, 'Crear cuenta');
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Camila');
      await tester.enterText(fields.at(1), 'camila@example.com');
      await tester.enterText(fields.at(2), 'Segura123');
      await tester.enterText(fields.at(3), 'Segura123');
      final termsLabel = find.text('Acepto los términos de uso');
      final privacyLabel = find.text('Acepto la política de privacidad');
      await tester.ensureVisible(termsLabel);
      await tester.tap(termsLabel);
      await tester.pump();
      await tester.ensureVisible(privacyLabel);
      await tester.tap(privacyLabel);
      await tester.pump();
      final createButton = find.widgetWithText(FilledButton, 'Crear cuenta');
      await tester.ensureVisible(createButton);
      await tester.tap(createButton);
      await tester.pump();

      expect(find.text('El correo ya está registrado.'), findsOneWidget);
      expect(find.text('Check the fields.'), findsOneWidget);
      expect(find.text('Camila'), findsOneWidget);
    },
  );

  testWidgets('forgot password returns the non-enumerating success state', (
    tester,
  ) async {
    final repository = _FakeAuthRepository();
    await _pumpApp(tester, repository);
    await _tapVisible(tester, 'Olvidé mi contraseña');
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'camila@example.com');
    await tester.tap(find.text('Enviar enlace'));
    await tester.pumpAndSettle();

    expect(repository.forgotCalls, 1);
    expect(find.text('Revisa tu correo'), findsOneWidget);
    expect(
      find.textContaining('Si existe una cuenta asociada'),
      findsOneWidget,
    );
  });

  testWidgets('login and registration fit a 320px viewport', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpApp(tester, _FakeAuthRepository());
    expect(tester.takeException(), isNull);
    expect(find.text('Bienvenido de nuevo'), findsOneWidget);

    await _tapVisible(tester, 'Crear cuenta');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Crea tu cuenta'), findsOneWidget);
  });

  testWidgets('reset password uses the URL token and returns to login', (
    tester,
  ) async {
    final repository = _FakeAuthRepository();
    final router = GoRouter(
      initialLocation: '/reset?token=url-token',
      routes: [
        GoRoute(
          path: '/reset',
          builder: (context, state) => ResetPasswordScreen(
            initialToken: state.uri.queryParameters['token'],
          ),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) =>
              const Scaffold(body: Text('Login after reset')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(repository),
          tokenStorageProvider.overrideWithValue(_MemoryTokenStorage()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    expect(
      tester.widget<TextFormField>(fields.at(0)).controller?.text,
      'url-token',
    );
    await tester.enterText(fields.at(1), 'NuevaSegura123');
    await tester.enterText(fields.at(2), 'NuevaSegura123');
    await tester.tap(find.text('Actualizar contraseña'));
    await tester.pumpAndSettle();

    expect(repository.resetToken, 'url-token');
    expect(repository.newPassword, 'NuevaSegura123');
    expect(find.text('Login after reset'), findsOneWidget);
  });
}

Future<void> _tapVisible(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _pumpApp(
  WidgetTester tester,
  _FakeAuthRepository repository,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(repository),
        tokenStorageProvider.overrideWithValue(_MemoryTokenStorage()),
        myProfileProvider.overrideWith((ref) async => _profileFixture),
        habitsListProvider.overrideWith((ref) async => const <Habito>[]),
      ],
      child: const HabitBuilderApp(),
    ),
  );
  await tester.pumpAndSettle();
}

const _profileFixture = PerfilUsuario(
  usuarioId: 'user-1',
  nombreCompleto: 'Camila',
  zonaHoraria: 'America/Bogota',
  objetivoGeneral: 'Dormir mejor',
  accessibility: AccessibilityPreferences.defaults(),
  notifications: NotificationPreferences.defaults(),
);

class _FakeAuthRepository implements AuthRepository {
  Object? failure;
  int loginCalls = 0;
  int registerCalls = 0;
  int forgotCalls = 0;
  bool? acceptedTerms;
  bool? acceptedPrivacy;
  String? termsVersion;
  String? privacyVersion;
  String? resetToken;
  String? newPassword;

  void _throwIfNeeded() {
    final error = failure;
    if (error != null) throw error;
  }

  @override
  Future<void> confirmPasswordReset({
    required String token,
    required String newPassword,
  }) async {
    _throwIfNeeded();
    resetToken = token;
    this.newPassword = newPassword;
  }

  @override
  Future<void> login({required String email, required String password}) async {
    _throwIfNeeded();
    loginCalls++;
  }

  @override
  Future<void> logout() async {}

  @override
  Future<Usuario> register({
    required String nombre,
    required String email,
    required String password,
    required bool aceptaTerminos,
    required bool aceptaPrivacidad,
    required String versionTerminos,
    required String versionPrivacidad,
  }) async {
    _throwIfNeeded();
    registerCalls++;
    acceptedTerms = aceptaTerminos;
    acceptedPrivacy = aceptaPrivacidad;
    termsVersion = versionTerminos;
    privacyVersion = versionPrivacidad;
    return Usuario(
      id: 'user-1',
      nombre: nombre,
      email: email,
      fechaRegistro: DateTime.utc(2026, 7, 26),
    );
  }

  @override
  Future<void> requestPasswordReset({required String email}) async {
    _throwIfNeeded();
    forgotCalls++;
  }
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
