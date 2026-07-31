abstract final class AuthValidators {
  static String? name(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Ingresa tu nombre';
    if (trimmed.length < 2) return 'El nombre debe tener al menos 2 caracteres';
    return null;
  }

  static String? email(String? value) {
    final trimmed = value?.trim() ?? '';
    final pattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!pattern.hasMatch(trimmed)) return 'Ingresa un correo válido';
    return null;
  }

  static String? password(String? value) {
    final password = value ?? '';
    if (password.length < 8) return 'Usa al menos 8 caracteres';
    if (!RegExp(r'[A-Z]').hasMatch(password) ||
        !RegExp(r'[a-z]').hasMatch(password) ||
        !RegExp(r'\d').hasMatch(password)) {
      return 'Incluye mayúscula, minúscula y número';
    }
    return null;
  }

  static String? passwordConfirmation(String? value, String password) {
    if (value != password) return 'Las contraseñas no coinciden';
    return null;
  }
}
