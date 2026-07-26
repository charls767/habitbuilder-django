# HBM-7 Verification

Date: 2026-07-26
Branch: `HBM-9/scaffold-mock-server`
Pull request: https://bitbucket.org/habit_builder/habitbuilder-mobile/pull-requests/1

## Jira Criteria

| Criterion | Evidence | Result |
| --- | --- | --- |
| Flutter 3.44.x | Flutter 3.44.8 / Dart 3.12.2 | PASS |
| Feature-first structure | Core plus documented feature boundaries | PASS |
| Riverpod code generation | Four generated providers; build_runner succeeds | PASS |
| go_router | Minimal HBM-7 router without auth/profile implementation | PASS |
| Dio/JWT | Access token, one refresh, retry and session cleanup | PASS |
| Secure storage | Access/refresh tokens only through FlutterSecureStorage | PASS |
| OpenAPI + Prism | Phase 1 contract and auth/profile smoke | PASS |
| Flutter runners | Android, iOS, web and Windows present | PASS |

## Automated Gates

```text
scripts/bootstrap.ps1                         PASS
flutter analyze                               PASS
flutter test --coverage                       PASS (17 tests)
changed-code coverage vs main                 PASS (95.06%, 77/81)
flutter build web --release                   PASS
node --test check-changed-coverage.test.mjs   PASS (3 tests)
npm run mock:smoke                            PASS
```

## Scope Audit

The PR contains infrastructure and feature-boundary documentation only.
Functional auth/profile code and implementations for goals, habits, reminders,
tracking and progress are absent. The safety stash remains available for the
next plans.
