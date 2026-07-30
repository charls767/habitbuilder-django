# HabitBuilder Mobile

## Qué es

Aplicación Flutter para que una persona autenticada organice hábitos y metas
personales desde una experiencia móvil accesible. Identidad, perfil, hábitos y
metas ya están integrados; el milestone actual añade recordatorios locales
confiables sobre un contrato OpenAPI ejecutable.

## Valor central

Una persona puede convertir una intención personal en hábitos y metas
organizados, administrarlos con claridad y conservar el control de sus datos.

## Milestone actual: v3.0 Phase 3: Reminders

**Objetivo:** Permitir que una persona configure recordatorios para hábitos
activos y reciba notificaciones locales en la zona horaria de su perfil con
comportamiento confiable ante permisos, suspensión y reinicios.

**Tickets frontend:**

- HBM-13: lista, creación, edición y activación de recordatorios según CU-006.
- HBM-14: programación local con zona horaria, permisos, exact alarm y reboot.

**Sincronización contractual:** HBB-23 formaliza en backend los endpoints de
`recordatorios` y el puerto `NotificationSender`. Mobile fija primero la forma
consumida en `docs/openapi.yaml`; ambos repos deben converger antes del cierre.

## Requisitos

### Validados

- ✓ Base Flutter 3.44 feature-first, Riverpod, go_router, Dio y almacenamiento seguro — v1.0, Phase 1.
- ✓ Registro, login y recuperación de contraseña con manejo seguro de errores — v1.0, HBM-8.
- ✓ Perfil, preferencias visuales y cierre de sesión confirmado — v1.0, HBM-9.
- ✓ Tres PRs aislados con cobertura changed-code de 95.06%, 92.42% y 89.80%; 44 pruebas integradas, analyze, web build y Prism en PASS — v1.0, Phase 1.
- ✓ Hábitos y metas integrados mediante HBM-10/11/12; 146 pruebas y gates completos — v2.0, Phase 2.

### Activos

- [ ] REMINDER-01..05: gestión y scheduling confiable de recordatorios por hábito.
- [ ] QUALITY-13..18: pruebas unitarias/widget, cobertura changed-code >=80%, analyze, suite completa, web build y smoke Prism.
- [ ] DELIVERY-07..08: HBM-13 y HBM-14 se entregan en ese orden, cada uno con rama y PR propios.

### Fuera de alcance

- Tracking o registro de completaciones, rachas y check-ins — no forma parte de HBM-10/11/12.
- Cálculo, métricas, reportes o visualización de progreso — se difiere aunque HBM-12 mencione “progress”.
- Push remoto, campañas, geofencing, snooze y estadísticas de notificaciones — no forman parte de HBM-13/14.
- Lógica de negocio backend, invariantes de agregados y persistencia real — responsabilidad del track HBB.
- Aplicar íntegramente `stash@{0}` — es una referencia histórica para consultar selectivamente, no una fuente para restaurar en bloque.

## Contexto

Phase 2 terminó el 2026-07-28 con HBM-10/11/12 y quedó integrada en `main`.
La revisión final pasó `flutter analyze`, 146 pruebas,
`flutter build web --release` y smoke de Prism. Existe `stash@{0}` con nombre
`pre-phase-1-combined-worktree`; contiene trabajo combinado de fases futuras y
debe permanecer intacto.

## Restricciones

- **Contrato:** La forma de HBB-23 debe quedar explícita en `docs/openapi.yaml`; mobile y backend deben terminar con el mismo contrato.
- **Arquitectura:** Mantener Flutter 3.44.x/Dart 3.12+, feature-first (`domain`, `data`, `presentation`), Riverpod, go_router y Dio — continuidad con Phase 1.
- **Propiedad:** La UI solo consulta o modifica recursos del usuario autenticado según el contrato — no se crean atajos de autorización en cliente.
- **Calidad:** Cada ticket incluye pruebas unitarias y widget pertinentes y >=80% de cobertura sobre código nuevo o modificado, excluyendo generado.
- **Gates:** Cada PR debe pasar `flutter analyze`, suite completa con cobertura, web build release y smoke Prism.
- **Entrega:** HBM-13 se integra antes de abrir HBM-14; commits atómicos y evidencia por ticket.
- **Seguridad del trabajo previo:** `stash@{0}` es solo referencia; no ejecutar `git stash pop` ni aplicarlo completo.

## Decisiones clave

| Decisión | Justificación | Resultado |
| --- | --- | --- |
| Ejecutar HBM-13 antes de HBM-14 | El scheduler necesita recordatorios persistidos y una UI estable | — Pendiente |
| Usar la zona horaria del perfil | Evita depender del reloj o zona local del dispositivo | — Pendiente |
| Aislar scheduling detrás de un puerto | Permite pruebas deterministas sin framework nativo | — Pendiente |
| Ejecutar backend HBB-23 → HBB-24 → HBB-27 | Contrato, dominio y luego cobertura de reglas | — Pendiente |
| Mantener `stash@{0}` intacto y solo consultarlo | Evita reintroducir trabajo fuera de alcance | — Pendiente |

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
*Última actualización: 2026-07-28 al iniciar milestone v3.0 Phase 3: Reminders.*
