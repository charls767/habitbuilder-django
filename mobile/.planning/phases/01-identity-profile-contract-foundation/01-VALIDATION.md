# Phase 1 Validation Strategy

## Fast Feedback

Despues de cada tarea de implementacion:

1. Ejecutar `dart format --output=none --set-exit-if-changed` sobre las rutas
   tocadas.
2. Ejecutar las pruebas focalizadas del ticket.
3. Ejecutar `flutter analyze`.
4. Revisar `git diff --check` y `git diff --name-status` contra la base del PR.

## Ticket Gates

| Plan | Focused tests | Additional checks |
| --- | --- | --- |
| 01-01 | `flutter test test/core` | Prism carga OpenAPI, bootstrap y health/smoke |
| 01-02 | `flutter test test/features/auth` | Flujos y errores de auth contra Prism |
| 01-03 | `flutter test test/features/profile test/app_test.dart` | Preferencias globales y logout |

Antes de abrir cada PR:

```text
flutter analyze
flutter test --coverage
flutter build web --release
npm run mock:smoke
```

El comando concreto de smoke puede ajustarse al script final de `package.json`,
pero debe ejecutar `scripts/mock-smoke.mjs` contra Prism.

## Changed-Code Coverage Gate

Para cada rama:

1. Determinar la base de comparacion del PR con `git merge-base`.
2. Obtener archivos Dart agregados/modificados con `git diff --diff-filter=AM`.
3. Parsear `coverage/lcov.info`.
4. Excluir archivos generados y archivos sin lineas instrumentables.
5. Calcular `sum(LH) / sum(LF)`.
6. Fallar por debajo de `80.00%`.

El script de cobertura debe tener pruebas unitarias o fixtures que demuestren:

- calculo correcto con varios archivos;
- exclusion de codigo generado;
- fallo bajo 80%;
- exito en 80% exacto o superior.

## Final Integrated Gate

Cuando los tres planes terminen, reconstruir una revision integrada y repetir:

- `flutter pub get`
- code generation sin diferencias inesperadas
- `flutter analyze`
- suite completa con cobertura
- build web release
- carga de OpenAPI en Prism
- smoke completo de auth y perfil
- inspeccion de que tokens y secretos no aparecen en logs ni almacenamiento no seguro

## Evidence

Cada `SUMMARY.md` debe registrar comandos, resultados, porcentaje de cobertura,
commits y URL del PR. `.planning/VERIFICATION.md` consolida la evidencia de la
fase.
