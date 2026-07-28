---
phase: 2
slug: habits-goals
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-28
---

# Phase 2 — Validation Strategy

> Contrato de validación por fase para HBM-10, HBM-11 y HBM-12.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Flutter test (`flutter_test`) + mocktail 1.0.5 + Node test runner |
| **Config file** | `pubspec.yaml`, `analysis_options.yaml`, `scripts/check-changed-coverage.mjs` |
| **Quick run command** | `flutter test <rutas-focalizadas-del-ticket>` |
| **Full suite command** | `flutter test --coverage` |
| **Changed-code gate** | `node scripts/check-changed-coverage.mjs --base <base-real-del-PR> --lcov coverage/lcov.info --min 80` |
| **Estimated runtime** | Quick <30 seconds; full suite + coverage <60 seconds |

Prism uses `docs/openapi.yaml` through `npm run mock:api`; its accepted smoke
command is `npm run mock:smoke`. On 2026-07-28 the mobile/backend OpenAPI
SHA-256 matched and the Phase 1 + habits/goals smoke passed.

---

## Sampling Rate

- **Después de cada task commit:** Run the task's focused `<automated>` command.
- **Después de cada plan wave:** Run `flutter analyze` and `flutter test --coverage`.
- **Antes de publicar cada PR:** Run focused tests, full coverage, changed-code
  coverage against the real PR base, web release build and Prism smoke.
- **Antes de `$gsd-verify-work`:** Reconstruct the integrated stack and repeat
  the full suite/gates.
- **Max feedback latency:** 60 seconds for every focused test command.

---

## Dependency and Delivery Graph

| Plan | Needs | Creates | Wave | Checkpoint |
|------|-------|---------|------|------------|
| 02-01 / HBM-10 | Phase 1; HBB-16 commit `6d12e8e`; concurrent owner handoffs | Habit contracts, CRUD UI, branch/PR/Jira evidence | 1 | None; auth gates are dynamic |
| 02-02 / HBM-11 | 02-01 final pushed revision | Confirmed pause/complete/delete, branch/PR/Jira evidence | 2 | None; auth gates are dynamic |
| 02-03 / HBM-12 | 02-02 final pushed revision | Goal contracts/UI/linking, branch/PR/Jira evidence | 3 | None; auth gates are dynamic |

The waves are sequential because the plans intentionally overlap on
`HabitRepository`, habit providers/screens and then router/navigation. No
same-wave file conflict exists.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 02-01-01 | 01 | 1 | HABIT-03, HABIT-07 | T-02-01..03 | Typed contract; no client auth shortcut | unit/data | `flutter test test/features/habits/domain/frecuencia_test.dart test/features/habits/data/habito_dto_test.dart test/features/habits/data/habit_repository_impl_test.dart` | ❌ W0 | ⬜ pending |
| 02-01-02 | 01 | 1 | HABIT-01, HABIT-02 | T-02-03..04 | Resilient forms; duplicate submit blocked | widget/controller | `flutter test test/features/habits/presentation/habits_controller_test.dart test/features/habits/presentation/habits_screens_test.dart test/app_test.dart` | ❌ W0 | ⬜ pending |
| 02-01-03 | 01 | 1 | QUALITY-07..12, DELIVERY-04 | T-02-05, T-02-SC | Isolated diff and intact stash | integrated/delivery | `flutter test --coverage` + changed-code gate with `origin/main` | Existing gate | ⬜ pending |
| 02-02-01 | 02 | 2 | HABIT-04, HABIT-05, HABIT-06 | T-02-07..08 | Contract-accurate mutations; server authorization | data | `flutter test test/features/habits/data/habit_lifecycle_repository_test.dart` | ❌ W0 | ⬜ pending |
| 02-02-02 | 02 | 2 | HABIT-04, HABIT-05, HABIT-06 | T-02-06, T-02-09..10 | Cancel makes zero calls; errors preserve state | widget/controller | `flutter test test/features/habits/presentation/habit_lifecycle_controller_test.dart test/features/habits/presentation/habit_lifecycle_dialogs_test.dart` | ❌ W0 | ⬜ pending |
| 02-02-03 | 02 | 2 | QUALITY-07..12, DELIVERY-05 | T-02-SC | Real stacked/merged base and isolated diff | integrated/delivery | `flutter test --coverage` + changed-code gate with resolved HBM-10/main base | Existing gate | ⬜ pending |
| 02-03-01 | 03 | 3 | GOAL-01, GOAL-02, GOAL-03, GOAL-04 | T-02-11..14 | Allowed fields only; server-owned linking | unit/data | `flutter test test/features/goals/data/meta_dto_test.dart test/features/goals/data/goal_repository_impl_test.dart` | ❌ W0 | ⬜ pending |
| 02-03-02 | 03 | 3 | GOAL-01, GOAL-02, GOAL-03, GOAL-04 | T-02-12..15 | Independent status; authoritative link refresh | widget/controller | `flutter test test/features/goals/presentation` | ❌ W0 | ⬜ pending |
| 02-03-03 | 03 | 3 | QUALITY-07..12, DELIVERY-06 | T-02-SC | No progress surface; isolated final diff | integrated/delivery | `flutter test --coverage` + changed-code gate with resolved HBM-11/main base | Existing gate | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

The test runner, coverage generator, changed-code script, Prism dependency and
pipeline already exist. Each production task is marked `tdd="true"` and must
create these missing tests before implementation:

- [ ] `test/features/habits/domain/frecuencia_test.dart`
- [ ] `test/features/habits/data/habito_dto_test.dart`
- [ ] `test/features/habits/data/habit_repository_impl_test.dart`
- [ ] `test/features/habits/presentation/habits_controller_test.dart`
- [ ] `test/features/habits/presentation/habits_screens_test.dart`
- [ ] `test/features/habits/data/habit_lifecycle_repository_test.dart`
- [ ] `test/features/habits/presentation/habit_lifecycle_controller_test.dart`
- [ ] `test/features/habits/presentation/habit_lifecycle_dialogs_test.dart`
- [ ] `test/features/goals/data/meta_dto_test.dart`
- [ ] `test/features/goals/data/goal_repository_impl_test.dart`
- [ ] `test/features/goals/presentation/goals_controller_test.dart`
- [ ] `test/features/goals/presentation/goals_screens_test.dart`
- [ ] `test/features/goals/presentation/habit_link_selector_test.dart`

No dependency installation or package legitimacy checkpoint is required.

---

## Ticket Coverage and Delivery Gates

| Ticket | Exact branch | Initial PR base | Jira start | Jira after PR | Coverage base |
|--------|--------------|-----------------|------------|---------------|---------------|
| HBM-10 | `HBM-10/habit-crud` | `main` | Already En curso | Transition 31 → En revisión | `origin/main` |
| HBM-11 | `HBM-11/habit-lifecycle` | HBM-10 while stacked; otherwise `main` | Transition 21 → En curso | Transition 31 → En revisión | Resolved remote PR base |
| HBM-12 | `HBM-12/goals-linking` | HBM-11 while stacked; otherwise `main` | Transition 21 → En curso | Transition 31 → En revisión | Resolved remote PR base |

Transition 41 (`Listo`) is reserved for merged work. Each PR description and
Jira evidence must include focused/full commands, test count, changed-code
percentage, web build result, Prism result and dependency/base.

Required gate sequence per ticket:

1. `flutter test <rutas-focalizadas-del-ticket>`
2. `flutter analyze`
3. `flutter test --coverage`
4. `node scripts/check-changed-coverage.mjs --base <base-real-del-PR> --lcov coverage/lcov.info --min 80`
5. `flutter build web --release`
6. `npm run mock:smoke`
7. `git diff --check`
8. `git diff <base-real-del-PR>...HEAD --name-status`
9. Verify remote branch, exactly one PR and Jira En revisión.
10. Verify `stash@{0}` still exists and was not applied, popped or dropped.

---

## Contract Decisions and Resolved Tensions

- HBB-16 is satisfied by backend commit `6d12e8e` and PR #1. The mobile
  contract is an identical executable copy and Prism smoke passes.
- HBB-16's response schema includes a read-only derived goal field. Locked
  decision D-07 has authority over the mobile surface: `MetaDto` reads only
  id/name/description/date/status/habit ids, and domain/UI/tests contain no
  field, percentage, metric, graph or calculation for that derived value.
- `resumeHabit`, `deleteGoal`, reminder, tracking and progress operations in
  the broad OpenAPI document are not Phase 2 requirements. Their exclusion is
  a scope boundary, not a missing plan item.
- Ownership is enforced by the backend. The client offers resources returned
  by authenticated endpoints but never treats local filtering as an
  authorization control.

---

## Multi-Source Coverage Audit

| SOURCE | ID | Feature/Requirement | Plan | Status | Notes |
|--------|----|---------------------|------|--------|-------|
| GOAL | — | Authenticated user manages habits/goals, confirmed lifecycle and links without deferred domains | 02-01..03 | COVERED | Three sequential vertical ticket slices |
| REQ | HABIT-01 | Own habit list/detail | 02-01 | COVERED | Query + loading/empty/error/detail tests |
| REQ | HABIT-02 | Resilient create/edit | 02-01 | COVERED | Form/controller/widget tests |
| REQ | HABIT-03 | Three valid frequency variants | 02-01 | COVERED | Sealed union + unit/data/widget tests |
| REQ | HABIT-04 | Confirmed pause | 02-02 | COVERED | Cancel/confirm/error tests |
| REQ | HABIT-05 | Confirmed complete | 02-02 | COVERED | Cancel/confirm/error tests |
| REQ | HABIT-06 | Confirmed delete with records/reports warning | 02-02 | COVERED | Explicit dialog copy + post-204 removal |
| REQ | HABIT-07 | Optional category and one optional goal | 02-01 | COVERED | Authenticated lookups + nullable selection |
| REQ | GOAL-01 | Own goal list/detail without progress | 02-03 | COVERED | Allowed fields only + negative UI gate |
| REQ | GOAL-02 | Resilient goal create/edit | 02-03 | COVERED | Form/controller/widget tests |
| REQ | GOAL-03 | Four independent goal states | 02-03 | COVERED | `lograda` ↔ Alcanzada and zero habit mutations |
| REQ | GOAL-04 | Link/unlink zero/one/many habits, max one goal each | 02-03 | COVERED | PUT/DELETE diff and authoritative refresh |
| REQ | QUALITY-07 | Unit/data and widget tests per ticket | 02-01..03 | COVERED | TDD tasks and focused suites |
| REQ | QUALITY-08 | Changed-code coverage >=80.00% | 02-01..03 | COVERED | Real PR base per ticket |
| REQ | QUALITY-09 | Analyze exit 0 | 02-01..03 | COVERED | Per-task and per-ticket gates |
| REQ | QUALITY-10 | Full suite with coverage | 02-01..03 | COVERED | Per-ticket and integrated gates |
| REQ | QUALITY-11 | Web release build | 02-01..03 | COVERED | Delivery task in every plan |
| REQ | QUALITY-12 | Accepted HBB-16 + Prism smoke | 02-01..03 | COVERED | Gate pinned in 02-01; repeated every ticket |
| REQ | DELIVERY-04 | One HBM-10 branch/PR | 02-01 | COVERED | Exact branch, PR title/base, Jira flow |
| REQ | DELIVERY-05 | One HBM-11 branch/PR | 02-02 | COVERED | Exact branch, dynamic stack base, Jira flow |
| REQ | DELIVERY-06 | One HBM-12 branch/PR | 02-03 | COVERED | Exact branch, dynamic stack base, Jira flow |
| RESEARCH | — | No `02-RESEARCH.md` | 02-01..03 | N/A | Level 0: no new dependency; existing Phase 1 patterns and accepted OpenAPI fully determine implementation |
| CONTEXT | Gate HBB-16 | Accepted CRUD/frequency/category/lifecycle/link contract and smoke | 02-01 | COVERED | Commit `6d12e8e`, PR #1, identical hash, passing smoke |
| CONTEXT | D-01 | Exactly 02-01 → 02-02 → 02-03 | All | COVERED | Waves 1/2/3 and explicit dependencies |
| CONTEXT | D-02 | Exact branch names | All | COVERED | Branch contract in every plan |
| CONTEXT | D-03 | One PR, atomic commits, evidence; stacking allowed | All | COVERED | Delivery task in every plan |
| CONTEXT | D-04 | Feature-first, Riverpod, go_router, Dio | All | COVERED | Existing architecture reused |
| CONTEXT | D-05 | Client presents contract; no backend invariants/auth | All | COVERED | Repository/data and threat mitigations |
| CONTEXT | D-06 | Hábitos del día means definitions, not check-ins | 02-01 | COVERED | UI/tests explicitly exclude daily activity |
| CONTEXT | D-07 | Goal status/date only; no progress | 02-03 | COVERED | Structural omission + negative source gate |
| CONTEXT | D-08 | Safety stash is inspect-only | All | COVERED | Branch/delivery guards |
| CONTEXT | D-09 | Selective stash content must be reconstructed/reviewed | All | COVERED | Plans prohibit restoration; current handoffs adopted in place |
| CONTEXT | D-10 | Unit/data and widget tests per ticket | All | COVERED | TDD behaviors and validation map |
| CONTEXT | D-11 | Changed-code coverage >=80.00% | All | COVERED | Ticket-specific real base |
| CONTEXT | D-12 | Focused/full/analyze/build/smoke/push/PR | All | COVERED | Delivery task and gate sequence |

Deferred reminders, notifications scheduling, tracking, check-ins, streaks,
completion records, progress, metrics, reports, backend logic and bulk stash
restoration are intentionally excluded and therefore are not source-audit gaps.

---

## Manual-Only Verifications

All required functional behaviors have automated unit/data/widget or API smoke
coverage. Human PR review and conversational UAT remain useful but are not the
only proof for any requirement.

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verification.
- [x] Sampling continuity has no three consecutive tasks without automation.
- [x] Wave 0 names every missing test and each TDD task creates tests first.
- [x] No watch-mode flags appear.
- [x] Focused feedback commands target <60 seconds.
- [ ] All Wave 0 test files exist.
- [ ] Every focused and full gate is green.
- [ ] `nyquist_compliant: true` is set after execution evidence is complete.

**Approval:** pending execution
