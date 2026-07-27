# HabitBuilder Mobile - Phase 1

## Objetivo

Entregar la épica HBM-1 de extremo a extremo: contrato OpenAPI ejecutable,
base Flutter feature-first, registro/login/recuperación de contraseña y perfil
editable con preferencias de accesibilidad, notificaciones y cierre de sesión.

## Fuente de verdad

- HBM-1: Phase 1: Identity, Profile & Contract Foundation
- HBM-7: Scaffold Flutter feature-first skeleton + mock server
- HBM-8: Build registration, login & password-reset screens
- HBM-9: Build profile screen + logout
- HBB-1: criterios globales de éxito y sincronización del contrato

## Valor central

Una persona puede crear y recuperar su cuenta, iniciar y cerrar sesión y
administrar su perfil sin depender de que el backend esté terminado.

## Restricciones

- Flutter 3.44.x y Dart 3.12+.
- Tokens únicamente en `flutter_secure_storage`.
- El mock local se sirve con Prism desde `docs/openapi.yaml`.
- Los errores de credenciales no revelan si un correo existe.
- La zona horaria usa identificadores IANA.
- La verificación reproducible debe ejecutarse con `scripts/bootstrap.ps1`,
  que exige Flutter 3.44.x.

## Fuera de alcance

- Lógica backend, envío real de correos y persistencia de consentimientos.
- Funcionalidad de hábitos, metas, recordatorios y progreso posterior a Phase 1.
- Implementación de un motor TTS; Phase 1 guarda y aplica la preferencia visual.
