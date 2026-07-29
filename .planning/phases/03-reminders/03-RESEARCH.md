# Phase 3: Reminders - Research

**Researched:** 2026-07-28  
**Domain:** Flutter reminder CRUD, timezone-aware local notification scheduling, and Android/iOS permission lifecycle  
**Confidence:** HIGH for repository architecture and package APIs; MEDIUM for physical-device behavior because no Android/iOS device was available

<user_constraints>
## User Constraints (from CONTEXT.md)

All content in this section is copied verbatim from `03-CONTEXT.md`. [VERIFIED: `.planning/phases/03-reminders/03-CONTEXT.md`]

### Locked Decisions

#### Phase Boundary

Phase 3 cubre exactamente HBM-13 y HBM-14. Entrega administración de varios
recordatorios por hábito y su programación como notificaciones locales
interpretadas en la zona horaria del perfil.

Incluye mensaje, hora, días ISO 1..7, activación/desactivación, elegibilidad
según estado del hábito, permisos nativos y reprogramación. No incluye push
remoto, campañas, snooze, geofencing, tracking ni métricas de notificaciones.

#### Secuencia y contrato

- **D-01:** Ejecutar HBM-13 antes de HBM-14. El scheduler solo se integra
  después de estabilizar entidad, repositorio, controlador y UI.
- **D-02:** Mobile consumirá `mensaje`, `hora`, `diasSemana` y `activo`. La
  forma se reflejará primero en `docs/openapi.yaml` y en los slices frontend.
  Por orden explícito del usuario, HBB-23 converge después del frontend; no es
  una precondición para iniciar HBM-13/HBM-14.
- **D-03:** Un hábito admite cero o varios recordatorios; cada recordatorio
  pertenece exactamente a un hábito.

#### Experiencia CU-006

- **D-04:** La pantalla vive en `/habits/:habitId/reminders` y se abre desde la
  acción de recordatorios de cada hábito.
- **D-05:** Reutilizar la composición CU-006: encabezado con regreso, resumen
  verde, tarjetas con hora/mensaje/días, switch por entrada y acción
  `Añadir recordatorio`.
- **D-06:** Crear o reactivar se bloquea para hábitos pausados o completados.
  Editar o desactivar conserva la configuración y sigue disponible.
- **D-07:** El formulario exige mensaje no vacío, hora y al menos un día.
  Un error conserva todos los valores ingresados.

#### Scheduling local

- **D-08:** La zona IANA de `PerfilUsuario.zonaHoraria` es canónica.
  `DateTime.now()` local nunca decide la ocurrencia; se usa `TZDateTime`. En un
  gap DST se avanza al primer instante local válido; en overlap se agenda una
  sola ocurrencia con el offset más temprano.
- **D-09:** El scheduler queda detrás de un puerto Dart. Dominio, controlador
  y tests no importan `flutter_local_notifications`.
- **D-10:** Android solicita permiso de notificaciones y exact alarm cuando
  corresponda, usa exact-allow-while-idle si está autorizado y fallback
  inexacto si no. Los receivers del plugin restauran tras reboot. El venue
  local es el AVD `Pixel_6`.
- **D-11:** iOS solicita permiso una sola vez y limita la planificación a las
  próximas 64 ocurrencias ordenadas. Web usa un puerto no-op explícito para
  conservar build y revisión visual. iOS se verifica externamente en macOS/CI
  y no se marca como probado sin evidencia.
- **D-12:** Activar/editar programa; desactivar/eliminar cancela; al iniciar
  sesión se reconcilian recordatorios activos con el scheduler.

#### Calidad y entrega

- **D-13:** Cada ticket incluye pruebas unitarias y widget y supera 80% de
  changed-code coverage contra la base real de su PR.
- **D-14:** HBM-13 usa `HBM-13/reminder-ui`; tras su merge HBM-14 parte de
  `main` en `HBM-14/local-notifications`.
- **D-15:** `stash@{0}` y
  `windows/flutter/generated_plugins.cmake` permanecen intactos y fuera de
  cualquier commit.
- **D-16:** La solicitud end-to-end autoriza verificación no interactiva e
  instalación exacta de `flutter_local_notifications` 22.2.0 y `timezone`
  0.11.1; antes de `pub get` se registran package, version,
  source/repository, homepage y UTC desde pub.dev oficial, con fallo cerrado.

### The Agent's Discretion

- Estructura exacta de DTOs, providers y componentes internos respetando
  feature-first, Riverpod, Dio, go_router y el sistema visual existente.
- Estrategia de IDs enteros para notificaciones y distribución de las 64
  ocurrencias de iOS, siempre determinista y cubierta por pruebas.

### Deferred Ideas (OUT OF SCOPE)

- Push remoto y selección de un proveedor concreto para `NotificationSender`.
- Snooze, geofencing, campañas y estadísticas.
- Tracking, progreso, rachas y reportes.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|---|---|---|
| REMINDER-01 | Listar, crear y editar varios recordatorios con mensaje, hora 24 h y al menos un día. | HBM-13 contract, entity/value object, repository, controller, form, and widget-test design below. [VERIFIED: `.planning/REQUIREMENTS.md`] |
| REMINDER-02 | Calcular ocurrencias con `TZDateTime` en la zona IANA del perfil. | HBM-14 occurrence planner receives `tz.Location` and injected `TZDateTime now`; native local time is never an input. [VERIFIED: `03-CONTEXT.md` D-08; CITED: https://pub.dev/packages/timezone] |
| REMINDER-03 | Bloquear creación/reactivación for paused/completed habits and explain why. | HBM-13 enforces this in both UI and controller; HBM-14 excludes ineligible habits during reconciliation. [VERIFIED: `03-CONTEXT.md` D-06] |
| REMINDER-04 | Desactivar/reactivar without losing configured fields. | HBM-13 sends a full reminder draft on toggle and preserves `mensaje`, `hora`, and `diasSemana`. [VERIFIED: `.planning/REQUIREMENTS.md`; VERIFIED: `docs/openapi.yaml` current PATCH shape] |
| REMINDER-05 | Permissions, exact fallback, reboot restoration, and iOS 64 limit. | HBM-14 platform adapter and reconciliation strategy below map directly to the package APIs and manifest requirements. [CITED: https://pub.dev/packages/flutter_local_notifications] |
| QUALITY-13 | HBM-13 unit/data/widget tests. | Validation map specifies domain, DTO, datasource, repository, controller, router, and widget tests. [VERIFIED: `.planning/REQUIREMENTS.md`] |
| QUALITY-14 | Deterministic occurrence and scheduling-port tests without native plugin dependency. | Pure planner plus fake `ReminderScheduler`/native gateway; test files never import `flutter_local_notifications`. [VERIFIED: `03-CONTEXT.md` D-09] |
| QUALITY-15 | At least 80.00% changed-code coverage per real PR base. | Exact per-ticket base and coverage commands are specified below. [VERIFIED: `.planning/ROADMAP.md`; VERIFIED: `scripts/check-changed-coverage.mjs`] |
| QUALITY-16 | `flutter analyze` and `flutter test --coverage` pass. | Existing Flutter test infrastructure and gate commands are mapped below. [VERIFIED: `.planning/ROADMAP.md`] |
| QUALITY-17 | Web release build keeps a functional no-op scheduling fallback. | Conditional scheduler factory returns an explicit no-op on web; release web build remains a phase gate. [VERIFIED: `03-CONTEXT.md` D-11] |
| QUALITY-18 | Prism loads reminder contract and smoke covers list/create/edit/deactivate. | HBM-13 starts with OpenAPI correction and extends `scripts/mock-smoke.mjs`. [VERIFIED: `.planning/REQUIREMENTS.md`; VERIFIED: codebase read] |
| DELIVERY-07 | HBM-13 is delivered from `HBM-13/reminder-ui`. | Exact branch/order gate below. [VERIFIED: `03-CONTEXT.md` D-14] |
| DELIVERY-08 | HBM-14 starts from `main` containing HBM-13 and uses `HBM-14/local-notifications`. | Exact branch/order gate below. [VERIFIED: `03-CONTEXT.md` D-14] |
</phase_requirements>

## Summary

Phase 3 remains two sequential ticket branches/PRs but is executed through eight bounded plans: four HBM-13 plans followed by four HBM-14 plans. HBM-13 first corrects the shared HTTP contract and tooling, implements domain/data, delivers CU-006, then publishes exactly `productTipSha`, merges and records local post-merge metadata. HBM-14 runs under the manually selected isolated root because `workflow.use_worktrees=false`, then adds the package gate/pure planner, native adapters, reconciliation and its own exact-tip delivery. [VERIFIED: revised planning decisions D-01/D-09/D-14; VERIFIED: second checker correction]

The immediate contract defect is concrete: `docs/openapi.yaml` already exposes list/create/PATCH/delete reminder operations, but both `Recordatorio` and `RecordatorioRequest` omit the locked `mensaje` field and lack the required non-empty/unique/format constraints. `scripts/mock-smoke.mjs` currently stops after habits/goals and has no reminder coverage. HBM-13 must close those gaps before its Dart implementation is considered stable. HBB-23 convergence follows frontend by explicit user order; mobile records the final contract handoff instead of blocking HBM-13 on prior backend acceptance. [VERIFIED: `docs/openapi.yaml`; VERIFIED: `scripts/mock-smoke.mjs`; VERIFIED: revised D-02]

For HBM-14, use `flutter_local_notifications` 22.2.0 and `timezone` 0.11.1 exactly. D-16 requires a tested helper before and after `pubspec.yaml` mutation. It checks exact package/version, HTTPS API/archive URLs, `flutter_local_notifications.homepage == https://github.com/MaikuB/flutter_local_notifications/tree/master/flutter_local_notifications` with null repository, and `timezone.repository == https://github.com/dart-lang/labs/tree/main/pkgs/timezone` with null homepage. Its evidence proves `checkedAtUtc` predates mutation and the resulting lockfile. The local SDK satisfies their minimums, Flutter 3.44.8 supplies Android compile/target SDK 36 and min SDK 24, the project uses AGP 9.0.1/Java 17 compile settings, and iOS already targets 13.0. [VERIFIED: D-16; VERIFIED: official version APIs on 2026-07-29]

**Primary recommendation:** Complete and merge HBM-13 as the contract-and-UI source of truth, then build HBM-14 around full desired-state reconciliation: active reminders of active habits + profile notification preferences + profile IANA zone → deterministic platform schedule. [VERIFIED: `03-CONTEXT.md` D-01/D-08/D-12]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|---|---|---|---|
| Reminder persistence and ownership | API / Backend | Mobile Client | Mobile calls the authenticated reminder endpoints; authorization/ownership must remain server-enforced. [VERIFIED: `docs/openapi.yaml`; CITED: https://github.com/OWASP/ASVS/blob/master/4.0/en/0x12-V4-Access-Control.md] |
| Contract validation and DTO mapping | Mobile Client data layer | API / Backend | Dio datasources and explicit DTOs are the established boundary; Prism validates the same OpenAPI source. [VERIFIED: habits/profile codebase read] |
| Create/reactivate eligibility | Mobile Client controller/UI | API / Backend | Client must explain and block invalid actions, while backend remains authoritative and may return `409`. [VERIFIED: `03-CONTEXT.md` D-06; VERIFIED: `docs/openapi.yaml`] |
| Reminder screen and form state | Mobile Client presentation | — | CU-006, 320 px behavior, validation, and error-state preservation are client responsibilities. [VERIFIED: `03-CONTEXT.md` D-04..D-07] |
| IANA wall-clock interpretation | Mobile Client domain/application | Device OS | The profile zone is canonical and is converted with `timezone`; the device-local zone is not consulted. [VERIFIED: `03-CONTEXT.md` D-08; CITED: https://pub.dev/packages/timezone] |
| Desired-schedule reconciliation | Mobile Client application coordinator | API / Backend | The coordinator combines habits, reminders, profile preferences, and zone into the desired schedule. [VERIFIED: `03-CONTEXT.md` D-12; VERIFIED: available API endpoints] |
| Notification permission and delivery | Device OS via native adapter | Mobile Client | Android/iOS own permissions and alarm/notification delivery; the adapter translates the Dart port to plugin APIs. [CITED: https://pub.dev/packages/flutter_local_notifications] |
| Reboot restoration | Android OS/plugin receivers | Mobile Client startup reconciliation | Receivers restore plugin-managed alarms; startup reconciliation corrects stale backend/profile state. [CITED: https://pub.dev/packages/flutter_local_notifications#androidmanifestxml-setup; VERIFIED: `03-CONTEXT.md` D-10/D-12] |
| iOS pending-64 allocation | Mobile Client occurrence planner | iOS notification center | Client schedules exactly the globally earliest 64 one-shot occurrences; iOS enforces the pending-request ceiling. [VERIFIED: `03-CONTEXT.md` D-11; CITED: https://pub.dev/packages/flutter_local_notifications#ios-pending-notifications-limit] |
| Web scheduling behavior | Mobile Client no-op port | Browser | The locked behavior is visual/configuration support without native scheduling, even though plugin 22.x now has a web implementation. [VERIFIED: `03-CONTEXT.md` D-11; CITED: https://pub.dev/packages/flutter_local_notifications/changelog] |

## Project Constraints

- No `AGENTS.md`, `.codex/skills/`, or `.agents/skills/` exists in the requested project root, so there are no additional project-local directives beyond planning artifacts and established code patterns. [VERIFIED: filesystem scan]
- The current branch is `HBM-13/reminder-ui`. [VERIFIED: `git branch --show-current` on 2026-07-28]
- `windows/flutter/generated_plugins.cmake` is already reported modified by Git and is explicitly protected by D-15; no command in either ticket may stage, normalize, restore, or overwrite it in this worktree. [VERIFIED: `git status --short`; VERIFIED: `03-CONTEXT.md` D-15]
- `stash@{0}` is reference state only and must not be applied, popped, dropped, or rewritten. [VERIFIED: `03-CONTEXT.md` D-15]

## Standard Stack

### Existing Core

| Library | Version | Purpose | Why Standard Here |
|---|---|---|---|
| Flutter | 3.44.8 local; project range `>=3.44.0 <3.45.0` | UI, widgets, platform builds | Existing application/runtime and test framework. [VERIFIED: `pubspec.yaml`; VERIFIED: `C:\Users\USER\flutter\bin\flutter.bat --version`] |
| Dart | 3.12.2 local; project range `>=3.12.0 <4.0.0` | Domain/data/application code | Existing project language and package solver constraint. [VERIFIED: `pubspec.yaml`; VERIFIED: local SDK] |
| `flutter_riverpod` | 3.3.2 | Providers and controller state | Existing generated-provider/controller pattern. [VERIFIED: `pubspec.lock`; VERIFIED: habits/profile providers] |
| `riverpod_annotation` / `riverpod_generator` | 4.0.3 / 4.0.4 | Provider declarations and generated code | Existing project convention; continue rather than introduce manual provider style. [VERIFIED: `pubspec.yaml`] |
| Dio | 5.11.0 | Reminder HTTP calls | Existing datasource pattern and `runApiCall` error normalization. [VERIFIED: `pubspec.lock`; VERIFIED: habit/profile datasources] |
| go_router | 17.3.0 | Protected `/habits/:habitId/reminders` route | Existing centralized route/provider pattern. [VERIFIED: `pubspec.lock`; VERIFIED: `lib/core/router/app_router.dart`] |
| flutter_test | Flutter SDK 3.44.8 | Unit and widget tests | Existing test infrastructure and phase quality gate. [VERIFIED: `pubspec.yaml`; VERIFIED: test tree] |
| mocktail | 1.0.5 | Repository/gateway fakes and interaction verification | Existing data/repository test convention. [VERIFIED: `pubspec.yaml`; VERIFIED: tests] |

### HBM-14 Additions

| Library | Version / Publish Date | Purpose | Why Standard |
|---|---|---|---|
| `flutter_local_notifications` **[AUTHORIZED D-16]** | 22.2.0, published 2026-07-25 | Android/iOS initialization, permissions, zoned scheduling, pending requests, cancellation, reboot persistence | Exact install is authorized only after the automated official-pub.dev evidence record passes. [VERIFIED: D-16; VERIFIED: pub.dev registry; CITED: https://pub.dev/documentation/flutter_local_notifications/latest/flutter_local_notifications/] |
| `timezone` **[AUTHORIZED D-16]** | 0.11.1, published 2026-06-29 | IANA database, `Location`, and `TZDateTime` | Exact install is authorized only after the same fail-closed official metadata record passes. [VERIFIED: D-16; VERIFIED: pub.dev registry; CITED: https://pub.dev/packages/timezone/changelog] |

Both selected versions require Dart `^3.10.0`; `flutter_local_notifications` requires Flutter `>=3.38.1`, Android min API 24/compile SDK 36, and iOS 13. The local project resolves Flutter 3.44.8/Dart 3.12.2, Flutter defaults to Android min/compile/target 24/36/36, and the Xcode project targets iOS 13.0. [VERIFIED: pub.dev API; VERIFIED: local Flutter source and `ios/Runner.xcodeproj/project.pbxproj`; CITED: https://pub.dev/packages/flutter_local_notifications/changelog]

### Alternatives Considered

| Instead of | Could Use | Disposition |
|---|---|---|
| Explicit web no-op | Plugin 22.2.0 web implementation | Rejected because D-11 explicitly requires a no-op port for web. [VERIFIED: `03-CONTEXT.md` D-11] |
| Profile IANA zone | Device-local zone or fixed UTC offset | Rejected because D-08 makes `PerfilUsuario.zonaHoraria` canonical and `timezone` does not discover the device zone. [VERIFIED: `03-CONTEXT.md` D-08; CITED: https://pub.dev/packages/timezone] |
| `zonedSchedule` | Deprecated `schedule`, `showDailyAtTime`, or `showWeeklyAtDayAndTime` | Rejected because official package guidance replaced these due to timezone/DST problems. [CITED: https://pub.dev/packages/flutter_local_notifications#scheduling-a-notification] |
| `USE_EXACT_ALARM` | `SCHEDULE_EXACT_ALARM` with inexact fallback | Rejected for this app: Android documents `USE_EXACT_ALARM` for qualifying calendar/alarm-clock apps and publication is policy-gated. Use user-granted `SCHEDULE_EXACT_ALARM` and degrade gracefully. [CITED: https://developer.android.com/about/versions/14/changes/schedule-exact-alarms] |

### Installation

Do not add either package in HBM-13. After HBM-13 `productTipSha` is proven merged into updated `origin/main`, manually create/select the HBM-14 worktree at the locked absolute root. Before mutation, run the D-16 helper in `pre` mode; after exact pins and `pub get`, run it in `post` mode to validate hashes, ordering and lockfile. No package checkpoint is required. [VERIFIED: `03-CONTEXT.md` D-01/D-14/D-15/D-16]

```bash
flutter pub add flutter_local_notifications:22.2.0 timezone:0.11.1
```

The package page recommends declaring `timezone` directly even though it is also transitive through `flutter_local_notifications`, because application code imports it. [CITED: https://pub.dev/packages/flutter_local_notifications#scheduling-a-notification]

## Package Legitimacy Audit

The mandatory `slopcheck` run could not produce a valid Dart-ecosystem verdict: slopcheck 0.6.1 scanned npm, falsely marked `flutter_local_notifications` as absent, matched an unrelated npm package named `timezone`, and then attempted `npm install`. Those npm results are discarded under the cross-ecosystem verification rule. D-16 resolves the fallback: exact versions are user-authorized after a non-interactive fail-closed query of the official pub.dev API records package, version, source/repository, homepage and UTC. [VERIFIED: D-16; VERIFIED: slopcheck command output; VERIFIED: pub.dev API; CITED: https://pub.dev/packages/flutter_local_notifications; CITED: https://pub.dev/packages/timezone]

| Package | Registry | Age / Displayed Downloads | Source Repo | slopcheck | Disposition |
|---|---|---|---|---|---|
| `flutter_local_notifications` [AUTHORIZED D-16] | pub.dev | First published 2018-03-25; pub.dev displayed 2.34M downloads | `github.com/MaikuB/flutter_local_notifications` | N/A — npm-only false `[SLOP]` discarded as wrong ecosystem | Automated official pub.dev record must pass before exact install. |
| `timezone` [AUTHORIZED D-16] | pub.dev | First published 2014-10-15; pub.dev displayed 2.8M downloads | `github.com/dart-lang/labs/tree/main/pkgs/timezone` | N/A — npm result refers to a different ecosystem | Automated official pub.dev record must pass before exact install. |

**Packages removed due to a valid slopcheck `[SLOP]` verdict:** none; no Dart/pub.dev verdict was available. [VERIFIED: slopcheck output]

**Packages authorized for non-interactive official verification:** `flutter_local_notifications` 22.2.0 and `timezone` 0.11.1 per D-16. The executor fails closed before `pub get` if official metadata is incomplete or mismatched.

Node-style `postinstall` scripts do not apply to these pub packages; their published pubspec metadata contains no npm lifecycle script field. [VERIFIED: pub.dev API]

## Package and Platform Configuration

### Android

`android/app/build.gradle.kts` already uses Java 17, AGP 9.0.1, and Flutter compile SDK 36, but core-library desugaring and multidex are not enabled. Add the package-documented settings below in HBM-14; do not downgrade AGP. [VERIFIED: Android Gradle files/local Flutter source; CITED: https://pub.dev/packages/flutter_local_notifications#gradle-setup]

```kotlin
android {
    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        multiDexEnabled = true
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

Add only the permissions needed by this phase. `POST_NOTIFICATIONS` and `VIBRATE` are declared by the plugin; scheduling/reboot and user-granted exact alarms require the following app declarations. [CITED: https://pub.dev/packages/flutter_local_notifications#androidmanifestxml-setup]

```xml
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />

<application ...>
    <receiver
        android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"
        android:exported="false" />
    <receiver
        android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver"
        android:exported="false">
        <intent-filter>
            <action android:name="android.intent.action.BOOT_COMPLETED" />
            <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
            <action android:name="android.intent.action.QUICKBOOT_POWERON" />
            <action android:name="com.htc.intent.action.QUICKBOOT_POWERON" />
        </intent-filter>
    </receiver>
</application>
```

Create a dedicated monochrome drawable notification icon (for example `android/app/src/main/res/drawable/ic_notification.xml`) and initialize the plugin with its resource name. Add an Android resource keep file for the icon because the official package warns that R8 can otherwise discard notification resources in release builds. Do not use `@mipmap/ic_launcher` as the notification icon. [CITED: https://pub.dev/packages/flutter_local_notifications#custom-notification-icons-and-sounds]

Permission flow must be: `requestNotificationsPermission()` when an eligible reminder is first activated; if notifications are allowed, call `canScheduleExactNotifications()`; when false, offer/request `requestExactAlarmsPermission()`, then re-check on resume; choose `AndroidScheduleMode.exactAllowWhileIdle` only when true and `AndroidScheduleMode.inexactAllowWhileIdle` otherwise. A denied notification permission means configuration is saved but no local schedule is created, with a visible explanation. [VERIFIED: `03-CONTEXT.md` D-10; CITED: https://pub.dev/documentation/flutter_local_notifications/latest/flutter_local_notifications/AndroidFlutterLocalNotificationsPlugin-class.html; CITED: https://developer.android.com/about/versions/14/changes/schedule-exact-alarms]

### iOS

The project already targets iOS 13.0 and uses Flutter's generated Swift package integration, matching plugin 22.2.0's minimum and current SPM support. No CocoaPods migration is required. [VERIFIED: Xcode project read; CITED: https://pub.dev/packages/flutter_local_notifications/changelog]

Add `import UserNotifications` and set the notification center delegate in `application(_:didFinishLaunchingWithOptions:)` before calling `super`:

```swift
import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate =
      self as? UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

This delegate setup is required by the official iOS setup guidance and preserves the existing implicit-engine registration method. [CITED: https://pub.dev/packages/flutter_local_notifications#ios-setup; VERIFIED: `ios/Runner/AppDelegate.swift`]

Initialize iOS with `requestAlertPermission`, `requestBadgePermission`, and `requestSoundPermission` all false. Request alert/sound permission explicitly on the first eligible activation through `IOSFlutterLocalNotificationsPlugin.requestPermissions(alert: true, sound: true, badge: false)`, guard duplicate attempts in the adapter process, and use `checkPermissions()` before scheduling. The phase does not require badges. [VERIFIED: `03-CONTEXT.md` D-11; CITED: https://pub.dev/packages/flutter_local_notifications#requesting-notification-permissions; CITED: https://pub.dev/documentation/flutter_local_notifications/latest/flutter_local_notifications/IOSFlutterLocalNotificationsPlugin-class.html]

Cancel all pending requests whose payload starts with the HabitBuilder reminder namespace, then schedule exactly the earliest 64 one-shot occurrences in ascending order. Do not use a per-reminder quota and do not call `matchDateTimeComponents` on iOS; the finite queue is replenished on app/session reconciliation. [VERIFIED: `03-CONTEXT.md` D-11/D-12 and Agent's Discretion; CITED: https://pub.dev/packages/flutter_local_notifications#ios-pending-notifications-limit]

### Web and Desktop

Use a conditional scheduler factory whose web branch returns `NoOpReminderScheduler`. Do not request browser permission and do not call the plugin's web implementation; users can still review/edit reminder configuration. Native desktop platforms also return no-op because Phase 3 only commits Android/iOS scheduling behavior. [VERIFIED: `03-CONTEXT.md` D-11 and Phase Boundary]

## Architecture Patterns

### System Architecture Diagram

```text
Authenticated user
      |
      +--> Habit card "Recordatorios" --> protected route
      |                                  /habits/:habitId/reminders
      |                                             |
      |                           habitDetailProvider + remindersListProvider
      |                                             |
      |                               CU-006 list/form/switch
      |                                             |
      |                             ReminderController (eligibility)
      |                                             |
      |                          ReminderRepository port (Dart)
      |                                             |
      |                    Dio datasource --> OpenAPI/Prism --> Backend
      |
      +--> login/app start, reminder mutation, habit lifecycle,
           profile timezone/preferences change
                                |
                     ReminderReconciliationCoordinator
                                |
             +------------------+-------------------+
             |                  |                   |
       habits/reminders     profile zone        notification prefs
             |                  |                   |
             +---------- desired eligible set ------+
                                |
              OccurrencePlanner (TZDateTime, injected now)
                                |
                      ReminderScheduler port
                  +-------------+-------------+
                  |             |             |
             Android adapter  iOS adapter   Web/desktop no-op
                  |             |
          exact/inexact      earliest 64
          weekly rules       one-shot events
                  |             |
            Android AlarmManager / iOS UNUserNotificationCenter
```

This flow assigns persistence to the API, eligibility and desired-state calculation to the Flutter client, and permission/delivery to the device OS. [VERIFIED: codebase architecture; VERIFIED: `03-CONTEXT.md` D-08..D-12]

### Recommended Project Structure

```text
lib/features/reminders/
├── domain/
│   ├── entities/
│   │   ├── recordatorio.dart
│   │   └── reminder_time.dart
│   ├── repositories/
│   │   └── reminder_repository.dart
│   └── services/
│       ├── reminder_scheduler.dart
│       ├── reminder_occurrence_planner.dart
│       └── managed_notification.dart
├── data/
│   ├── datasources/
│   │   └── reminder_remote_data_source.dart
│   ├── models/
│   │   └── recordatorio_dto.dart
│   └── repositories/
│       └── reminder_repository_impl.dart
├── infrastructure/
│   └── notifications/
│       ├── reminder_scheduler_factory.dart
│       ├── reminder_scheduler_factory_native.dart
│       ├── reminder_scheduler_factory_noop.dart
│       ├── flutter_notification_gateway.dart
│       └── noop_reminder_scheduler.dart
└── presentation/
    ├── providers/
    │   └── reminder_providers.dart
    ├── screens/
    │   └── reminders_screen.dart
    └── widgets/
        ├── reminder_card.dart
        └── reminder_form_sheet.dart

test/features/reminders/
├── domain/
├── data/
├── application/
├── presentation/
└── support/
```

Keep the package feature-first and preserve the repository/DTO/provider separation used by habits and profile. The plugin import belongs only under `infrastructure/notifications`; domain, controllers, and tests depend on the Dart port. [VERIFIED: established codebase pattern; VERIFIED: `03-CONTEXT.md` D-09]

### Pattern 1: Immutable API Shape and Wall-Clock Value

Model API time as validated hour/minute components, not as a local `DateTime`. `Recordatorio` should contain `id`, `habitoId`, `mensaje`, `ReminderTime`, an immutable sorted unique list/set of ISO weekdays 1..7, and `activo`; `ReminderDraft` carries the four writable fields. [VERIFIED: `03-CONTEXT.md` D-02/D-03/D-07/D-08]

The DTO alone converts `ReminderTime` to/from strict `HH:mm`, and it must reject malformed data rather than silently defaulting. This follows the existing explicit DTO mapping pattern. [VERIFIED: habits/profile DTO codebase read]

### Pattern 2: Controller-Level Eligibility

The reminder controller must enforce the same predicate used by the UI:

```text
mayCreate = habit.estado == activo
mayReactivate = habit.estado == activo
mayEdit = true
mayDeactivate = true
mayDelete = true
```

If create/reactivate is disallowed, return a typed failure without calling the repository. Editing an existing reminder keeps its current `activo` value, so paused/completed habits can preserve configuration; HBM-14 still excludes those reminders from the desired device schedule. [VERIFIED: `03-CONTEXT.md` D-06]

After successful create/update/delete/toggle, invalidate `remindersListProvider(habitId)` and the single reminder provider if one is introduced. Do not invalidate unrelated habit lists for reminder-only mutations. [VERIFIED: existing Riverpod mutation pattern; VERIFIED: feature boundary]

### Pattern 3: Full Desired-State Reconciliation

Treat the device schedule as a projection, never as the source of truth. On reconciliation:

1. Load `PerfilUsuario`; if `notifications.enabled` or `notifications.habitReminders` is false, desired state is empty. [VERIFIED: profile entity/codebase read; VERIFIED: `03-CONTEXT.md` D-12]
2. Load all habits, then list reminders for each habit because the current contract has only the per-habit list endpoint. Use bounded/concurrent `Future.wait`, retain only active reminders belonging to active habits, and handle one failed habit list as a reconciliation failure rather than silently producing a partial destructive schedule. [VERIFIED: `docs/openapi.yaml`; recommendation based on fail-safe consistency]
3. Resolve `tz.getLocation(profile.zonaHoraria)` and calculate desired occurrences with an injected `TZDateTime now`. Invalid zones produce a controlled error and no schedule mutation. [CITED: https://pub.dev/packages/timezone; VERIFIED: `03-CONTEXT.md` D-08]
4. Ask the scheduler port to replace the managed projection atomically: inspect pending requests, cancel only payloads with prefix `habit-reminder:v1:`, then schedule the complete sorted desired set. [CITED: https://pub.dev/documentation/flutter_local_notifications/latest/flutter_local_notifications/FlutterLocalNotificationsPlugin-class.html]
5. Serialize reconciliations so rapid switch/edit/profile events cannot interleave cancellation and scheduling. Coalesce a second request into one rerun after the current pass. [ASSUMED]

Trigger reconciliation after successful reminder mutation; after habit pause/resume/complete; after profile timezone/notification-preference changes; and when the session resolves authenticated on app startup/login. These triggers are required to keep eligibility, zone, and preference changes reflected locally. [VERIFIED: `03-CONTEXT.md` D-08/D-12; VERIFIED: existing habit/profile controllers]

### Pattern 4: Platform-Specific Schedule Shape

Use one Android repeating rule per `(reminderId, ISO weekday)` with `DateTimeComponents.dayOfWeekAndTime`; calculate the first future `TZDateTime` yourself, then let the plugin persist/restore the weekly rule. Use exact-allow-while-idle only when allowed, otherwise inexact-allow-while-idle. [VERIFIED: `03-CONTEXT.md` D-10; CITED: https://pub.dev/packages/flutter_local_notifications#scheduling-a-notification]

Use one-shot iOS requests. Generate the globally earliest 64 occurrences with a min-heap/merge of each reminder's next occurrence, tie-break by UTC instant → reminder ID → ISO weekday → per-reminder ordinal, and schedule in that order. This is deterministic and naturally allocates more slots to events that occur sooner without arbitrary quotas. [VERIFIED: `03-CONTEXT.md` D-11 and Agent's Discretion]

### Pattern 5: Deterministic Integer IDs Without Runtime `hashCode`

On every full reconciliation, sort managed schedule keys and assign IDs sequentially from a documented reserved base (for example `1_000_000 + index`). Store `habit-reminder:v1:<habitId>:<reminderId>:<key>` in the payload. Cancel old managed IDs by payload prefix before assigning the new batch. This is collision-free within the batch, deterministic for identical desired state, and avoids Dart hash values that are not guaranteed stable across runs/platforms. [VERIFIED: Agent's Discretion; CITED: https://api.dart.dev/dart-core/Object/hash.html]

Reserve this ID namespace exclusively for habit reminders and test maximum/non-negative bounds. Do not derive IDs from list position unless the adapter always performs the preceding managed cancellation. [VERIFIED: recommended reconciliation invariant]

### Pattern 6: Testable App Bootstrap

Use a keep-alive Riverpod reconciliation controller plus a small `ConsumerStatefulWidget` bootstrap that listens to authentication transitions and `AppLifecycleState.resumed`. Do not perform network/scheduling side effects directly in provider `build()` or every `HabitBuilderApp.build()`. The native adapter memoizes plugin initialization; the no-op adapter initializes nothing. [VERIFIED: existing app/provider composition; recommendation for idempotent side effects]

Use `package:timezone/data/latest_all.dart` during native/test bootstrap and pass `Location` explicitly instead of mutating `tz.local`. The all database is the package's complete IANA variant and avoids reliance on the package default (`Etc/UTC` in 0.11.1). [CITED: https://pub.dev/packages/timezone; CITED: https://pub.dev/packages/timezone/changelog]

### Anti-Patterns to Avoid

- **Scheduling in widgets or Riverpod provider `build()`:** rebuilds can duplicate permission prompts and interleave schedules; call the coordinator only from explicit successful events/bootstrap listeners. [VERIFIED: reconciliation design]
- **Using `DateTime.now()`, `toLocal()`, or a numeric UTC offset:** this violates the profile-zone decision and fails across DST/travel. [VERIFIED: `03-CONTEXT.md` D-08; CITED: https://pub.dev/packages/timezone]
- **Importing the plugin outside infrastructure:** it makes HBM-14 logic/plugin-dependent and violates D-09. [VERIFIED: `03-CONTEXT.md` D-09]
- **Calling `cancelAll()`:** it can erase future unrelated local-notification features; cancel only managed payload-prefixed requests. [CITED: https://pub.dev/documentation/flutter_local_notifications/latest/flutter_local_notifications/FlutterLocalNotificationsPlugin-class.html]
- **Scheduling more than 64 iOS requests and trusting insertion order:** iOS keeps only 64 and newer iOS versions keep the last set, not necessarily the soonest. Schedule exactly the selected 64. [CITED: https://pub.dev/packages/flutter_local_notifications#ios-pending-notifications-limit]
- **Treating permission denial as save failure:** backend configuration should remain saved; expose delivery as disabled/degraded and reconcile later when permissions change. [VERIFIED: `03-CONTEXT.md` D-06/D-10]
- **Using `String.hashCode`/`Object.hash` for persisted notification IDs:** stability across executions/platforms is not guaranteed. [CITED: https://api.dart.dev/dart-core/Object/hash.html]
- **Applying `stash@{0}` or staging generated Windows plugin files:** explicitly forbidden and risks mixing historical/unrelated state into either ticket. [VERIFIED: `03-CONTEXT.md` D-15]

## Exact Recommended Implementation Order

### HBM-13 — `HBM-13/reminder-ui` (must finish and merge first)

1. **Protect the worktree before edits.** Verify branch `HBM-13/reminder-ui`; record `git status --short`; assert the only pre-existing dirty path remains `windows/flutter/generated_plugins.cmake`; do not inspect/apply/pop `stash@{0}` beyond confirming it remains untouched. Use `--no-pub` for Flutter gates because HBM-13 adds no package. [VERIFIED: current Git state; VERIFIED: `03-CONTEXT.md` D-14/D-15]
2. **Fix the OpenAPI contract first.** Add required non-empty `mensaje` to `Recordatorio` and `RecordatorioRequest`; add `hora` pattern `^(?:[01]\d|2[0-3]):[0-5]\d$`; add `diasSemana.minItems: 1`, `uniqueItems: true`, and item range 1..7; keep `activo` required; add representative examples and relevant `400/404/409` error responses without changing endpoint paths. [VERIFIED: `03-CONTEXT.md` D-02/D-07; VERIFIED: current `docs/openapi.yaml` gaps]
3. **Extend Prism smoke immediately.** Cover authenticated list, create with all four writable fields, PATCH edit, PATCH deactivate while preserving message/time/days, and optional DELETE cleanup; update the terminal success message. Run this before Dart UI work so Prism proves HBB-23-compatible shape. [VERIFIED: QUALITY-18; VERIFIED: current smoke gap]
4. **Build domain/data vertically.** Add `ReminderTime`, immutable `Recordatorio`, `ReminderDraft`, `ReminderRepository`, DTO, Dio datasource, and repository implementation. Methods: list by habit, create by habit, update by reminder ID with the full writable shape, and delete. Use `runApiCall` and exact existing endpoint paths. [VERIFIED: existing feature architecture; VERIFIED: `docs/openapi.yaml`]
5. **Add tests for the boundary before presentation.** Cover time/day/message validation, DTO round-trip and exact JSON, all HTTP paths/methods/payloads/status normalization, repository mapping, and preservation of writable fields during `activo` changes. [VERIFIED: QUALITY-13; VERIFIED: existing test patterns]
6. **Add Riverpod providers/controller.** Implement family list/detail providers and a controller with typed create/update/toggle/delete operations. Enforce create/reactivate eligibility in the controller before repository calls; invalidate only reminder providers after success. [VERIFIED: `03-CONTEXT.md` D-06; VERIFIED: existing provider pattern]
7. **Wire navigation and CU-006.** Add `AppRoutes.habitReminders(habitId)`, the protected router entry, and a `Recordatorios` action on each habit card. Build the app-bar/back flow, green summary, loading/empty/error/list states, cards with prominent time/message/day chips/switch, form sheet/dialog, and `Añadir recordatorio`; keep it usable at 320 px via `AppContent` and scrollable content. Add a reminder-card overflow delete action with confirmation so the existing DELETE contract has a visible owner. [VERIFIED: `03-CONTEXT.md` D-04/D-05 and Phase Boundary; deletion UI is recommended from D-12]
8. **Prove eligibility and state preservation in widgets.** Test active/paused/completed habits; allowed edit/deactivate/delete; blocked create/reactivate with explanatory copy and zero repository calls; invalid form values; failed API submission preserving every field; switch rollback/no fake success; routing from a habit card; 320 px overflow. [VERIFIED: `03-CONTEXT.md` D-06/D-07/D-13]
9. **Run HBM-13 gates against the real PR base.** Generate Riverpod code intentionally, run formatter, `flutter analyze --no-pub`, targeted tests, full `flutter test --coverage --no-pub`, `flutter build web --release --no-pub`, Prism smoke, and changed coverage with `git merge-base HEAD origin/main`. Re-check that the protected generated Windows file is byte-for-byte unchanged and unstaged. [VERIFIED: `.planning/ROADMAP.md`; VERIFIED: D-15]
10. **Merge HBM-13 before HBM-14 begins.** Capture the immutable HBM-13 tip after its final commit, open exactly one Bitbucket PR to `main`, verify source/destination/source commit, merge it, fetch, and require `git merge-base --is-ancestor <captured-tip> origin/main`. Only then write the final HBM-13 summary and release every HBM-14 plan. [VERIFIED: revised delivery gate D-01/D-14]

### HBM-14 — `HBM-14/local-notifications` (only after HBM-13 merge)

1. **Create from updated `main` in a clean isolated worktree.** Confirm HBM-13 files and contract are present, create `HBM-14/local-notifications`, and keep the current protected worktree, generated CMake file, and `stash@{0}` untouched. [VERIFIED: `03-CONTEXT.md` D-14/D-15]
2. **Record official package legitimacy, then pin dependencies.** Implement and test a `pre`/`post` helper that validates the exact official metadata and UTC ordering around `pubspec.yaml`/lockfile mutation, then add exact 22.2.0/0.11.1 only in the isolated worktree. Never include generated Windows plugin files in the PR. [VERIFIED: D-15/D-16]
3. **Implement pure scheduling contracts first.** Add `ReminderScheduler`, permission/result types, `ManagedNotification`, explicit `Location` resolution, injected clock, next-occurrence calculation, Android weekly-rule generation, global iOS earliest-64 merge, payload namespace, and sequential ID allocation. No plugin imports. [VERIFIED: `03-CONTEXT.md` D-08/D-09/D-11]
4. **Write deterministic tests before adapters.** Cover same-day future/past, ISO weekdays, month/year rollover, profile zones different from device zone, DST spring gap/fall overlap, invalid IANA zone, tie ordering, exactly 64 iOS events, empty sets, stable IDs, and payload namespace. Document the chosen DST-gap behavior in tests. [VERIFIED: QUALITY-14; CITED: https://pub.dev/packages/timezone]
5. **Add conditional adapters.** Implement explicit web/desktop no-op; native plugin initializer; Android permission/exact-fallback/repeating schedule/cancel/pending mapping; iOS permission/one-shot schedule/cancel/pending mapping. Keep plugin types behind a thin infrastructure gateway and out of all tests. [VERIFIED: `03-CONTEXT.md` D-09..D-11; CITED: https://pub.dev/documentation/flutter_local_notifications/latest/flutter_local_notifications/]
6. **Apply native configuration.** Add Android desugaring/multidex, boot/exact declarations, receivers, notification drawable and retention rule; add iOS notification-center delegate while preserving implicit-engine registration. [CITED: https://pub.dev/packages/flutter_local_notifications]
7. **Implement serialized full reconciliation.** Fetch profile/habits/reminders; compute eligible desired state; cancel only managed pending requests; schedule desired state. Trigger after reminder create/edit/toggle/delete, habit pause/resume/complete, profile zone/preferences update, authenticated startup/login, and resume after exact-alarm settings. [VERIFIED: `03-CONTEXT.md` D-08/D-12; VERIFIED: integration points in existing controllers]
8. **Expose degraded delivery state without undoing server data.** Saved configuration remains visible when notification permission is denied or exact permission falls back; show precise UI status and retry/settings action where appropriate. [VERIFIED: `03-CONTEXT.md` D-10]
9. **Run automated gates.** Run pure/port/controller/widget tests, full analyze/coverage, web release build proving no-op conditional imports, unchanged Prism smoke, and changed coverage against the post-HBM-13 `origin/main` merge base. [VERIFIED: QUALITY-14..18]
10. **Run native acceptance checks.** Android 13/14+: notification granted/denied, exact granted/denied, inexact fallback, edit/deactivate/delete, reboot, package replacement, and active-habit lifecycle. iOS 13+: first permission grant/denial, foreground presentation, timezone change, exactly 64 pending requests, and resupply on relaunch. Physical-device/iOS checks require external hardware/macOS because none is available here. [CITED: https://developer.android.com/about/versions/14/changes/schedule-exact-alarms; CITED: https://pub.dev/packages/flutter_local_notifications#testing; VERIFIED: environment audit]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---|---|---|---|
| Native alarms/notification center | Platform channels over `AlarmManager`/`UNUserNotificationCenter` | `flutter_local_notifications` 22.2.0 adapter [AUTHORIZED D-16] | Plugin already handles platform API translation, pending requests, cancellation, and Android reboot persistence. [CITED: https://pub.dev/packages/flutter_local_notifications] |
| IANA offsets and DST tables | Offset maps or device-local conversion | `timezone` 0.11.1 [AUTHORIZED D-16] | IANA rules change and offsets are date/location dependent. [CITED: https://pub.dev/packages/timezone] |
| Reminder HTTP plumbing | JSON handling in widgets/controllers | Existing Dio datasource + DTO + repository pattern | Preserves current architecture and normalized `ApiException` behavior. [VERIFIED: codebase read] |
| Permission UI as business state | A custom boolean pretending OS permission | Platform-specific check/request APIs and typed result | OS permission can change outside the app and exact alarm is separate from notification permission. [CITED: https://pub.dev/documentation/flutter_local_notifications/latest/flutter_local_notifications/AndroidFlutterLocalNotificationsPlugin-class.html; CITED: https://developer.android.com/about/versions/14/changes/schedule-exact-alarms] |
| Unscoped cancellation | `cancelAll()` | Pending-request filter by managed payload prefix + `cancel(id:)` | Avoids deleting unrelated future notification categories. [CITED: https://pub.dev/documentation/flutter_local_notifications/latest/flutter_local_notifications/FlutterLocalNotificationsPlugin-class.html] |
| Persistent hash IDs | `hashCode`-derived IDs | Full reconciliation + sorted sequential reserved IDs | Dart hash stability is not guaranteed across runs/platforms. [CITED: https://api.dart.dev/dart-core/Object/hash.html] |
| Web notification simulation | Browser plugin use or fake timers | Explicit `NoOpReminderScheduler` | D-11 deliberately limits web to visual/configuration review. [VERIFIED: `03-CONTEXT.md` D-11] |

**Key insight:** the durable truth is backend reminder configuration plus profile/habit state; device schedules are disposable projections that can always be rebuilt. [VERIFIED: `03-CONTEXT.md` D-12 and API architecture]

## Common Pitfalls

### Pitfall 1: Building HBM-13 Against the Current Incomplete Schema

**What goes wrong:** DTO/UI implementation omits `mensaje`, Prism generates the wrong response, and HBB-23/mobile diverge. [VERIFIED: current `docs/openapi.yaml`]  
**Why it happens:** endpoints already exist, making the contract look complete. [VERIFIED: `docs/openapi.yaml`]  
**How to avoid:** make OpenAPI + reminder smoke the first HBM-13 task and gate Dart work on it. [VERIFIED: D-02/QUALITY-18]  
**Warning sign:** a `Recordatorio` constructor or JSON fixture has no `mensaje`. [VERIFIED: locked shape]

### Pitfall 2: UI-Only Eligibility

**What goes wrong:** tests/deep links can invoke create/reactivate for paused/completed habits, or an existing active configuration remains scheduled after a habit is paused. [VERIFIED: phase eligibility rules]  
**Why it happens:** disabled buttons are mistaken for a business invariant. [ASSUMED]  
**How to avoid:** enforce in controller, backend response handling, and HBM-14 desired-state filtering; reconcile after habit lifecycle changes. [VERIFIED: D-06/D-12]  
**Warning sign:** repository create/update is called in a paused-habit controller test. [VERIFIED: expected test invariant]

### Pitfall 3: Permission Requested During Startup

**What goes wrong:** iOS prompts without user context, Android exact-alarm settings interrupt startup, and app rebuilds can repeat request calls. [CITED: https://pub.dev/packages/flutter_local_notifications#requesting-notification-permissions] [ASSUMED]  
**Why it happens:** plugin initialization and permission request are conflated. [CITED: https://pub.dev/packages/flutter_local_notifications#initialisation]  
**How to avoid:** initialize with iOS request flags false and request only on first eligible activation; reconcile on resume. [CITED: https://pub.dev/packages/flutter_local_notifications#requesting-notification-permissions; CITED: https://developer.android.com/about/versions/14/changes/schedule-exact-alarms]  
**Warning sign:** `requestPermissions()` appears in `main()` or a provider `build()`. [VERIFIED: recommended boundary]

### Pitfall 4: Exact Scheduling Without a Permission Re-check

**What goes wrong:** an exact recurring notification is not scheduled after permission revocation. [CITED: https://pub.dev/packages/flutter_local_notifications#scheduling-a-notification]  
**Why it happens:** Android 14 denies exact-alarm access by default for many new installs and permission can change in settings. [CITED: https://developer.android.com/about/versions/14/changes/schedule-exact-alarms]  
**How to avoid:** check `canScheduleExactNotifications()` every reconciliation and use inexact-allow-while-idle when false. [CITED: https://pub.dev/documentation/flutter_local_notifications/latest/flutter_local_notifications/AndroidFlutterLocalNotificationsPlugin-class.html; VERIFIED: D-10]  
**Warning sign:** adapter always passes `exactAllowWhileIdle`. [VERIFIED: D-10]

### Pitfall 5: iOS Queue Ordering and Exhaustion

**What goes wrong:** scheduling more than 64 can leave the wrong requests pending; a finite 64-event horizon eventually empties if the user never relaunches the app. [CITED: https://pub.dev/packages/flutter_local_notifications#ios-pending-notifications-limit; VERIFIED: finite scheduling design]  
**Why it happens:** the limit is treated as per reminder or recurring rules are mixed with one-shot occurrence allocation. [ASSUMED]  
**How to avoid:** reconcile exactly the globally earliest 64 one-shots on authenticated app start and every relevant mutation. [VERIFIED: D-11/D-12]  
**Warning sign:** more than 64 iOS `zonedSchedule` calls or a per-reminder loop that schedules 64 each. [VERIFIED: D-11]

### Pitfall 6: DST-Unsafe Date Arithmetic

**What goes wrong:** adding 24-hour durations can shift local wall time across DST, and a nonexistent spring-forward time may normalize differently than product expectations. [CITED: https://pub.dev/packages/timezone; CITED: https://pub.dev/packages/flutter_local_notifications#scheduling-a-notification]  
**Why it happens:** duration arithmetic is used where calendar-day construction is required. [ASSUMED]  
**How to avoid:** construct each candidate from location + calendar components and compare to injected zoned `now`; for a gap advance to the first valid local instant, and for an overlap emit exactly one occurrence using the earliest offset. Lock both policies in named tests. [VERIFIED: revised D-08; CITED: https://pub.dev/documentation/timezone/latest/timezone/TZDateTime/TZDateTime.html]  
**Warning sign:** `now.add(Duration(days: ...))` determines the reminder wall clock. [VERIFIED: D-08]

### Pitfall 7: Partial Destructive Reconciliation

**What goes wrong:** one failed reminder-list request is treated as empty, then valid pending alarms for that habit are canceled. [ASSUMED]  
**Why it happens:** `Future.wait` errors are caught per item and replaced with empty lists. [ASSUMED]  
**How to avoid:** calculate the complete desired set first; if any required fetch/zone conversion fails, leave the current schedule untouched and report/retry. [VERIFIED: fail-safe reconciliation recommendation]  
**Warning sign:** cancellation happens before all API/profile inputs have succeeded. [VERIFIED: reconciliation invariant]

### Pitfall 8: Generated Plugin File Contamination

**What goes wrong:** package resolution or Flutter tooling rewrites the already-dirty Windows generated CMake file, and it is accidentally staged with HBM-14. [VERIFIED: current Git state; plugin supports Windows]  
**Why it happens:** Flutter plugin registration spans enabled platforms even when Phase 3 only targets Android/iOS/web. [VERIFIED: plugin pubspec platform metadata]  
**How to avoid:** perform HBM-14 in an isolated clean worktree, never stage generated platform files, and compare status before/after every gate. [VERIFIED: D-15]  
**Warning sign:** `windows/flutter/generated_plugins.cmake` appears in `git diff --cached --name-only`. [VERIFIED: D-15]

### Pitfall 9: Android OEM Alarm Limits/Background Restrictions

**What goes wrong:** some OEM devices suppress background behavior, and Samsung has been reported to cap scheduled alarms at 500. [CITED: https://pub.dev/packages/flutter_local_notifications#scheduled-android-notifications]  
**Why it happens:** these are vendor OS constraints outside plugin control. [CITED: https://pub.dev/packages/flutter_local_notifications#scheduled-android-notifications]  
**How to avoid:** Android schedules one weekly rule per selected day rather than an unbounded list of one-shots; surface degraded behavior honestly in acceptance notes. [VERIFIED: recommended platform shape]  
**Warning sign:** Android code materializes months of one-shot occurrences. [VERIFIED: schedule design]

## Code Examples

### Pure Next-Occurrence Calculation

```dart
// Source basis:
// https://pub.dev/packages/timezone
// https://pub.dev/documentation/timezone/latest/timezone/TZDateTime/TZDateTime.html
tz.TZDateTime nextOccurrence({
  required tz.Location location,
  required tz.TZDateTime now,
  required int hour,
  required int minute,
  required Set<int> isoWeekdays,
}) {
  for (var dayOffset = 0; dayOffset <= 7; dayOffset++) {
    final candidate = tz.TZDateTime(
      location,
      now.year,
      now.month,
      now.day + dayOffset,
      hour,
      minute,
    );
    if (isoWeekdays.contains(candidate.weekday) && candidate.isAfter(now)) {
      return candidate;
    }
  }
  throw StateError('No next occurrence for a non-empty weekday set.');
}
```

Production code must validate non-empty weekdays before this function and inject `now`; tests must cover DST normalization rather than assuming every wall-clock minute exists. [VERIFIED: D-07/D-08; CITED: https://pub.dev/documentation/timezone/latest/timezone/TZDateTime/TZDateTime.html]

### Android Exact/Inexact Selection

```dart
// Source:
// https://pub.dev/documentation/flutter_local_notifications/latest/
// flutter_local_notifications/AndroidFlutterLocalNotificationsPlugin-class.html
final canScheduleExact =
    await androidPlugin.canScheduleExactNotifications() ?? false;

await androidPlugin.zonedSchedule(
  id: notification.id,
  title: notification.title,
  body: notification.body,
  scheduledDate: notification.scheduledAt,
  payload: notification.payload,
  notificationDetails: androidDetails,
  scheduleMode: canScheduleExact
      ? AndroidScheduleMode.exactAllowWhileIdle
      : AndroidScheduleMode.inexactAllowWhileIdle,
  matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
);
```

The adapter must first ensure normal notification permission; exact-alarm denial selects the inexact fallback rather than throwing or claiming exact delivery. [VERIFIED: D-10; CITED: https://pub.dev/documentation/flutter_local_notifications/latest/flutter_local_notifications/AndroidFlutterLocalNotificationsPlugin-class.html; CITED: https://developer.android.com/about/versions/14/changes/schedule-exact-alarms]

### iOS Delayed Permission Request

```dart
// Source:
// https://pub.dev/packages/flutter_local_notifications
const iosInitialization = DarwinInitializationSettings(
  requestAlertPermission: false,
  requestSoundPermission: false,
  requestBadgePermission: false,
);

final granted = await iosPlugin.requestPermissions(
  alert: true,
  sound: true,
  badge: false,
);
```

Call the request only from an eligible user activation path, then schedule through the port if granted. [VERIFIED: D-11; CITED: https://pub.dev/packages/flutter_local_notifications#requesting-notification-permissions]

### Conditional No-Op Factory

```dart
// reminder_scheduler_factory.dart
export 'reminder_scheduler_factory_noop.dart'
    if (dart.library.io) 'reminder_scheduler_factory_native.dart';

// reminder_scheduler_factory_noop.dart
ReminderScheduler createReminderScheduler() => NoOpReminderScheduler();
```

The native factory may branch with `Platform.isAndroid`/`Platform.isIOS`; the exported web implementation must not import `dart:io` or `flutter_local_notifications`. [VERIFIED: D-09/D-11; recommendation for web-safe compilation]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|---|---|---|---|
| `schedule`, `showDailyAtTime`, `showWeeklyAtDayAndTime` | `zonedSchedule` + `TZDateTime` | Plugin 2.0 | Use timezone-aware scheduling and calculate the next matching date explicitly. [CITED: https://pub.dev/packages/flutter_local_notifications#scheduling-a-notification] |
| Positional plugin calls | Named parameters for initialize/show/cancel/zonedSchedule | Plugin 20.0.0 | HBM-14 examples/tasks must use 22.2.0 named signatures. [CITED: https://pub.dev/packages/flutter_local_notifications/changelog] |
| Older Flutter/Dart/OS minimums | Flutter >=3.38.1, Dart ^3.10.0, Android 24/compile 36, iOS 13 | Plugin 21.0.0 | Current project is compatible; no SDK downgrade is needed. [CITED: https://pub.dev/packages/flutter_local_notifications/changelog; VERIFIED: local environment] |
| No web implementation | Plugin web support exists | Plugin 22.0.0 | Ignore it for this phase because locked D-11 requires explicit no-op. [CITED: https://pub.dev/packages/flutter_local_notifications/changelog; VERIFIED: D-11] |
| Package default zone named `UTC` | Default is `Etc/UTC` | timezone 0.11.1 | Never depend on the default; always resolve the profile IANA location explicitly. [CITED: https://pub.dev/packages/timezone/changelog] |

**Deprecated/outdated:**

- Pre-`zonedSchedule` local scheduling APIs are deprecated because of timezone/DST issues. [CITED: https://pub.dev/packages/flutter_local_notifications#scheduling-a-notification]
- Examples using positional arguments predate plugin 20.0.0 and will not match 22.2.0 signatures. [CITED: https://pub.dev/packages/flutter_local_notifications/changelog; CITED: https://pub.dev/documentation/flutter_local_notifications/latest/flutter_local_notifications/]
- Assuming the plugin manifest declares every scheduling receiver/permission has been wrong since plugin 16.0.0. [CITED: https://pub.dev/packages/flutter_local_notifications/changelog; CITED: https://pub.dev/packages/flutter_local_notifications#androidmanifestxml-setup]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|---|---|---|
| A1 | **RESOLVED by D-16:** `flutter_local_notifications` 22.2.0 is authorized after automated official-pub.dev verification. | Standard Stack / Package Audit | Fail closed before `pub get` if package/version/source/homepage evidence does not match. |
| A2 | **RESOLVED by D-16:** `timezone` 0.11.1 is authorized by the same non-interactive gate. | Standard Stack / Package Audit | Fail closed before `pub get` if official evidence does not match. |
| A3 | Reconciliation requests arriving during a run should coalesce into one serialized rerun. | Architecture Pattern 3 | Without serialization, rapid mutations can leave stale or duplicate schedules. |
| A4 | **RESOLVED by D-08:** spring gap advances to the first valid local instant; overlap schedules one occurrence using the earliest offset. | Common Pitfalls / Tests | Named tests must prove both policies across DST-observing zones. |
| A5 | Expose reminder deletion in a card overflow because DELETE exists and D-12 requires scheduler cancellation on delete. | HBM-13 order | If CU-006 intentionally omits deletion, the UI action should be removed while retaining repository/controller delete support. |
| A6 | A disabled control alone is insufficient enforcement/explanation for reminder eligibility. | Pitfall 2 | Controller enforcement and explanatory copy could be omitted if this assumption is missed. |
| A7 | Requesting permissions automatically during startup creates poor or repeated user experience. | Pitfall 3 | Permission timing/copy may need product adjustment, although delayed request remains the official package-supported pattern. |
| A8 | Mixing per-reminder 64-slot loops or recurring and one-shot iOS allocation is likely to select the wrong pending set. | Pitfall 5 | The queue may not contain the globally earliest 64 occurrences. |
| A9 | Duration-based day arithmetic is unsafe for preserving reminder wall time across DST. | Pitfall 6 | Tests may pass in `America/Bogota` but fail in DST-observing zones. |
| A10 | Treating a failed per-habit fetch as an empty list can destructively cancel valid pending reminders. | Pitfall 7 | Reconciliation could erase valid schedules during transient API failure. |
| A11 | **RESOLVED by D-02:** frontend establishes the contract first and HBB-23 converges afterward by explicit user order. | Resolved Inputs | Record the final mobile contract handoff; do not block HBM-13/HBM-14 on prior backend acceptance. |
| A12 | **RESOLVED by D-10/D-11:** Android uses local AVD `Pixel_6`; iOS remains external macOS/CI verification and cannot be marked passed without evidence. | Resolved Inputs | Android can be automated locally; iOS evidence status must remain explicit. |
| A13 | Notification payload parsing and scheduling logs need explicit trust/privacy rules. | Security Domain | Untrusted payloads could route incorrectly, or logs could disclose reminder/profile text. |

## Resolved Questions

1. **HBB-23 contract order — RESOLVED**
   - Frontend establishes `mensaje`, `hora`, `diasSemana`, `activo` and its
     validation first. HBB-23 converges afterward by explicit user order.
     Mobile plans record a contract handoff and do not claim prior backend
     acceptance. [VERIFIED: revised D-02]

2. **DST gap/overlap policy — RESOLVED**
   - A nonexistent local wall time advances to the first valid local instant.
     An overlap emits one occurrence using the earliest offset. Both outcomes
     require named deterministic tests. [VERIFIED: revised D-08]

3. **Native acceptance venue — RESOLVED**
   - Local Android SDK includes AVD `Pixel_6`; no device was attached during
     planning, so execution starts the AVD and waits for boot readiness.
   - iOS/Xcode is unavailable on Windows. Verification is documented for an
     external macOS/CI runner and remains `pending_external` until real
     evidence is attached; no plan may report an unexecuted iOS pass.
     [VERIFIED: 2026-07-28 environment probe; VERIFIED: D-10/D-11]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|---|---|---|---|---|
| Flutter SDK | Analyze/test/build/package resolution | Yes, not on PATH | 3.44.8 at `C:\Users\USER\flutter` | Invoke `C:\Users\USER\flutter\bin\flutter.bat` locally. [VERIFIED: local probe] |
| Dart SDK | Codegen/tools/tests | Yes, not on PATH | 3.12.2 bundled with Flutter | Invoke bundled `dart.bat`. [VERIFIED: local probe] |
| Node.js / npm | Prism and coverage scripts | Yes | Node 22.16.0 / npm 10.9.2 | — [VERIFIED: local probe] |
| Prism CLI | Contract mock/smoke | Installed in project | lockfile resolves `@stoplight/prism-cli` 5.14.2 | `npm ci` if `node_modules` is absent. [VERIFIED: `package.json`/`package-lock.json`] |
| Android SDK / adb/emulator | Android build/device checks | Yes; AVD available, not running | adb 37.0.0; AVD `Pixel_6` | Start local AVD automatically, wait for `sys.boot_completed`, then run acceptance. [VERIFIED: 2026-07-28 local probe] |
| Java | Android Gradle | Yes | Runtime 24.0.1; project compiles Java 17 | Prefer Flutter/Android-supported JDK if Gradle rejects runtime 24. [VERIFIED: local probe; VERIFIED: Gradle config] |
| iOS/Xcode toolchain | iOS build and permission/64 tests | No on Windows | — | Run on macOS CI or developer Mac/iPhone. [VERIFIED: host OS/environment] |
| Context7 | Preferred package-doc lookup | No | CLI absent; MCP unavailable | Official pub.dev/API/GitHub/Android docs were used. [VERIFIED: tool/CLI discovery] |
| slopcheck | Package legitimacy | Installed after best-effort | 0.6.1, npm-only for this invocation | Use the automated, tested D-16 official-pub.dev helper; no human package checkpoint. [VERIFIED: D-16] |

**Missing dependencies with no local fallback:**

- iOS/Xcode/native-device verification cannot run on this Windows host; it
  requires external macOS/CI evidence and must remain `pending_external` until
  that evidence exists. [VERIFIED: environment audit; VERIFIED: D-11]

**Missing dependencies with fallback:**

- Flutter/Dart are absent from PATH but available by absolute path. [VERIFIED: environment audit]
- Android has no currently attached device, but the local `Pixel_6` AVD is an
  executable fallback. [VERIFIED: emulator probe]
- Context7 is unavailable; official package and platform documentation supplied the required authoritative evidence. [VERIFIED: lookup audit]

## Validation Architecture

`workflow.nyquist_validation` is absent from `.planning/config.json`, so validation architecture is enabled by default. [VERIFIED: `.planning/config.json`]

### Test Framework

| Property | Value |
|---|---|
| Framework | `flutter_test` from Flutter 3.44.8 + mocktail 1.0.5. [VERIFIED: `pubspec.yaml`; local SDK] |
| Config file | None; Flutter defaults are in use. [VERIFIED: filesystem scan] |
| Quick HBM-13 command | `flutter test test/features/reminders --no-pub` [VERIFIED: planned test tree] |
| Quick HBM-14 command | `flutter test test/features/reminders/domain test/features/reminders/application --no-pub` [VERIFIED: planned test tree] |
| Full suite command | `flutter test --coverage --no-pub` [VERIFIED: roadmap gate, with protected-file safeguard] |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|---|---|---|---|---|
| REMINDER-01 | Entity/time validation, exact DTO/API mapping, list/create/edit UI | unit + datasource + widget | `flutter test test/features/reminders --no-pub` | ❌ Wave 0 |
| REMINDER-02 | Profile-zone `TZDateTime` occurrence calculation | unit | `flutter test test/features/reminders/domain/reminder_occurrence_planner_test.dart --no-pub` | ❌ Wave 0 |
| REMINDER-03 | Create/reactivate blocked; edit/deactivate allowed; scheduler excludes ineligible habits | controller + widget + application | `flutter test test/features/reminders/presentation/reminder_eligibility_test.dart test/features/reminders/application/reminder_reconciliation_test.dart --no-pub` | ❌ Wave 0 |
| REMINDER-04 | Toggle preserves message/time/days and rollback on failure | controller + widget | `flutter test test/features/reminders/presentation/reminder_controller_test.dart test/features/reminders/presentation/reminders_screen_test.dart --no-pub` | ❌ Wave 0 |
| REMINDER-05 | Permission outcomes, exact/inexact mode, managed cancellation, iOS 64, startup reconciliation | pure gateway/port + manual native | `flutter test test/features/reminders/application --no-pub` | ❌ Wave 0 |
| QUALITY-13 | HBM-13 unit/data/widget suite exists and passes | suite | `flutter test test/features/reminders --coverage --no-pub` | ❌ Wave 0 |
| QUALITY-14 | No plugin import in tests/domain/controller and deterministic schedules | unit + static grep | `flutter test test/features/reminders/domain test/features/reminders/application --no-pub` plus `rg "flutter_local_notifications" lib/features/reminders/domain lib/features/reminders/presentation test/features/reminders` | ❌ Wave 0 |
| QUALITY-15 | Changed-code coverage >=80% against actual PR base | coverage gate | `node scripts/check-changed-coverage.mjs --base <merge-base-sha> --lcov coverage/lcov.info --min 80` | ✅ script exists |
| QUALITY-16 | Analyze/full tests pass | static + suite | `flutter analyze --no-pub && flutter test --coverage --no-pub` | ✅ framework exists |
| QUALITY-17 | Web compiles with no-op scheduler | build + no-op unit | `flutter build web --release --no-pub` | ❌ no-op tests Wave 0 |
| QUALITY-18 | Prism reminder list/create/edit/deactivate | contract smoke | `npm run mock:smoke` | ❌ reminder cases Wave 0 |

### Required Test Cases

HBM-13 must include:

- `reminder_time_test.dart`: strict `HH:mm`, boundaries `00:00`/`23:59`, invalid values, ISO day uniqueness/range, trimmed non-empty message. [VERIFIED: D-02/D-07]
- `recordatorio_dto_test.dart`: exact response/request JSON and round-trip with `mensaje`. [VERIFIED: contract requirement]
- `reminder_remote_data_source_test.dart`: all paths/methods/payloads and normalized 400/404/409 failures. [VERIFIED: existing datasource test style]
- `reminder_repository_impl_test.dart`: DTO/entity mapping and full-field toggle preservation. [VERIFIED: existing repository test style]
- `reminder_controller_test.dart`: invalid eligibility makes zero repository calls; success invalidates expected providers; failure retains state. [VERIFIED: D-06/D-07]
- `reminders_screen_test.dart`: loading/empty/error/list, form validation, edit hydration, API-error state preservation, switches, delete confirmation, paused/completed explanation, and 320 px layout. [VERIFIED: D-04..D-07/D-13]
- Router/habit-card test for `/habits/:habitId/reminders`. [VERIFIED: D-04]

HBM-14 must include:

- `reminder_occurrence_planner_test.dart`: ISO weekdays, same-day boundary, month/year rollover, profile-zone independence, spring gap, fall overlap, invalid zone, deterministic ties. [VERIFIED: D-08/QUALITY-14]
- `ios_occurrence_allocator_test.dart`: globally earliest exactly 64, fewer-than-64, multiple reminders, deterministic tie-breaks. [VERIFIED: D-11]
- `managed_notification_id_test.dart`: reserved range, uniqueness, repeatability, and payload namespace. [VERIFIED: Agent's Discretion]
- `reminder_reconciliation_test.dart`: preferences off, inactive habits, partial-fetch fail-safe, stale managed cancellation, unrelated pending preservation, serialized rerun, and each trigger. [VERIFIED: D-12]
- `notification_permission_policy_test.dart`: notification denied, exact granted, exact denied/inexact fallback, iOS denied/granted, no-op behavior. [VERIFIED: D-10/D-11]
- Manual Android/iOS acceptance checklist captured in HBM-14 summary/PR evidence. [VERIFIED: REMINDER-05]

### Sampling Rate

- **Per task commit:** targeted test file(s) for the layer changed plus `flutter analyze --no-pub`. [VERIFIED: recommended fast feedback]
- **Per HBM-13 wave/PR:** full suite, web release, Prism smoke, changed coverage against HBM-13 merge base. [VERIFIED: roadmap gates]
- **Per HBM-14 wave/PR:** full suite, web release, Prism smoke, changed coverage against post-HBM-13 `main`, then native acceptance. [VERIFIED: roadmap/requirements]
- **Phase gate:** both PRs independently green, HBM-13 merged before HBM-14 base, full integrated suite green before `$gsd-verify-work`. [VERIFIED: D-01/D-13/D-14]

### Wave 0 Gaps

- [ ] `test/features/reminders/domain/reminder_time_test.dart` — REMINDER-01.
- [ ] `test/features/reminders/data/recordatorio_dto_test.dart` — REMINDER-01.
- [ ] `test/features/reminders/data/reminder_remote_data_source_test.dart` — REMINDER-01/QUALITY-18.
- [ ] `test/features/reminders/data/reminder_repository_impl_test.dart` — REMINDER-01/04.
- [ ] `test/features/reminders/presentation/reminder_controller_test.dart` — REMINDER-03/04.
- [ ] `test/features/reminders/presentation/reminders_screen_test.dart` — REMINDER-01/03/04.
- [ ] `test/features/reminders/domain/reminder_occurrence_planner_test.dart` — REMINDER-02/QUALITY-14.
- [ ] `test/features/reminders/application/ios_occurrence_allocator_test.dart` — REMINDER-05.
- [ ] `test/features/reminders/application/managed_notification_id_test.dart` — REMINDER-05.
- [ ] `test/features/reminders/application/reminder_reconciliation_test.dart` — REMINDER-03/05.
- [ ] `test/features/reminders/application/notification_permission_policy_test.dart` — REMINDER-05/QUALITY-17.
- [ ] `test/features/reminders/support/fakes.dart` — shared repository/scheduler/gateway fixtures.
- [ ] Reminder operations in `scripts/mock-smoke.mjs` — QUALITY-18.

No test-framework installation gap exists. [VERIFIED: existing `flutter_test`/mocktail infrastructure]

## Security Domain

Security enforcement is enabled because `.planning/config.json` does not explicitly set `security_enforcement: false`. The table uses the ASVS v4 category names required by the research template; OWASP's current stable ASVS is 5.0.0 and reorganizes chapter numbering. [VERIFIED: `.planning/config.json`; CITED: https://github.com/OWASP/ASVS]

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---|---|---|
| V2 Authentication | No new mechanism | Reuse existing authenticated Dio/session flow; reminder routes remain protected by go_router redirect. [VERIFIED: router/network codebase read] |
| V3 Session Management | Indirectly | Reconciliation starts only when shared auth session resolves true and stops producing schedules when unauthenticated/logout is processed. [VERIFIED: existing auth session architecture; VERIFIED: D-12] |
| V4 Access Control | Yes | UI/controller eligibility is not authorization; backend must enforce ownership for habit/reminder IDs and fail securely on cross-user IDs. [CITED: OWASP ASVS v4 V4.1/V4.2; VERIFIED: authenticated API contract] |
| V5 Input Validation | Yes | Validate trimmed message, strict 24-hour time, unique ISO days 1..7, known IANA zone, and typed IDs at contract/domain boundaries. [VERIFIED: phase requirements; CITED: https://pub.dev/packages/timezone] |
| V6 Stored Cryptography | No new cryptography | Reuse existing bearer token/secure storage; local scheduling introduces no new secrets or cryptographic design. [VERIFIED: codebase read; VERIFIED: phase boundary] |

### Known Threat Patterns for Flutter Reminder Stack

| Pattern | STRIDE | Standard Mitigation |
|---|---|---|
| Changing `habitId`/`reminderId` to access another user's data | Elevation of Privilege / Information Disclosure | Authenticated backend ownership checks; client treats 403/404 as failure and never claims success. [CITED: OWASP ASVS v4 V4.2.1; VERIFIED: API/client architecture] |
| Malformed API time/day/zone causing crash or wrong delivery | Tampering / Denial of Service | Strict DTO/domain validation, controlled `LocationNotFoundException`, fail-safe reconciliation before cancellation. [VERIFIED: recommended boundaries; CITED: https://pub.dev/packages/timezone] |
| Forged/untrusted notification payload used as arbitrary route | Spoofing / Tampering | Versioned internal payload schema; parse IDs strictly; route only to protected in-app destinations; never interpret payload as URL/code. [ASSUMED] |
| Permission spam or exact-alarm coercion | Repudiation / User control abuse | Request in user context, one process attempt for iOS, explicit Android exact rationale, and inexact fallback. [CITED: https://pub.dev/packages/flutter_local_notifications#requesting-notification-permissions; CITED: https://developer.android.com/about/versions/14/changes/schedule-exact-alarms] |
| Logging message text or profile data during scheduling errors | Information Disclosure | Log only IDs/status/error category; do not log reminder message, bearer token, or full profile. [ASSUMED] |
| Canceling unrelated local notifications | Denial of Service | Managed payload namespace and targeted `cancel(id:)`, never `cancelAll()`. [VERIFIED: scheduler design; CITED: https://pub.dev/documentation/flutter_local_notifications/latest/flutter_local_notifications/FlutterLocalNotificationsPlugin-class.html] |

## Sources

### Primary (HIGH confidence)

- `.planning/phases/03-reminders/03-CONTEXT.md` — locked phase decisions, discretion, and exclusions. [VERIFIED: codebase read]
- `.planning/ROADMAP.md` and `.planning/REQUIREMENTS.md` — sequence, requirements, and quality/delivery gates. [VERIFIED: codebase read]
- `docs/openapi.yaml` — current reminder endpoint/schema shape and identified `mensaje`/validation gap. [VERIFIED: codebase read]
- `pubspec.yaml`, `pubspec.lock`, Android/iOS project files, and local Flutter source — current stack/platform compatibility. [VERIFIED: codebase/local SDK read]
- https://pub.dev/packages/flutter_local_notifications — 22.2.0 setup, limitations, scheduling, permissions, receivers, iOS 64, and testing. Checked 2026-07-28. [CITED: https://pub.dev/packages/flutter_local_notifications]
- https://pub.dev/documentation/flutter_local_notifications/latest/flutter_local_notifications/ — exact 22.2.0 named API signatures. Checked 2026-07-28. [CITED: https://pub.dev/documentation/flutter_local_notifications/latest/flutter_local_notifications/]
- https://pub.dev/packages/flutter_local_notifications/changelog — 20.x/21.x/22.x breaking/current behavior. Checked 2026-07-28. [CITED: https://pub.dev/packages/flutter_local_notifications/changelog]
- https://pub.dev/packages/timezone and https://pub.dev/documentation/timezone/latest/ — 0.11.1 IANA initialization and `TZDateTime`. Checked 2026-07-28. [CITED: https://pub.dev/packages/timezone]
- https://pub.dev/packages/timezone/changelog — 0.11.1 default-zone change and 0.11.x changes. Checked 2026-07-28. [CITED: https://pub.dev/packages/timezone/changelog]
- https://developer.android.com/about/versions/14/changes/schedule-exact-alarms — exact-alarm grant/check/fallback policy. Updated 2026-03-03, checked 2026-07-28. [CITED: https://developer.android.com/about/versions/14/changes/schedule-exact-alarms]
- https://developer.android.com/develop/ui/compose/notifications/notification-permission — Android 13+ notification permission. Checked 2026-07-28. [CITED: https://developer.android.com/develop/ui/compose/notifications/notification-permission]
- https://api.dart.dev/dart-core/Object/hash.html — hash stability limitation. Checked 2026-07-28. [CITED: https://api.dart.dev/dart-core/Object/hash.html]
- https://github.com/OWASP/ASVS — current ASVS release/status. Checked 2026-07-28. [CITED: https://github.com/OWASP/ASVS]

### Secondary (MEDIUM confidence)

- `scripts/mock-smoke.mjs`, reminder/habit/profile/router source, and existing tests — implementation conventions and current coverage gaps. [VERIFIED: codebase read]
- Official plugin limitation notes about OEM background restrictions and Samsung alarm cap. [CITED: https://pub.dev/packages/flutter_local_notifications#scheduled-android-notifications]

### Tertiary (LOW confidence)

- None used as factual authority. All unverified design/product-policy choices are explicitly listed as `[ASSUMED]`. [VERIFIED: research audit]

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH for existence/version/API/platform compatibility; installation is authorized by D-16 only after the automated official-pub.dev record passes. [VERIFIED: official registry/docs and package audit]
- Architecture: HIGH because it follows locked decisions and existing feature-first repository/provider patterns. [VERIFIED: context/codebase]
- Platform configuration: HIGH for documented setup; MEDIUM for runtime behavior until physical-device checks pass. [CITED: https://pub.dev/packages/flutter_local_notifications; CITED: https://developer.android.com/about/versions/14/changes/schedule-exact-alarms; VERIFIED: environment audit]
- Pitfalls: HIGH for contract, timezone, permission, iOS limit, protected-file findings and the resolved DST policy. [VERIFIED: source mix; VERIFIED: D-08]

**Research date:** 2026-07-28  
**Valid until:** 2026-08-04, because `flutter_local_notifications` 22.2.0 was published only three days before this research and the Flutter/plugin platform stack is fast-moving. [VERIFIED: pub.dev publish date]
