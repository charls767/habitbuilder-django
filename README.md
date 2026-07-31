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

## Prerequisites

- Flutter 3.44.x (this repo was verified against 3.44.8, Dart 3.12.2)
- Chrome, if you want the quickest possible target (no extra install)
- **For a real Android build:** Android Studio + Android SDK (not required just to `analyze`/`test`/web-build)
- **For a real Windows desktop build:** Developer Mode enabled (Settings → Privacy & security → For developers) **and** the Visual Studio "Desktop development with C++" workload
- iOS builds require a Mac — not possible from Windows
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

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:4010
```

Swap `-d chrome` for `-d windows` or a connected Android device/emulator once their toolchains are set up (see Prerequisites). Run `flutter doctor -v` to see exactly what's missing on your machine.

## Tests
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

To run against the real backend contract, start `habitbuilder-backend` and
use its local port instead of the Prism port:

```powershell
flutter run --dart-define=API_BASE_URL=http://localhost:8080
```

The mobile client sends the backend's `/v1` routes, stores the single session
token returned by login, and clears the local session on HTTP 401 because the
backend does not expose a refresh-token endpoint. Categories remain a local
frontend catalog because the backend stores `categoria` as a free-form value.

Scaffold verified working: `flutter analyze` is clean, `flutter test` passes (1/1), and `flutter build web` succeeds end-to-end. Native platform folders (`android/`, `ios/`, `web/`, `windows/`) were generated via `flutter create .` — additive only, `lib/` untouched. No real screens or logic yet; that starts with the tickets in Jira epic `HBM-1` (Identity, Profile & Contract Foundation).

Note: `build_runner` is pinned to `^2.4.0` rather than the latest `2.15.x` — the newest `build_runner` and the newest `riverpod_generator` require incompatible `analyzer` versions of each other, so `pub get` fails above that if you bump it. Re-check this constraint next time you touch codegen deps.
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

- The access token is stored only with `flutter_secure_storage`.
- The backend currently has no refresh-token endpoint; HTTP 401 clears the
  local session.
- HTTP logs omit headers, request bodies, response bodies and error payloads.
- Secrets and credentials must never be committed or printed.

## Changed-code coverage

After `flutter test --coverage`, enforce the ticket gate with:

```powershell
node scripts/check-changed-coverage.mjs --base main --min 80
```

Generated files and declarative application bootstrap files are excluded; all
remaining changed Dart logic is required to reach at least 80% line coverage.
