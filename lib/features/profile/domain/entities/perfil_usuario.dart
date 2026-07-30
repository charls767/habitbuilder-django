enum TextSizePreference {
  small('normal', 'Normal', 0.9),
  medium('grande', 'Grande', 1),
  large('extra_grande', 'Extra grande', 1.15);

  const TextSizePreference(this.apiValue, this.label, this.scaleFactor);

  factory TextSizePreference.fromApiValue(String? value) {
    if (value == 'pequeno' || value == 'mediano') {
      return value == 'pequeno' ? small : medium;
    }
    return values.firstWhere(
      (preference) => preference.apiValue == value,
      orElse: () => medium,
    );
  }

  final String apiValue;
  final String label;
  final double scaleFactor;
}

class AccessibilityPreferences {
  const AccessibilityPreferences({
    required this.textToSpeech,
    required this.textSize,
    required this.highContrast,
  });

  const AccessibilityPreferences.defaults()
    : textToSpeech = false,
      textSize = TextSizePreference.medium,
      highContrast = false;

  final bool textToSpeech;
  final TextSizePreference textSize;
  final bool highContrast;
}

class NotificationPreferences {
  const NotificationPreferences({
    required this.enabled,
    required this.habitReminders,
    required this.weeklySummary,
  });

  const NotificationPreferences.defaults()
    : enabled = true,
      habitReminders = true,
      weeklySummary = true;

  final bool enabled;
  final bool habitReminders;
  final bool weeklySummary;
}

class PerfilUsuario {
  const PerfilUsuario({
    required this.usuarioId,
    required this.nombreCompleto,
    required this.zonaHoraria,
    required this.objetivoGeneral,
    required this.accessibility,
    required this.notifications,
    this.fotoUrl,
    this.biografia,
  });

  final String usuarioId;
  final String nombreCompleto;
  final String zonaHoraria;
  final String objetivoGeneral;
  final AccessibilityPreferences accessibility;
  final NotificationPreferences notifications;
  final String? fotoUrl;
  final String? biografia;
}
