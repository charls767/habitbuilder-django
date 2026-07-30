# Phase 1: Identity, Profile & Contract Foundation - Context

**Gathered:** 2026-07-26
**Status:** Ready for planning

<domain>

## Phase Boundary

Esta fase cubre exactamente los tickets frontend HBM-7, HBM-8 y HBM-9 de la
epica HBM-1:

- HBM-7: scaffold Flutter feature-first y mock server.
- HBM-8: registro, login y recuperacion de contrasena.
- HBM-9: perfil, preferencias y cierre de sesion.

No incluye implementacion backend ni las funcionalidades completas de habitos,
metas, recordatorios, tracking o progreso.

</domain>

<decisions>

## Implementation Decisions

### Delivery

- **D-01:** Cada ticket usa su propia rama y PR; los nombres exactos son `HBM-9/scaffold-mock-server`, `HBM-9/auth-screens` y `HBM-9/profile-logout`.
- **D-02:** Los commits son descriptivos y atomicos, y los PRs se apilan de forma secuencial HBM-7 -> HBM-8 -> HBM-9 hasta poder retargetearlos a `main`.

### Quality

- **D-03:** Cada ticket incluye pruebas unitarias y alcanza al menos 80% de cobertura sobre codigo nuevo o modificado, excluyendo generado y bootstrap sin logica.
- **D-04:** Los gates compartidos son `flutter analyze`, `flutter test --coverage`, `flutter build web --release` y smoke tests de Prism; un ticket termina solo despues de push y PR con evidencia.

### Architecture And Security

- **D-05:** La arquitectura es feature-first (`domain`, `data`, `presentation`) con Riverpod codegen, go_router y Dio; access/refresh tokens usan exclusivamente `flutter_secure_storage`, las credenciales invalidas son genericas y la suspension es explicita.
- **D-06:** `docs/openapi.yaml` es la fuente ejecutable de Prism, las zonas horarias usan IANA y no se implementan features completas posteriores a HBM-9.

### Existing Dirty Worktree

- **D-07:** El worktree combinado se respalda con un stash que incluye untracked; cada rama recupera solo sus rutas y el stash se conserva hasta auditar los tres PRs.

### the agent's Discretion

- Detalles internos de nombres de providers y composicion de widgets que no
  contradigan Jira, OpenAPI o las decisiones anteriores.

</decisions>

<canonical_refs>

## Canonical References

- Jira: HBM-7, HBM-8 y HBM-9 en `habitbuilder.atlassian.net`.
- `.planning/PROJECT.md`
- `.planning/REQUIREMENTS.md`
- `docs/openapi.yaml`
- Flutter 3.44.x / Dart 3.12+
- Repositorio backend local para contrastar rutas disponibles, sin modificarlo.

</canonical_refs>

<deferred>

## Deferred Ideas

- Implementacion o despliegue del backend.
- Envio real de correos de recuperacion.
- Persistencia backend real de consentimientos.
- Features completas de habitos, metas, recordatorios, tracking y progreso.
- Cambios visuales o funcionales no exigidos por HBM-7/8/9.

</deferred>
