import 'package:flutter_test/flutter_test.dart';
import 'package:habitbuilder_mobile/core/network/api_exception.dart';
import 'package:habitbuilder_mobile/features/auth/presentation/auth_error_message.dart';

void main() {
  test('any 401 uses a generic credential message', () {
    const exception = ApiException(
      statusCode: 401,
      code: 'USUARIO_NO_EXISTE',
      message: 'El correo no existe.',
    );

    expect(
      authErrorMessage(exception),
      'El correo o la contraseña no son válidos.',
    );
  });

  test('suspended account receives a clear status message', () {
    const exception = ApiException(
      statusCode: 423,
      code: 'CUENTA_SUSPENDIDA',
      message: 'Cuenta suspendida.',
    );

    expect(authErrorMessage(exception), contains('suspendida'));
  });
}
