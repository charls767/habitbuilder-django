# Roadmap: HabitBuilder Mobile - Phase 1

## Overview

Esta fase entrega los cimientos de la aplicacion movil, los flujos de
identidad y la gestion del perfil. El trabajo se separa en tres tickets y tres
PRs revisables, conservando el contrato OpenAPI como fuente de verdad mientras
el backend termina sus endpoints.

## Phases

- [x] **Phase 1: Identity, Profile & Contract Foundation** - Completar HBM-7, HBM-8 y HBM-9 con pruebas y PRs independientes.

## Phase Details

### Phase 1: Identity, Profile & Contract Foundation

**Goal**: Entregar una base Flutter reproducible, autenticacion completa y perfil editable con preferencias y logout, todo validado contra el mock Prism.

**Depends on**: HBB-7 para la integracion backend real; el mock OpenAPI permite
completar y revisar el frontend sin bloquear la fase.

**Requirements**: INFRA-01, INFRA-02, INFRA-03, INFRA-04, INFRA-05, AUTH-01, AUTH-02, AUTH-04, AUTH-05, AUTH-06, AUTH-07, PROFILE-01, PROFILE-02, PROFILE-03, PROFILE-04, PROFILE-05, QUALITY-01, QUALITY-02, QUALITY-03, QUALITY-04, QUALITY-05, QUALITY-06, DELIVERY-01, DELIVERY-02, DELIVERY-03

**Success Criteria** (what must be TRUE):

  1. HBM-7, HBM-8 y HBM-9 existen como cambios aislados en ramas `HBM-9/<descripcion-corta>`, con commits atomicos y un PR de Bitbucket por ticket.
  2. Cada ticket incluye pruebas unitarias y demuestra al menos 80% de cobertura sobre codigo nuevo o modificado, excluyendo archivos generados.
  3. `flutter analyze`, `flutter test --coverage` y `flutter build web --release` terminan correctamente en la revision integrada.
  4. Prism carga `docs/openapi.yaml` y sus smoke tests de autenticacion y perfil pasan.
  5. Ningun token se almacena fuera de `flutter_secure_storage` y los errores de login no revelan si una cuenta existe.

**Plans**: 3 plans in 3 waves

Plans:

**Wave 1**

- [x] 01-01: HBM-7 - scaffold feature-first, red, almacenamiento y mock server.

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 01-02: HBM-8 - registro, login y recuperacion de contrasena.

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 01-03: HBM-9 - perfil, preferencias, accesibilidad y logout.

## Definition of Done

La fase se considera completa cuando los tres planes tienen `SUMMARY.md`, sus
gates de pruebas y cobertura pasan, los tres PRs estan creados y la evidencia
queda registrada en `.planning/VERIFICATION.md`.

## Progress

| Phase | Plans Complete | Status | Completed |
| --- | --- | --- | --- |
| 1. Identity, Profile & Contract Foundation | 3/3 | Complete | 2026-07-26 |
