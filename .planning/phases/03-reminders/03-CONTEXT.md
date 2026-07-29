# Phase 3: Reminders - Context

**Gathered:** 2026-07-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 3 cubre exactamente HBM-13 y HBM-14. Entrega administración de varios
recordatorios por hábito y su programación como notificaciones locales
interpretadas en la zona horaria del perfil.

Incluye mensaje, hora, días ISO 1..7, activación/desactivación, elegibilidad
según estado del hábito, permisos nativos y reprogramación. No incluye push
remoto, campañas, snooze, geofencing, tracking ni métricas de notificaciones.

</domain>

<decisions>
## Implementation Decisions

### Secuencia y contrato

- **D-01:** Ejecutar HBM-13 antes de HBM-14. El scheduler solo se integra
  después de estabilizar entidad, repositorio, controlador y UI.
- **D-02:** Mobile consumirá `mensaje`, `hora`, `diasSemana` y `activo`. La
  forma se reflejará primero en `docs/openapi.yaml` y en los slices frontend.
  Por orden explícito del usuario, HBB-23 converge después del frontend; no es
  una precondición para iniciar HBM-13/HBM-14, aunque el cierre contractual
  debe registrar la comparación y el handoff al orden HBB-23 → HBB-24 →
  HBB-27.
- **D-03:** Un hábito admite cero o varios recordatorios; cada recordatorio
  pertenece exactamente a un hábito.

### Experiencia CU-006

- **D-04:** La pantalla vive en `/habits/:habitId/reminders` y se abre desde la
  acción de recordatorios de cada hábito.
- **D-05:** Reutilizar la composición CU-006: encabezado con regreso, resumen
  verde, tarjetas con hora/mensaje/días, switch por entrada y acción
  `Añadir recordatorio`.
- **D-06:** Crear o reactivar se bloquea para hábitos pausados o completados.
  Editar o desactivar conserva la configuración y sigue disponible.
- **D-07:** El formulario exige mensaje no vacío, hora y al menos un día.
  Un error conserva todos los valores ingresados.

### Scheduling local

- **D-08:** La zona IANA de `PerfilUsuario.zonaHoraria` es canónica.
  `DateTime.now()` local nunca decide la ocurrencia; se usa `TZDateTime`. En un
  gap DST la hora avanza al primer instante local válido; en un overlap se
  agenda una sola ocurrencia usando el offset más temprano.
- **D-09:** El scheduler queda detrás de un puerto Dart. Dominio, controlador
  y tests no importan `flutter_local_notifications`.
- **D-10:** Android solicita permiso de notificaciones y exact alarm cuando
  corresponda, usa exact-allow-while-idle si está autorizado y fallback
  inexacto si no. Los receivers del plugin restauran tras reboot. El venue
  ejecutable es el AVD local `Pixel_6`, detectado en
  `C:\Users\USER\AppData\Local\Android\Sdk\emulator`; si no está iniciado, el
  executor debe arrancarlo y esperar `sys.boot_completed`.
- **D-11:** iOS solicita permiso una sola vez y limita la planificación a las
  próximas 64 ocurrencias ordenadas. Web usa un puerto no-op explícito para
  conservar build y revisión visual. La aceptación iOS se documenta para un
  runner macOS/CI externo; mientras no exista evidencia de ese runner, se
  registra `pending_external` y nunca se afirma una prueba nativa inexistente.
- **D-12:** Activar/editar programa; desactivar/eliminar cancela; al iniciar
  sesión se reconcilian recordatorios activos con el scheduler.

### Calidad y entrega

- **D-13:** Cada ticket incluye pruebas unitarias y widget y supera 80% de
  changed-code coverage contra la base real de su PR.
- **D-14:** HBM-13 usa `HBM-13/reminder-ui`; tras su merge HBM-14 parte de
  `main` en `HBM-14/local-notifications`.
- **D-15:** `stash@{0}` y
  `windows/flutter/generated_plugins.cmake` permanecen intactos y fuera de
  cualquier commit.
- **D-16:** La solicitud end-to-end del usuario autoriza la verificación no
  interactiva y la instalación exacta de `flutter_local_notifications`
  `22.2.0` y `timezone` `0.11.1`. Un helper automatizado y probado se ejecuta
  antes y después de mutar `pubspec.yaml`: valida nombre/versión exactos,
  endpoints y archive URLs HTTPS, el homepage oficial esperado de
  `flutter_local_notifications`, el repository oficial esperado de
  `timezone`, y demuestra que `checkedAtUtc` antecede tanto la mutación como
  el lockfile resultante. Cualquier discrepancia falla cerrado antes de
  continuar.

### The Agent's Discretion

- Estructura exacta de DTOs, providers y componentes internos respetando
  feature-first, Riverpod, Dio, go_router y el sistema visual existente.
- Estrategia de IDs enteros para notificaciones y distribución de las 64
  ocurrencias de iOS, siempre determinista y cubierta por pruebas.

### Resolved Inputs

- HBB-23 converge después de completar el frontend, por decisión explícita del
  usuario; los planes mobile no esperan aprobación backend previa.
- DST queda cerrado: gap → primer instante válido; overlap → una ocurrencia con
  el offset más temprano.
- Android usa el AVD local `Pixel_6`; iOS usa verificación externa macOS/CI
  documentada y permanece pendiente hasta que exista evidencia real.
- El gate de paquetes es automático y fail-closed por D-16; no requiere
  interacción humana.
- `workflow.use_worktrees=false`. 03-01..04 se ejecutan desde
  `C:\Users\USER\Desktop\DPPF\HabitBuilder\habitbuilder-mobile`; 03-05..08
  usan como cwd
  `C:\Users\USER\Desktop\DPPF\HabitBuilder\habitbuilder-mobile-hbm14`.
- `productTipSha` identifica exclusivamente el commit publicado por cada rama
  de producto. Después del merge se permiten commits locales no publicados de
  handoff/SUMMARY en el primary root; esos commits se registran aparte como
  `metadataTipSha` y nunca cambian el source commit del PR remoto.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Producto y contrato

- `.planning/ROADMAP.md` - alcance, secuencia y Definition of Done v3.0.
- `.planning/REQUIREMENTS.md` - REMINDER-01..05 y gates QUALITY/DELIVERY.
- `docs/openapi.yaml` - contrato HTTP consumido por Prism y mobile.
- `C:/Users/USER/Desktop/DPPF/HabitBuilder - Mockups.html` - frame
  `Configurar recordatorios - CU-006`.
- Jira HBM-3, HBM-13, HBM-14 y HBB-23.

### Código existente

- `lib/features/habits/domain/entities/habito.dart` - estado que gobierna
  elegibilidad.
- `lib/features/habits/presentation/providers/habit_providers.dart` - detalle
  e invalidación de hábito.
- `lib/features/profile/domain/entities/perfil_usuario.dart` - zona horaria y
  preferencias de notificaciones.
- `lib/core/router/app_router.dart` - rutas protegidas.
- `lib/core/widgets/app_chrome.dart` - ancho, navegación y piezas visuales.

### Bibliotecas

- `https://pub.dev/packages/flutter_local_notifications` - scheduling,
  permisos, exact alarm y receivers.
- `https://pub.dev/packages/timezone` - base IANA y `TZDateTime`.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `habitsListProvider` y `habitDetailProvider`: obtienen el hábito y su estado.
- `ProfileRepository`/providers: exponen `zonaHoraria` y preferencias.
- `AppContent`, `AppSectionLabel` y paleta `AppColors`: mantienen CU-006
  consistente con Phase 2.
- `runApiCall`: normaliza errores de Dio.

### Established Patterns

- Feature-first con capas `domain`, `data` y `presentation`.
- Repositorios abstractos y DTOs explícitos; las pantallas nunca consumen JSON.
- Controladores Riverpod invalidan providers de lista/detalle después de
  mutaciones.
- Pruebas widget reemplazan repositorios mediante overrides.

### Integration Points

- Ruta `/habits/:habitId/reminders` y acción desde `HabitsListScreen`.
- Endpoints `/habits/{habitId}/reminders` y `/reminders/{reminderId}`.
- Inicialización en composición de la app para HBM-14.
- AndroidManifest/iOS AppDelegate y permisos nativos para el plugin.

</code_context>

<specifics>
## Specific Ideas

- Replicar el frame CU-006: resumen verde, hora prominente, mensaje, chips de
  días, switches y borde punteado para añadir.
- Mantener la UI útil a 320 px y en web/desktop sin simular soporte nativo.

</specifics>

<deferred>
## Deferred Ideas

- Push remoto y selección de un proveedor concreto para `NotificationSender`.
- Snooze, geofencing, campañas y estadísticas.
- Tracking, progreso, rachas y reportes.

</deferred>

---

*Phase: 03-reminders*
*Context gathered: 2026-07-28*
