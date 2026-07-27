# Requirements: HabitBuilder Mobile - Phase 1

## Infraestructura

- [ ] **INFRA-01** Estructura feature-first con capas `domain`, `data` y `presentation`.
- [ ] **INFRA-02** Riverpod code generation, `go_router` y Dio configurados.
- [ ] **INFRA-03** JWT en almacenamiento seguro, refresh y cierre de sesion.
- [ ] **INFRA-04** Prism sirve el contrato `docs/openapi.yaml`.
- [ ] **INFRA-05** Plataformas Flutter y codigo generado se producen con Flutter 3.44.x.

## Autenticacion

- [ ] **AUTH-01** Registro con nombre, correo y contrasena.
- [ ] **AUTH-02** Consentimiento explicito de terminos y privacidad con versiones.
- [ ] **AUTH-04** Validacion local y errores de backend por campo sin perder datos.
- [ ] **AUTH-05** Login con mensajes genericos para credenciales invalidas.
- [ ] **AUTH-06** Cuenta suspendida bloquea el acceso con un mensaje claro.
- [ ] **AUTH-07** Solicitud y confirmacion de recuperacion de contrasena.

## Perfil

- [ ] **PROFILE-01** Consulta del perfil autenticado.
- [ ] **PROFILE-02** Edicion del objetivo general.
- [ ] **PROFILE-03** Edicion de zona horaria con identificadores IANA.
- [ ] **PROFILE-04** Preferencias de lector de texto, tamano y alto contraste.
- [ ] **PROFILE-05** Preferencias de notificaciones y cierre de sesion.

## Calidad

- [ ] **QUALITY-01** El contrato OpenAPI describe campos y flujos de Phase 1.
- [ ] **QUALITY-02** Cada ticket incluye pruebas unitarias de sus comportamientos.
- [ ] **QUALITY-03** `flutter analyze` termina sin hallazgos.
- [ ] **QUALITY-04** `flutter test --coverage` termina correctamente.
- [ ] **QUALITY-05** Los smoke tests de Prism para auth y perfil terminan correctamente.
- [ ] **QUALITY-06** El codigo nuevo o modificado por cada ticket alcanza al menos 80% de cobertura, excluyendo codigo generado.

## Entrega

- [ ] **DELIVERY-01** HBM-7 se entrega desde `HBM-9/scaffold-mock-server` con commits atomicos y PR propio.
- [ ] **DELIVERY-02** HBM-8 se entrega desde `HBM-9/auth-screens` con commits atomicos y PR propio.
- [ ] **DELIVERY-03** HBM-9 se entrega desde `HBM-9/profile-logout` con commits atomicos y PR propio.

## Trazabilidad

| Requisito | Ticket | Plan | Implementacion principal |
| --- | --- | --- | --- |
| INFRA-01..05, QUALITY-01, DELIVERY-01 | HBM-7 | 01-01 | `lib/core`, esqueletos `lib/features`, `docs`, `scripts` |
| AUTH-01, AUTH-02, AUTH-04..07, QUALITY-02, DELIVERY-02 | HBM-8 | 01-02 | `lib/features/auth`, rutas y pruebas de auth |
| PROFILE-01..05, DELIVERY-03 | HBM-9 | 01-03 | `lib/features/profile`, preferencias globales y pruebas |
| QUALITY-03..06 | HBM-1 | 01-01..03 | analizadores, tests, cobertura, build y smoke tests |
