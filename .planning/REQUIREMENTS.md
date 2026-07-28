# Requisitos: HabitBuilder Mobile — v2.0 Phase 2: Habits and Goals

**Definidos:** 2026-07-28

**Valor central:** Una persona puede convertir una intención personal en hábitos y metas organizados, administrarlos con claridad y conservar el control de sus datos.

## Requisitos v2.0

### Hábitos

- [ ] **HABIT-01**: La persona puede ver una lista de sus propios hábitos y abrir el detalle de uno sin mostrar hábitos de otra cuenta.
- [ ] **HABIT-02**: La persona puede crear y editar un hábito propio con nombre, descripción y fecha de inicio, conservando los valores del formulario cuando hay errores.
- [ ] **HABIT-03**: La persona debe elegir una frecuencia válida al crear o editar: diaria, días específicos de la semana o N veces por período.
- [ ] **HABIT-04**: La persona puede pausar un hábito propio solo después de confirmar la acción; cancelar conserva el estado anterior.
- [ ] **HABIT-05**: La persona puede marcar un hábito propio como completado solo después de confirmar la acción; cancelar conserva el estado anterior.
- [ ] **HABIT-06**: La persona puede eliminar un hábito propio solo después de confirmar una advertencia explícita sobre el impacto en registros o reportes relacionados.
- [ ] **HABIT-07**: La persona puede asignar opcionalmente una categoría y vincular el hábito a una sola meta propia, o dejar ambos campos vacíos.

### Metas

- [ ] **GOAL-01**: La persona puede ver la lista y el detalle de sus propias metas con estado y fecha objetivo, sin métricas ni visualización de progreso.
- [ ] **GOAL-02**: La persona puede crear y editar una meta propia con sus datos y fecha objetivo, conservando los valores del formulario cuando hay errores.
- [ ] **GOAL-03**: La persona puede cambiar el estado de una meta entre en progreso, alcanzada, pausada y cancelada independientemente del estado de sus hábitos vinculados.
- [ ] **GOAL-04**: La persona puede vincular y desvincular hábitos propios existentes; una meta admite cero, uno o varios hábitos y cada hábito se vincula como máximo a una meta.

### Calidad

- [ ] **QUALITY-07**: Cada ticket incluye pruebas unitarias para dominio/data y pruebas widget para sus flujos visibles y decisiones de confirmación.
- [ ] **QUALITY-08**: Cada ticket alcanza al menos 80.00% de cobertura sobre código Dart nuevo o modificado contra la base real de su PR, excluyendo código generado.
- [ ] **QUALITY-09**: `flutter analyze` termina con exit code 0 para cada ticket y para la revisión integrada.
- [ ] **QUALITY-10**: `flutter test --coverage` ejecuta correctamente la suite completa para cada ticket y para la revisión integrada.
- [ ] **QUALITY-11**: `flutter build web --release` termina con exit code 0 para cada ticket y para la revisión integrada.
- [ ] **QUALITY-12**: Prism carga el contrato aceptado de HBB-16 y el smoke de `habitos`/`metas` termina correctamente para cada ticket y para la revisión integrada.

### Entrega

- [ ] **DELIVERY-04**: HBM-10 se entrega en una única rama dedicada `HBM-10/habit-crud` y un PR propio con commits atómicos y evidencia de gates.
- [ ] **DELIVERY-05**: HBM-11 se entrega en una única rama dedicada `HBM-11/habit-lifecycle` y un PR propio con commits atómicos y evidencia de gates.
- [ ] **DELIVERY-06**: HBM-12 se entrega en una única rama dedicada `HBM-12/goals-linking` y un PR propio con commits atómicos y evidencia de gates.

## Gate contractual

HBB-16 no es un requisito ni un cuarto plan frontend. Antes de iniciar 02-01,
el contrato aceptado en `docs/openapi.yaml` debe definir CRUD de hábitos y
metas, frecuencias, categoría, transiciones de pausa/finalización/eliminación y
vínculo/desvínculo hábito-meta; Prism debe cargarlo sin errores. Al
2026-07-28, HBB-16 figura en Jira como **Tareas por hacer**.

## Fuera de alcance

| Funcionalidad | Razón |
| --- | --- |
| Recordatorios y notificaciones programadas | Corresponden a una fase posterior, no a HBM-10/11/12. |
| Tracking, check-ins, registros de completación y rachas | El milestone administra definiciones y estados, no actividad diaria. |
| Progreso, porcentajes, métricas, reportes o cálculos derivados | Se excluyen explícitamente; GOAL-01 solo muestra estado y fecha objetivo. |
| Lógica de negocio backend e invariantes de agregados | Pertenece al track HBB; mobile consume el contrato HBB-16. |
| Implementaciones combinadas recuperadas desde `stash@{0}` | El stash es referencia histórica y no debe aplicarse ni hacerse pop en bloque. |

## Trazabilidad

| Requisito | Jira | Fase | Plan | Estado |
| --- | --- | --- | --- | --- |
| HABIT-01 | HBM-10 | Phase 2 | 02-01 | Pendiente |
| HABIT-02 | HBM-10 | Phase 2 | 02-01 | Pendiente |
| HABIT-03 | HBM-10 | Phase 2 | 02-01 | Pendiente |
| HABIT-04 | HBM-11 | Phase 2 | 02-02 | Pendiente |
| HABIT-05 | HBM-11 | Phase 2 | 02-02 | Pendiente |
| HABIT-06 | HBM-11 | Phase 2 | 02-02 | Pendiente |
| HABIT-07 | HBM-10 | Phase 2 | 02-01 | Pendiente |
| GOAL-01 | HBM-12 | Phase 2 | 02-03 | Pendiente |
| GOAL-02 | HBM-12 | Phase 2 | 02-03 | Pendiente |
| GOAL-03 | HBM-12 | Phase 2 | 02-03 | Pendiente |
| GOAL-04 | HBM-12 | Phase 2 | 02-03 | Pendiente |
| QUALITY-07 | HBM-10/11/12 | Phase 2 | 02-01..03 | Pendiente |
| QUALITY-08 | HBM-10/11/12 | Phase 2 | 02-01..03 | Pendiente |
| QUALITY-09 | HBM-10/11/12 | Phase 2 | 02-01..03 | Pendiente |
| QUALITY-10 | HBM-10/11/12 | Phase 2 | 02-01..03 | Pendiente |
| QUALITY-11 | HBM-10/11/12 | Phase 2 | 02-01..03 | Pendiente |
| QUALITY-12 | HBM-10/11/12 | Phase 2 | 02-01..03 | Pendiente |
| DELIVERY-04 | HBM-10 | Phase 2 | 02-01 | Pendiente |
| DELIVERY-05 | HBM-11 | Phase 2 | 02-02 | Pendiente |
| DELIVERY-06 | HBM-12 | Phase 2 | 02-03 | Pendiente |

**Cobertura:**

- Requisitos v2.0: 20.
- Mapeados exactamente una vez a Phase 2: 20.
- Huérfanos: 0.
- Duplicados entre fases: 0.

## Historia validada de v1.0

Phase 1 completó INFRA-01..05, AUTH-01/02/04..07,
PROFILE-01..05, QUALITY-01..06 y DELIVERY-01..03. La evidencia permanece en
`.planning/VERIFICATION.md` y en los `SUMMARY.md` de
`.planning/phases/01-identity-profile-contract-foundation/`.

---
*Última actualización: 2026-07-28 al crear la trazabilidad del milestone v2.0.*
