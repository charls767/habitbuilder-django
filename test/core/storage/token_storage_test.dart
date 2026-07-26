import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitbuilder_mobile/core/storage/token_storage.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  late _MockFlutterSecureStorage secureStorage;
  late SecureTokenStorage storage;

  setUp(() {
    secureStorage = _MockFlutterSecureStorage();
    storage = SecureTokenStorage(secureStorage);
  });

  test('reads access and refresh tokens from their isolated keys', () async {
    when(
      () => secureStorage.read(key: 'auth.access_token'),
    ).thenAnswer((_) async => 'access');
    when(
      () => secureStorage.read(key: 'auth.refresh_token'),
    ).thenAnswer((_) async => 'refresh');

    expect(await storage.readAccessToken(), 'access');
    expect(await storage.readRefreshToken(), 'refresh');
  });

  test('writes both tokens', () async {
    when(
      () => secureStorage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async {});

    await storage.saveTokens(accessToken: 'access', refreshToken: 'refresh');

    verify(
      () => secureStorage.write(key: 'auth.access_token', value: 'access'),
    ).called(1);
    verify(
      () => secureStorage.write(key: 'auth.refresh_token', value: 'refresh'),
    ).called(1);
  });

  test('deletes both tokens when clearing the session', () async {
    when(
      () => secureStorage.delete(key: any(named: 'key')),
    ).thenAnswer((_) async {});

    await storage.clear();

    verify(() => secureStorage.delete(key: 'auth.access_token')).called(1);
    verify(() => secureStorage.delete(key: 'auth.refresh_token')).called(1);
  });
}

class _MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}
