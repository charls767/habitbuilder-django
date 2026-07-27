# Phase 1 Verification

Date: 2026-07-26
Status: in progress

## Ticket Status

| Jira | Branch | Coverage | Pull request | Status |
| --- | --- | --- | --- | --- |
| HBM-7 | `HBM-9/scaffold-mock-server` | 95.06% | [#1](https://bitbucket.org/habit_builder/habitbuilder-mobile/pull-requests/1) | PASS |
| HBM-8 | `HBM-9/auth-screens` | 92.42% | [#2](https://bitbucket.org/habit_builder/habitbuilder-mobile/pull-requests/2) | PASS |
| HBM-9 | `HBM-9/profile-logout` | pending | pending | pending |

## HBM-7 Evidence

- Flutter 3.44.8 / Dart 3.12.2.
- Bootstrap, Riverpod code generation and analyze pass.
- 17 Flutter tests pass.
- Changed-code coverage is 95.06% (77/81).
- Web release build passes.
- Prism auth/profile contract smoke passes.
- Remote branch and PR exist.

Final integrated verification will run after plans 01-02 and 01-03.

## HBM-8 Evidence

- 18 focused auth tests and 35 tests in the full suite pass.
- Changed-code coverage against HBM-7 is 92.42% (390/422).
- Registration consent, field errors, generic credentials, suspension and both
  password-reset steps have automated coverage.
- Analyze, web release build and Prism smoke pass.
- Remote branch and stacked PR exist.
