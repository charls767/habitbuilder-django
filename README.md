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

## ⚠️ One-time setup required

This project was scaffolded **without** the Flutter CLI available (not installed on the machine that generated it) — `pubspec.yaml`, `lib/`, and `test/` are hand-authored and correct, but the native platform runners are missing. Before you can `flutter run` this, do once per machine:

```bash
flutter create . --project-name habitbuilder_mobile --org com.habitbuilder
flutter pub get
```

`flutter create .` on an existing project only **adds** the missing `android/`, `ios/`, etc. folders — it will not touch `lib/`, `pubspec.yaml`, or anything already there.

## Running locally

Point the app at your local backend or the OpenAPI mock server (Prism, see `HBB-7`/`HBM` setup tickets):

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:4010
```

## Tests

```bash
flutter analyze
flutter test
```

## CI

`bitbucket-pipelines.yml` runs `flutter analyze` + `flutter test` on every push (using the community `cirruslabs/flutter` image — double-check it still resolves the first time the pipeline runs).

## Status

Initial scaffold only — dependencies, folder structure, theme, and a placeholder screen. No real screens or logic yet; that starts with the tickets in Jira epic `HBM-1` (Identity, Profile & Contract Foundation).
