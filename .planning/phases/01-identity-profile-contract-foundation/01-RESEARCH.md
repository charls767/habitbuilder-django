# Phase 1 Research

## Repository Baseline

- Mobile: `main` en `b967376`, siguiendo `origin/main`.
- Backend: `b1752f6`; actualmente solo expone el health check necesario para
  verificar disponibilidad basica.
- El worktree mobile esta sucio y mezcla infraestructura, auth, perfil y
  codigo de features posteriores.
- La implementacion combinada ya demostro que Flutter 3.44.8, Dart 3.12.2,
  analyze, 12 tests, build web y Prism pueden funcionar juntos.

La evidencia previa reduce incertidumbre tecnica, pero no satisface la
entrega: faltan aislamiento por ticket, cobertura por diff, commits atomicos y
PRs.

## Recommended Extraction Strategy

La opcion de menor riesgo es tratar el worktree actual como una fuente temporal
de cambios:

1. Crear un stash nombrado con `git stash push -u` y guardar su identificador.
2. Volver a `main` limpio y crear `HBM-9/scaffold-mock-server`.
3. Restaurar rutas de infraestructura, revisar cada diff y excluir codigo de
   negocio posterior a HBM-9.
4. Crear auth sobre la revision terminada de HBM-7.
5. Crear perfil sobre la revision terminada de HBM-8.
6. Mantener el stash hasta comparar su listado completo contra los tres PRs.

No se debe aplicar el stash completo sobre cada rama porque volveria a mezclar
los tickets.

## Pull Request Topology

- PR HBM-7: `HBM-9/scaffold-mock-server` -> `main`.
- PR HBM-8: `HBM-9/auth-screens` -> rama HBM-7 mientras el primer PR esta
  abierto; despues -> `main`.
- PR HBM-9: `HBM-9/profile-logout` -> rama HBM-8 mientras el segundo PR esta
  abierto; despues -> `main`.

Esta topologia mantiene diffs revisables sin duplicar infraestructura. Si
Bitbucket no permite retarget, se actualiza cada rama con la base integrada y
se crea el PR contra `main` solo cuando su dependencia ya haya sido mergeada.

## Coverage Strategy

`flutter test --coverage` genera `coverage/lcov.info`. El gate por ticket debe:

- identificar archivos Dart agregados o modificados contra la base del PR;
- ignorar `*.g.dart`, `*.freezed.dart` y archivos sin lineas ejecutables;
- sumar `LF` y `LH` de esos archivos;
- fallar cuando `LH / LF < 0.80`;
- publicar el porcentaje y la lista de archivos incluidos en el PR.

El total global se informa como diagnostico, pero el umbral obligatorio aplica
al codigo del ticket para impedir que cobertura heredada o archivos ajenos
oculten huecos.

## Ticket Boundaries

### HBM-7

Incluye dependencias, configuracion, core de red y almacenamiento, router
minimo, estructura feature-first, contrato OpenAPI, Prism, bootstrap y pruebas
unitarias del core. No incluye pantallas funcionales de auth o perfil.

### HBM-8

Incluye modelos, repositorio, datasource, validadores, providers, rutas y
pantallas de registro, login, solicitud y confirmacion de recuperacion. Incluye
manejo de errores por campo, credenciales genericas y suspension.

### HBM-9

Incluye lectura/edicion de perfil, objetivo, zona IANA, accesibilidad,
notificaciones, aplicacion global de tamano/contraste y logout confirmado.

## Risks And Mitigations

| Risk | Mitigation |
| --- | --- |
| Perder cambios del worktree | Stash con untracked, identificador registrado y comparacion final |
| Mezclar features futuras | Restauracion por rutas y revision de `git diff --name-status` antes de cada commit |
| Prefijo de rama inconsistente con ticket | Mantener literalmente el prefijo `HBM-9/` solicitado y nombrar ticket real en commits/PR |
| Codigo generado altera el diff | Ejecutar codegen de forma reproducible y excluir generado del calculo de cobertura |
| Backend incompleto bloquea frontend | Validar contra Prism/OpenAPI y documentar dependencia HBB-7 |
| Cobertura global enganosa | Gate calculado sobre archivos cambiados contra la base del PR |
