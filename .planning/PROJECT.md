# HabitBuilder Mobile

## Qué es

Aplicación Flutter para que una persona autenticada organice hábitos y metas
personales desde una experiencia móvil accesible. La base de identidad, sesión y
perfil ya existe; el milestone actual añade la gestión frontend de hábitos y
metas sobre un contrato OpenAPI ejecutable.

## Valor central

Una persona puede convertir una intención personal en hábitos y metas
organizados, administrarlos con claridad y conservar el control de sus datos.

## Milestone actual: v2.0 Phase 2: Habits and Goals

**Objetivo:** Permitir que una persona gestione sus propios hábitos, sus
transiciones de ciclo de vida y sus metas, incluidos los vínculos entre ambos,
sin incorporar recordatorios, tracking, progreso ni lógica de negocio backend.

**Tickets frontend:**

- HBM-10: lista, creación y edición de hábitos; frecuencia, categoría y campo de meta.
- HBM-11: pausa, finalización y eliminación con confirmación.
- HBM-12: lista/detalle, creación y edición de metas; estado y vínculo/desvínculo de hábitos.

**Gate contractual:** HBB-16 debe acordar y publicar en `docs/openapi.yaml` los
endpoints y schemas de `habitos` y `metas` antes de iniciar implementación
frontend. Es una precondición, no un cuarto plan móvil.

## Requisitos

### Validados

- ✓ Base Flutter 3.44 feature-first, Riverpod, go_router, Dio y almacenamiento seguro — v1.0, Phase 1.
- ✓ Registro, login y recuperación de contraseña con manejo seguro de errores — v1.0, HBM-8.
- ✓ Perfil, preferencias visuales y cierre de sesión confirmado — v1.0, HBM-9.
- ✓ Tres PRs aislados con cobertura changed-code de 95.06%, 92.42% y 89.80%; 44 pruebas integradas, analyze, web build y Prism en PASS — v1.0, Phase 1.

### Activos

- [ ] HABIT-01..07: la persona gestiona únicamente sus hábitos, incluida frecuencia, categoría, meta opcional y transiciones confirmadas.
- [ ] GOAL-01..04: la persona gestiona sus metas, estados, fecha objetivo y vínculos con hábitos existentes.
- [ ] QUALITY-07..12: cada ticket demuestra pruebas unitarias/widget, cobertura changed-code >=80%, analyze, suite completa, web build y smoke Prism.
- [ ] DELIVERY-04..06: HBM-10, HBM-11 y HBM-12 se entregan cada uno en una rama y un PR propios.

### Fuera de alcance

- Recordatorios y programación de notificaciones — pertenecen a una fase posterior.
- Tracking o registro de completaciones, rachas y check-ins — no forma parte de HBM-10/11/12.
- Cálculo, métricas, reportes o visualización de progreso — se difiere aunque HBM-12 mencione “progress”.
- Lógica de negocio backend, invariantes de agregados y persistencia real — responsabilidad del track HBB.
- Aplicar íntegramente `stash@{0}` — es una referencia histórica para consultar selectivamente, no una fuente para restaurar en bloque.

## Contexto

Phase 1 terminó el 2026-07-26 con HBM-7/8/9, tres ramas y tres PRs apilados.
La revisión integrada pasó `flutter analyze`, 44 pruebas,
`flutter build web --release` y smoke de Prism. Los artefactos y evidencia
detallada permanecen en `.planning/phases/01-identity-profile-contract-foundation/`
y `.planning/VERIFICATION.md`.

Al iniciar este milestone, la rama activa observada es
`HBM-10/habit-crud`. Existe `stash@{0}` con nombre
`pre-phase-1-combined-worktree`; contiene trabajo combinado de fases futuras y
debe permanecer intacto.

## Restricciones

- **Contrato:** HBB-16 debe estar acordado y disponible en `docs/openapi.yaml` antes de implementar HBM-10 — evita inventar endpoints o campos.
- **Arquitectura:** Mantener Flutter 3.44.x/Dart 3.12+, feature-first (`domain`, `data`, `presentation`), Riverpod, go_router y Dio — continuidad con Phase 1.
- **Propiedad:** La UI solo consulta o modifica recursos del usuario autenticado según el contrato — no se crean atajos de autorización en cliente.
- **Calidad:** Cada ticket incluye pruebas unitarias y widget pertinentes y >=80% de cobertura sobre código nuevo o modificado, excluyendo generado.
- **Gates:** Cada PR debe pasar `flutter analyze`, suite completa con cobertura, web build release y smoke Prism.
- **Entrega:** Una rama y un PR por HBM-10, HBM-11 y HBM-12; commits atómicos y evidencia por ticket.
- **Seguridad del trabajo previo:** `stash@{0}` es solo referencia; no ejecutar `git stash pop` ni aplicarlo completo.

## Decisiones clave

| Decisión | Justificación | Resultado |
| --- | --- | --- |
| Continuar la numeración en Phase 2 para v2.0 | Conserva la historia del milestone anterior y evita colisiones | — Pendiente |
| Ejecutar tres waves HBM-10 → HBM-11 → HBM-12 | Las transiciones dependen del CRUD y las metas reutilizan hábitos existentes | — Pendiente |
| Tratar HBB-16 como gate, no como plan frontend | El contrato debe preceder al código móvil y pertenece al track backend/contrato | — Pendiente |
| Excluir todo progreso pese a la mención en HBM-12 | El alcance explícito del milestone no incluye métricas ni tracking | — Pendiente |
| Mantener `stash@{0}` intacto y solo consultarlo | Evita reintroducir una implementación combinada o trabajo fuera de alcance | — Pendiente |

## Evolución

Este documento evoluciona en transiciones de fase y límites de milestone.

**Después de cada transición de fase:**

1. Mover requisitos verificados a Validados.
2. Registrar requisitos invalidados o emergentes.
3. Actualizar decisiones y contexto si la implementación cambia el entendimiento.

**Después de cada milestone:**

1. Revisar valor central, alcance y exclusiones.
2. Consolidar evidencia y requisitos validados.
3. Preparar el contexto del siguiente milestone sin borrar la historia útil.

---
*Última actualización: 2026-07-28 al iniciar milestone v2.0 Phase 2: Habits and Goals.*
