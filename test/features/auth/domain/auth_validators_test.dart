import 'package:flutter_test/flutter_test.dart';
import 'package:habitbuilder_mobile/features/auth/domain/auth_validators.dart';

void main() {
  group('AuthValidators.email', () {
    test('accepts a valid email', () {
      expect(AuthValidators.email('camila@example.com'), isNull);
    });

    test('rejects an invalid email', () {
      expect(AuthValidators.email('camila@'), isNotNull);
    });
  });

  group('AuthValidators.password', () {
    test('accepts a password with the required strength', () {
      expect(AuthValidators.password('Segura123'), isNull);
    });

    test('rejects short or weak passwords', () {
      expect(AuthValidators.password('abc'), isNotNull);
      expect(AuthValidators.password('sololetras'), isNotNull);
    });
  });

  test('password confirmation must match', () {
    expect(
      AuthValidators.passwordConfirmation('Segura123', 'Segura123'),
      isNull,
    );
    expect(
      AuthValidators.passwordConfirmation('Otra123', 'Segura123'),
      isNotNull,
    );
  });
}
