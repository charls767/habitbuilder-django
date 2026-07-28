# Phase 2: Habits and Goals — Context

**Gathered:** 2026-07-28

**Status:** Executed and in review; HBB-16 satisfied by the official backend
branch `HBB-16/openapi-habitos-metas-contract`, merged to `main` through PR
#7/#8. The earlier backend PR #1 is obsolete and closed.

<domain>

## Límite de la fase

Esta fase cubre exactamente tres tickets frontend de la épica HBM-2:

- **HBM-10 / 02-01:** lista, creación y edición de hábitos; frecuencia,
  categoría y campo de meta — HABIT-01, HABIT-02, HABIT-03, HABIT-07.
- **HBM-11 / 02-02:** pausa, finalización y eliminación con confirmación —
  HABIT-04, HABIT-05, HABIT-06.
- **HBM-12 / 02-03:** lista/detalle, creación y edición de metas; estado y
  vínculo/desvínculo de hábitos — GOAL-01, GOAL-02, GOAL-03, GOAL-04.

No incluye recordatorios, tracking, registros de completación, rachas,
progreso, porcentajes, reportes ni lógica de negocio backend.

</domain>

<precondition>

## Gate HBB-16

HBB-16 es una precondición compartida y no un cuarto plan frontend. La
precondición quedó satisfecha por la implementación oficial integrada mediante
los PR backend #7/#8; antes de implementar 02-01 se conservó como gate de
verificación que:

1. `docs/openapi.yaml` contenga grupos de endpoints `habitos` y `metas`.
2. El contrato defina CRUD, las tres variantes de frecuencia, categoría
   opcional, estados/transiciones y vínculo/desvínculo hábito-meta.
3. Los schemas indiquen propiedad/autenticación y errores esperados sin exigir
   que mobile implemente autorización.
4. Prism cargue el contrato sin error y el smoke cubra al menos una respuesta
   válida y una inválida por grupo.
5. Mobile consuma ese contrato sin inventar campos, endpoints o reglas.

Comprobación mínima del gate:

```text
npm run mock:smoke
```

El 2026-07-28 se verificó que mobile y backend tienen el mismo SHA-256 para
`docs/openapi.yaml` y que `npm run mock:smoke` pasa cubriendo `habits` y
`goals`. Jira todavía figuraba **En curso**; ese estado administrativo no
reabre el gate contractual ya satisfecho.

</precondition>

<decisions>

## Decisiones de implementación

### Secuencia y entrega

- **D-01:** Se ejecutan exactamente tres waves: 02-01 → 02-02 → 02-03.
- **D-02:** Las ramas exactas son `HBM-10/habit-crud`,
  `HBM-11/habit-lifecycle` y `HBM-12/goals-linking`.
- **D-03:** Cada ticket tiene un único PR propio, commits atómicos y evidencia
  de aceptación. Si las dependencias aún no se integran, los PRs pueden
  apilarse y luego retargetearse a `main`.

### Arquitectura y alcance

- **D-04:** Mantener feature-first con `domain`, `data`, `presentation`,
  Riverpod, go_router y Dio; reutilizar sesión y errores de Phase 1.
- **D-05:** El cliente representa y presenta estados definidos por OpenAPI; no
  reimplementa invariantes, autorización, cálculos de rachas o reglas backend.
- **D-06:** “Hábitos del día” es una lista de definiciones de hábito en esta
  fase; no incorpora check-ins ni registro diario.
- **D-07:** En HBM-12 solo se muestran estado y fecha objetivo. La mención de
  “progress” en Jira queda excluida: no hay porcentaje, métrica, gráfico ni
  cálculo derivado.

### Seguridad del trabajo previo

- **D-08:** `stash@{0}` (`pre-phase-1-combined-worktree`) es referencia
  histórica. Se puede inspeccionar por archivo para entender intención, pero
  nunca ejecutar `git stash pop`, `git stash apply` global ni restaurarlo en
  bloque.
- **D-09:** Cualquier archivo recuperado selectivamente del stash debe
  contrastarse con HBB-16, reconstruirse dentro del ticket correcto y pasar
  revisión de alcance antes de stage.

### Calidad

- **D-10:** Cada ticket incluye pruebas unitarias de dominio/data y pruebas
  widget de los comportamientos visibles y confirmaciones que introduce.
- **D-11:** El umbral obligatorio es >=80.00% sobre código Dart nuevo o
  modificado contra la base real del PR, excluyendo generado.
- **D-12:** Un ticket no termina hasta que pasan pruebas focalizadas, suite
  completa, analyze, web build, smoke Prism, push y PR.

</decisions>

<acceptance>

## Criterios de aceptación ejecutables

### Gate previo

- [x] `docs/openapi.yaml` contiene `habitos` y `metas` con los campos y
  operaciones exigidos por HBB-16.
- [x] `npm run mock:smoke` termina con exit code 0 e incluye ambos grupos.
- [ ] No existe un plan 02-00 ni un cuarto plan frontend para HBB-16.

### 02-01 / HBM-10 — CRUD, frecuencia, categoría y meta

- [ ] Al cargar la pantalla, una cuenta ve solo sus hábitos y puede abrir su
  detalle; estados loading, vacío y error son visibles y testeados.
- [ ] Crear y editar aceptan nombre, descripción y fecha de inicio; un error de
  validación o API conserva los demás valores escritos.
- [ ] El formulario no envía sin frecuencia y permite exactamente diaria, días
  específicos o N veces por período con parámetros válidos según OpenAPI.
- [ ] Categoría y meta son opcionales; el selector de meta solo ofrece metas de
  la cuenta y permite dejar el hábito sin vínculo.
- [ ] El diff contra la base del PR contiene solo HBM-10 y wiring estrictamente
  necesario; no contiene lifecycle, goals completos, reminders, tracking,
  progress ni lógica backend.

### 02-02 / HBM-11 — transiciones confirmadas

- [ ] Pausar abre confirmación; cancelar no llama al repositorio ni cambia la
  UI y confirmar refleja la respuesta del contrato.
- [ ] Completar abre confirmación; cancelar conserva el estado y confirmar
  refleja el hábito completado.
- [ ] Eliminar abre una advertencia que menciona el impacto en registros o
  reportes relacionados; cancelar conserva el hábito y confirmar lo retira de
  lista/detalle tras éxito.
- [ ] Errores de pausa, finalización o eliminación mantienen el recurso visible
  y ofrecen un mensaje accionable sin fingir éxito.
- [ ] El diff contra 02-01 contiene solo HBM-11 y wiring necesario.

### 02-03 / HBM-12 — metas y vínculos

- [ ] La cuenta ve lista y detalle de sus metas con estado y fecha objetivo,
  incluidos estados loading, vacío y error.
- [ ] Crear y editar una meta conserva el formulario ante errores y persiste la
  fecha objetivo según OpenAPI.
- [ ] El estado puede cambiar entre en progreso, alcanzada, pausada y cancelada
  sin cambiar automáticamente el estado de hábitos vinculados.
- [ ] La UI permite vincular y desvincular hábitos existentes: una meta admite
  cero, uno o varios hábitos y un hábito aparece vinculado como máximo a una
  meta.
- [ ] Ninguna pantalla, modelo o prueba introduce porcentajes, barras, métricas
  o cálculos de progreso.
- [ ] El diff contra 02-02 contiene solo HBM-12 y wiring necesario.

### Gates obligatorios por ticket

Ejecutar desde la rama del ticket, reemplazando `<base-del-PR>` por su base real:

```text
flutter test <rutas-focalizadas-del-ticket>
flutter analyze
flutter test --coverage
node scripts/check-changed-coverage.mjs --base <base-del-PR> --lcov coverage/lcov.info --min 80
flutter build web --release
npm run mock:smoke
git diff <base-del-PR>...HEAD --name-status
```

Criterio de salida para cada wave:

- [ ] Pruebas unitarias y widget del ticket pasan.
- [ ] Suite completa pasa y genera `coverage/lcov.info`.
- [ ] Changed-code coverage reporta >=80.00%.
- [ ] Analyze, web build y Prism smoke pasan.
- [ ] Rama remota y PR propio existen con comandos, resultados y porcentaje de
  cobertura documentados.
- [ ] `stash@{0}` sigue existiendo e intacto; no fue aplicado ni eliminado.

</acceptance>

<canonical_refs>

## Referencias canónicas

- Jira HBM-2, HBM-10, HBM-11 y HBM-12.
- Jira HBB-16 como gate contractual.
- Mockups `mockup-cu004-inicio-habitos`,
  `mockup-cu004-crear-habito` y `mockup-cu005-metas`.
- `.planning/PROJECT.md`
- `.planning/REQUIREMENTS.md`
- `.planning/ROADMAP.md`
- `.planning/VERIFICATION.md`
- `docs/openapi.yaml` una vez aceptado por HBB-16.

</canonical_refs>

<deferred>

## Diferido explícitamente

- Recordatorios y notificaciones programadas.
- Tracking, check-ins, completaciones y rachas.
- Progreso, porcentajes, métricas, gráficas y reportes.
- Motor backend, persistencia e invariantes de agregados.
- Restauración masiva de la implementación combinada de `stash@{0}`.

</deferred>
