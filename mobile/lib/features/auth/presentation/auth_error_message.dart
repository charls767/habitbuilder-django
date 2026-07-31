import '../../../core/network/api_exception.dart';

String authErrorMessage(Object error) {
  if (error is! ApiException) {
    return 'No pudimos completar la solicitud. Intenta de nuevo.';
  }

  if (error.code == 'CUENTA_SUSPENDIDA') {
    return 'Tu cuenta está suspendida. Contacta a soporte para recuperar el acceso.';
  }
  if (error.statusCode == 401) {
    return 'El correo o la contraseña no son válidos.';
  }

  return switch (error.code) {
    'EMAIL_YA_REGISTRADO' => 'Ya existe una cuenta con este correo.',
    'TOKEN_RESET_INVALIDO' =>
      'El enlace de recuperación no es válido o ya expiró.',
    _ => error.message,
  };
}
