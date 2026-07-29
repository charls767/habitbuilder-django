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
  forma se reflejará en `docs/openapi.yaml` y HBB-23 debe converger con ella.
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
  `DateTime.now()` local nunca decide la ocurrencia; se usa `TZDateTime`.
- **D-09:** El scheduler queda detrás de un puerto Dart. Dominio, controlador
  y tests no importan `flutter_local_notifications`.
- **D-10:** Android solicita permiso de notificaciones y exact alarm cuando
  corresponda, usa exact-allow-while-idle si está autorizado y fallback
  inexacto si no. Los receivers del plugin restauran tras reboot.
- **D-11:** iOS solicita permiso una sola vez y limita la planificación a las
  próximas 64 ocurrencias ordenadas. Web usa un puerto no-op explícito para
  conservar build y revisión visual.
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

### The Agent's Discretion

- Estructura exacta de DTOs, providers y componentes internos respetando
  feature-first, Riverpod, Dio, go_router y el sistema visual existente.
- Estrategia de IDs enteros para notificaciones y distribución de las 64
  ocurrencias de iOS, siempre determinista y cubierta por pruebas.

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
