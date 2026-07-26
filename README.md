# HabitBuilder Mobile

Flutter client for HabitBuilder. HBM-7 establishes the feature-first
architecture, secure networking foundation and executable OpenAPI mock used by
the identity and profile tickets.

## Requirements

- Flutter 3.44.x with Dart 3.12+
- Node.js 18+

## Bootstrap

From PowerShell:

```powershell
.\scripts\bootstrap.ps1
```

The script validates Flutter 3.44.x, creates any missing native platform
runners in a temporary directory, installs packages, runs Riverpod code
generation, analyzes the project and executes the test suite.

Generated `*.g.dart` files are intentionally ignored. Regenerate them with:

```powershell
dart run build_runner build
```

## Mock API

Install Prism and start the server:

```powershell
npm install
npm run mock:api
```

In a second terminal:

```powershell
npm run mock:smoke
```

Both commands use `docs/openapi.yaml`. The smoke script covers the Phase 1
authentication and profile contract without requiring the backend.

## Run

For web or Windows:

```powershell
flutter run --dart-define=API_BASE_URL=http://localhost:4010
```

For an Android emulator:

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4010
```

## Architecture

```text
lib/
  core/
    config/
    network/
    router/
    storage/
    theme/
  features/
    auth/
    profile/
    goals/
    habits/
    progress/
    reminders/
    tracking/
```

Every feature boundary is organized as `domain`, `data` and `presentation`
when implementation is introduced. HBM-7 only supplies the shared foundation;
functional auth and profile code belongs to HBM-8 and HBM-9.

## Security

- Access and refresh tokens are stored only with `flutter_secure_storage`.
- The Dio interceptor attempts one refresh after a 401.
- Failed refresh clears the local session.
- HTTP logs omit headers, request bodies, response bodies and error payloads.
- Secrets and credentials must never be committed or printed.

## Changed-code coverage

After `flutter test --coverage`, enforce the ticket gate with:

```powershell
node scripts/check-changed-coverage.mjs --base main --min 80
```

Generated files and declarative application bootstrap files are excluded; all
remaining changed Dart logic is required to reach at least 80% line coverage.
