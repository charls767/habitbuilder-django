# HabitBuilder — Mobile

Flutter app for **HabitBuilder**, a habit-tracking mobile app. Built for the *Calidad de Software 2025-2* course project (Prof. Albeiro Espinosa Bedoya).

Companion repo: [habitbuilder-backend](https://bitbucket.org/habit_builder/habitbuilder-backend) (Spring Boot). Tickets: [Habit Builder Frontend](https://habitbuilder.atlassian.net/jira/software/projects/HBM/boards) (Jira, project `HBM`).

## Stack

- **Flutter** (Dart SDK `^3.5.0`)
- **Riverpod** (code-gen) for state management
- **go_router** for navigation
- **dio** for HTTP
- **flutter_secure_storage** for the JWT access token (never `SharedPreferences`)
- **flutter_local_notifications** + **timezone** for reminders (`TZDateTime`, never naive `DateTime`)
- **freezed** / **json_serializable** for DTOs
- **mocktail** for tests

## Architecture

Feature-first, with a thin `core/` for cross-cutting concerns:

```
lib/
├── core/
│   ├── network/    ApiClient (dio) — no auth interceptor yet, see HBM-8
│   ├── storage/    SecureTokenStorage
│   └── theme/      AppTheme, colors matching the course mockups
├── features/
│   ├── auth/       HBM-1 · HBM-8
│   ├── profile/    HBM-1 · HBM-9
│   ├── habits/     HBM-2 · HBM-10, HBM-11
│   ├── goals/      HBM-2 · HBM-12
│   ├── reminders/  HBM-3 · HBM-13, HBM-14
│   ├── tracking/   HBM-4 · HBM-15, HBM-16 (offline-first — the "cannot fail" loop)
│   └── progress/   HBM-5 · HBM-17, HBM-18
├── app.dart        MaterialApp.router + go_router config
└── main.dart        entrypoint
```

Each feature folder has its own short README pointing at its Jira epic/tickets — check there before starting one.

## Prerequisites

- Flutter 3.44.x (this repo was verified against 3.44.8, Dart 3.12.2)
- Chrome, if you want the quickest possible target (no extra install)
- **For a real Android build:** Android Studio + Android SDK (not required just to `analyze`/`test`/web-build)
- **For a real Windows desktop build:** Developer Mode enabled (Settings → Privacy & security → For developers) **and** the Visual Studio "Desktop development with C++" workload
- iOS builds require a Mac — not possible from Windows

## Running locally

Point the app at your local backend or the OpenAPI mock server (Prism, see `HBB-7`/`HBM` setup tickets):

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:4010
```

Swap `-d chrome` for `-d windows` or a connected Android device/emulator once their toolchains are set up (see Prerequisites). Run `flutter doctor -v` to see exactly what's missing on your machine.

## Tests

```bash
flutter analyze
flutter test
```

## CI

`bitbucket-pipelines.yml` runs `flutter analyze` + `flutter test` on every push (using the community `cirruslabs/flutter` image — double-check it still resolves the first time the pipeline runs).

## Status

Scaffold verified working: `flutter analyze` is clean, `flutter test` passes (1/1), and `flutter build web` succeeds end-to-end. Native platform folders (`android/`, `ios/`, `web/`, `windows/`) were generated via `flutter create .` — additive only, `lib/` untouched. No real screens or logic yet; that starts with the tickets in Jira epic `HBM-1` (Identity, Profile & Contract Foundation).

Note: `build_runner` is pinned to `^2.4.0` rather than the latest `2.15.x` — the newest `build_runner` and the newest `riverpod_generator` require incompatible `analyzer` versions of each other, so `pub get` fails above that if you bump it. Re-check this constraint next time you touch codegen deps.
