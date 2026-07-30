import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitbuilder_mobile/core/network/auth_session_controller.dart';
import 'package:habitbuilder_mobile/core/storage/token_storage.dart';

void main() {
  test('starts authenticated when an access token exists', () async {
    final container = ProviderContainer(
      overrides: [
        tokenStorageProvider.overrideWithValue(
          _MemoryTokenStorage(accessToken: 'access'),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(authSessionControllerProvider.future), isTrue);
  });

  test('marks the session authenticated and unauthenticated', () async {
    final storage = _MemoryTokenStorage(accessToken: 'access');
    final container = ProviderContainer(
      overrides: [tokenStorageProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
    await container.read(authSessionControllerProvider.future);

    final notifier = container.read(authSessionControllerProvider.notifier);
    notifier.markAuthenticated();
    expect(container.read(authSessionControllerProvider).value, isTrue);

    await notifier.markUnauthenticated();
    expect(container.read(authSessionControllerProvider).value, isFalse);
    expect(storage.cleared, isTrue);
  });
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
