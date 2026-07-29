# Roadmap: HabitBuilder Mobile

## Overview

v1.0 entregó identidad, sesión y perfil sobre una base Flutter y OpenAPI
verificable. v2.0 continúa con una única fase coherente: primero CRUD y
clasificación de hábitos, luego sus transiciones confirmadas y finalmente metas
con vínculos a hábitos. HBB-16 desbloquea la ejecución al fijar el contrato, pero
no añade un plan frontend.

## Milestones

- ✅ **v1.0 Identity, Profile & Contract Foundation** — Phase 1 completada el 2026-07-26.
- ✅ **v2.0 Phase 2: Habits and Goals** — completada el 2026-07-28.

## Phases

- [x] **Phase 1: Identity, Profile & Contract Foundation** - Base Flutter, autenticación y perfil entregados en HBM-7/8/9.
- [x] **Phase 2: Habits and Goals** - Hábitos, transiciones confirmadas y metas vinculadas en HBM-10/11/12.

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

## Progress

**Execution Order:** Phase 1 → gate HBB-16 → 02-01 → 02-02 → 02-03.

| Phase | Milestone | Plans Complete | Status | Completed |
| --- | --- | --- | --- | --- |
| 1. Identity, Profile & Contract Foundation | v1.0 | 3/3 | Complete | 2026-07-26 |
| 2. Habits and Goals | v2.0 | 3/3 | Complete | 2026-07-28 |
