# Roadmap: HabitBuilder Mobile

## Overview

v1.0 entregó identidad, sesión y perfil sobre una base Flutter y OpenAPI
verificable. v2.0 añadió hábitos y metas. v3.0 incorpora recordatorios por
hábito en dos pasos: primero su gestión visible y luego la programación local
con zona horaria, permisos y reprogramación confiable.

## Milestones

- ✅ **v1.0 Identity, Profile & Contract Foundation** — Phase 1 completada el 2026-07-26.
- ✅ **v2.0 Phase 2: Habits and Goals** — completada el 2026-07-28.
- 🚧 **v3.0 Phase 3: Reminders** — en ejecución.

## Phases

- [x] **Phase 1: Identity, Profile & Contract Foundation** - Base Flutter, autenticación y perfil entregados en HBM-7/8/9.
- [x] **Phase 2: Habits and Goals** - Hábitos, transiciones confirmadas y metas vinculadas en HBM-10/11/12.
- [ ] **Phase 3: Reminders** - Gestión de recordatorios y notificaciones locales confiables en HBM-13/14.

## Phase Details

### Phase 1: Identity, Profile & Contract Foundation

**Goal**: Una persona puede registrarse, iniciar y recuperar sesión, administrar su perfil y cerrar sesión sobre una base Flutter reproducible y un mock Prism.

**Depends on**: Nada.

**Requirements**: INFRA-01..05, AUTH-01, AUTH-02, AUTH-04..07, PROFILE-01..05, QUALITY-01..06, DELIVERY-01..03

**Success Criteria** (what must be TRUE):

  1. HBM-7, HBM-8 y HBM-9 existen en ramas y PRs independientes.
  2. La revisión integrada pasa analyze, 44 pruebas, web build y smoke Prism.
  3. Cada ticket supera 80% de cobertura changed-code: 95.06%, 92.42% y 89.80%.

**Plans**: 3 plans completos

Plans:

- [x] 01-01: HBM-7 — scaffold feature-first, red segura y mock server.
- [x] 01-02: HBM-8 — registro, login y recuperación de contraseña.
- [x] 01-03: HBM-9 — perfil, preferencias y logout.

**UI hint**: yes

### Phase 3: Reminders

**Goal**: Una persona autenticada puede configurar recordatorios para sus
hábitos activos y recibir notificaciones locales interpretadas en la zona
horaria de su perfil, incluso después de reinicios y bajo restricciones del
sistema operativo.

**Depends on**: Phase 2. Por decisión D-02, frontend fija primero la forma de
`recordatorios`; HBB-23 converge después del frontend en el orden
HBB-23 → HBB-24 → HBB-27.

**Requirements**: REMINDER-01, REMINDER-02, REMINDER-03, REMINDER-04, REMINDER-05, QUALITY-13, QUALITY-14, QUALITY-15, QUALITY-16, QUALITY-17, QUALITY-18, DELIVERY-07, DELIVERY-08

**Success Criteria** (what must be TRUE):

  1. La persona puede listar, crear y editar varios recordatorios por hábito con mensaje, hora, días activos y estado.
  2. Crear o reactivar queda bloqueado para hábitos pausados o completados sin perder la configuración existente.
  3. La programación usa `TZDateTime` en la zona horaria del perfil, gestiona permisos Android/iOS y se restaura tras reinicio.
  4. La lógica de elegibilidad y cálculo de próximas ocurrencias se prueba sin depender del framework nativo de notificaciones.
  5. HBM-13 se integra antes de abrir HBM-14; ambos superan 80% de changed-code coverage y todos los gates del repositorio.

**Plans**: 8 plans in 8 sequential waves

Plans:

**Wave 1**

- [x] 03-01: HBM-13 — baseline, tooling fail-closed y contrato Prism.

**Wave 2** *(depends on 03-01)*

- [x] 03-02: HBM-13 — dominio, DTO, datasource y repositorio.

**Wave 3** *(depends on 03-02)*

- [x] 03-03: HBM-13 — UI/controlador CU-006, ruta y elegibilidad.

**Wave 4** *(depends on 03-03)*

- [ ] 03-04: HBM-13 — validación, `productTipSha`, único PR, merge y metadata local.

**Wave 5** *(depends on 03-04)*

- [ ] 03-05: HBM-14 — worktree manual, paquetes D-16 y planner/puerto puro.

**Wave 6** *(depends on 03-05)*

- [ ] 03-06: HBM-14 — adaptadores Android/iOS/no-op y configuración nativa.

**Wave 7** *(depends on 03-06)*

- [ ] 03-07: HBM-14 — reconciliación, triggers y estado degradado.

**Wave 8** *(depends on 03-07)*

- [ ] 03-08: HBM-14 — validación, `productTipSha`, único PR, merge y metadata local.

**Manual worktree protocol**:

- `.planning/config.json` fija `workflow.use_worktrees=false`; el orquestador no crea ni selecciona worktrees.
- 03-01..04 se ejecutan en `C:\Users\USER\Desktop\DPPF\HabitBuilder\habitbuilder-mobile`.
- Tras el merge/ancestry de HBM-13, el bootstrap de 03-05 crea y valida `C:\Users\USER\Desktop\DPPF\HabitBuilder\habitbuilder-mobile-hbm14` desde `origin/main` y todos los comandos de 03-05..08 se ejecutan con ese directorio como cwd.
- Los `SUMMARY.md` y handoffs de HBM-14 se escriben y versionan mediante rutas absolutas desde el primary root para que el orquestador los vea; esos commits de metadata permanecen locales y nunca se envían a las ramas de producto.

**Canonical refs**:

- `docs/openapi.yaml`
- `C:/Users/USER/Desktop/DPPF/HabitBuilder - Mockups.html` — CU-006
- Jira HBM-3, HBM-13, HBM-14 y HBB-23

**UI hint**: yes

### Phase 2: Habits and Goals

**Goal**: Una persona autenticada puede administrar sus hábitos y metas, ejecutar transiciones de hábito con confirmación y organizar hábitos bajo metas, sin tracking, progreso, recordatorios ni lógica backend.

**Depends on**: Phase 1; gate HBB-16 aceptado y cargando correctamente en Prism.

**Requirements**: HABIT-01, HABIT-02, HABIT-03, HABIT-04, HABIT-05, HABIT-06, HABIT-07, GOAL-01, GOAL-02, GOAL-03, GOAL-04, QUALITY-07, QUALITY-08, QUALITY-09, QUALITY-10, QUALITY-11, QUALITY-12, DELIVERY-04, DELIVERY-05, DELIVERY-06

**Success Criteria** (what must be TRUE):

  1. La persona puede listar, crear y editar solo sus hábitos con nombre, descripción, fecha de inicio, frecuencia obligatoria, categoría opcional y una meta opcional.
  2. La persona puede pausar, completar o eliminar un hábito solo tras confirmar; cancelar no cambia el recurso y eliminar muestra la advertencia de impacto.
  3. La persona puede listar, abrir, crear y editar sus metas, cambiar su estado y vincular o desvincular hábitos existentes sin mostrar ni calcular progreso.
  4. Cada ticket demuestra pruebas unitarias/widget, cobertura changed-code >=80%, analyze, suite completa, web build y smoke Prism en PASS.
  5. HBM-10, HBM-11 y HBM-12 tienen cada uno una sola rama y un PR propio; `stash@{0}` permanece intacto como referencia y nunca se aplica en bloque.

**Plans**: 3 plans in 3 waves

**Precondition / gate (no es un plan):**

- [x] HBB-16: contrato `habitos`/`metas` acordado en `docs/openapi.yaml` y cargado por Prism.

Plans:

**Wave 1**

- [x] 02-01: HBM-10 — CRUD de hábitos, frecuencia, categoría y campo de meta.

**Wave 2** *(depends on 02-01)*

- [x] 02-02: HBM-11 — confirmaciones de pausa, finalización y eliminación.

**Wave 3** *(depends on 02-02)*

- [x] 02-03: HBM-12 — metas, estados y vínculo/desvínculo con hábitos.

**UI hint**: yes

## Definition of Done v2.0

Phase 2 termina cuando HBB-16 fue consumido como contrato, los tres planes
tienen `SUMMARY.md`, las 20 exigencias de v2.0 están verificadas, cada ticket
tiene su rama y PR, y la revisión integrada pasa:

```text
flutter analyze
flutter test --coverage
flutter build web --release
npm run mock:smoke
```

El gate de cobertura se ejecuta además por ticket con
`node scripts/check-changed-coverage.mjs --base <base-del-PR> --lcov coverage/lcov.info --min 80`.

## Definition of Done v3.0

Phase 3 termina cuando los planes 03-01..03-08 tienen `SUMMARY.md`, los
`productTipSha` capturados de HBM-13 y HBM-14 son ancestros verificables de
`origin/main`, las ramas remotas apuntan exactamente a esos tips y los commits
locales posteriores de metadata permanecen sin publicar, el
handoff frontend para la convergencia posterior de HBB-23 está registrado, la
programación local está aislada detrás de un puerto testeable y la revisión
integrada pasa:

```text
flutter analyze
flutter test --coverage
flutter build web --release
npm run mock:smoke
```

Cada ticket debe superar además 80% de changed-code coverage contra la base
real de su PR.

## Progress

**Execution Order:** Phase 1 → Phase 2 → 03-01 → 03-02 → 03-03 → 03-04 → 03-05 → 03-06 → 03-07 → 03-08.

| Phase | Milestone | Plans Complete | Status | Completed |
| --- | --- | --- | --- | --- |
| 1. Identity, Profile & Contract Foundation | v1.0 | 3/3 | Complete | 2026-07-26 |
| 2. Habits and Goals | v2.0 | 3/3 | Complete | 2026-07-28 |
| 3. Reminders | v3.0 | 3/8 | In Progress|  |
