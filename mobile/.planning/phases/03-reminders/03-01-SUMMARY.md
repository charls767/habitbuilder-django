---
phase: 03-reminders
plan: "01"
subsystem: testing
tags: [openapi, prism, lcov, nodejs, reminders]

requires:
  - phase: 02-habits-and-goals
    provides: Habit and goal contract plus the existing Prism smoke conventions
provides:
  - Immutable HBM-13 baseline with protected CMake and stash evidence
  - Fail-closed changed-Dart LCOV coverage gate
  - Executable reminder contract for multiple reminders per habit
  - Self-contained Prism readiness, smoke and process-tree cleanup gate
affects: [03-02, 03-03, 03-04, HBM-13, HBB-23]

tech-stack:
  added: []
  patterns:
    - Behavior-first Node test fixtures around CLI exit codes
    - Dependency-injected process lifecycle with owned PID-tree cleanup

key-files:
  created:
    - .planning/phases/03-reminders/03-HBM-13-BASE.json
    - scripts/run-mock-gate.mjs
    - scripts/run-mock-gate.test.mjs
  modified:
    - docs/openapi.yaml
    - package.json
    - scripts/check-changed-coverage.mjs
    - scripts/check-changed-coverage.test.mjs
    - scripts/mock-smoke.mjs

key-decisions:
  - "Changed Dart paths missing from LCOV or reporting zero measurable lines are fatal, even when aggregate coverage would otherwise pass."
  - "The mock gate spawns Prism directly under one captured PID and always awaits process-tree cleanup in finally."
  - "Reminder create/update payloads require mensaje, strict HH:mm, unique ISO weekdays 1..7 and activo."

patterns-established:
  - "Coverage gate: excluded generated paths may be absent, but every eligible changed Dart path must have measurable LCOV."
  - "Mock ownership: readiness precedes smoke, and every timeout/spawn/smoke outcome converges through finally cleanup."

requirements-completed: [REMINDER-01, QUALITY-15, QUALITY-16, QUALITY-18]

duration: 13min
completed: 2026-07-29
---

# Phase 3 Plan 1: Reminder Contract and Quality Gates Summary

**Immutable HBM-13 evidence, strict changed-code LCOV enforcement, and a self-cleaning Prism reminder lifecycle gate**

## Performance

- **Duration:** 13 min
- **Started:** 2026-07-29T13:59:02Z
- **Completed:** 2026-07-29T14:12:35Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments

- Captured `startSha`, `originMainSha`, branch, root, CMake SHA-256 and stash object before production edits.
- Made missing LCOV paths, zero measurable lines and coverage below 80.00% fail with explicit offending-path diagnostics.
- Added `mensaje`, strict 24-hour `hora`, and unique/ranged ISO weekday constraints to reminder response and request schemas.
- Added one `mock:gate` owner for Prism startup, bounded readiness, reminder smoke and awaited PID-tree cleanup.
- Proved port 4010 is released after both a successful smoke and a forced smoke failure.

## Task Commits

Each task followed RED then GREEN with atomic commits:

1. **Task 1 RED — immutable baseline and coverage fixtures:** `c4aa5cb` (`test`)
2. **Task 1 GREEN — fail-closed coverage helper:** `7fe1ef0` (`feat`)
3. **Task 2 RED — Prism lifecycle behavior:** `c555124` (`test`)
4. **Task 2 GREEN — reminder contract and mock owner:** `a50af89` (`feat`)

## Files Created/Modified

- `.planning/phases/03-reminders/03-HBM-13-BASE.json` — immutable HBM-13 safety and PR-base evidence.
- `scripts/check-changed-coverage.mjs` — strict changed-path discovery, LCOV matching and 80.00% enforcement.
- `scripts/check-changed-coverage.test.mjs` — CLI fixtures for missing, zero-line, below/exact/above-threshold and generated exclusions.
- `docs/openapi.yaml` — multiple-reminder examples and constrained `Recordatorio`/`RecordatorioRequest`.
- `scripts/mock-smoke.mjs` — list/create/edit/deactivate reminder lifecycle.
- `scripts/run-mock-gate.mjs` — Prism owner with readiness timeout and awaited process-tree termination.
- `scripts/run-mock-gate.test.mjs` — success, timeout, spawn failure, smoke failure and cleanup tests.
- `package.json` — `mock:gate` command.

## Decisions Made

- A structurally incomplete coverage report cannot be rescued by aggregate percentage; missing and zero-line paths fail first.
- Generated `.g.dart`/`.freezed.dart` paths remain excluded and do not create false zero-line failures.
- Prism is spawned directly with Node instead of through an npm wrapper so the captured PID is the owned mock process.
- Reminder PATCH uses the same complete request shape as create, preserving fields during edit or deactivation.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Made the mock-gate module safe to import without `process.argv[1]`**

- **Found during:** Task 2 real smoke-failure cleanup verification.
- **Issue:** Importing `run-mock-gate.mjs` from `node --input-type=module -e` evaluated `pathToFileURL(undefined)` before Prism started.
- **Fix:** Guarded the direct-entry comparison with `process.argv[1]`.
- **Files modified:** `scripts/run-mock-gate.mjs`
- **Verification:** The forced smoke exited with code 7 for the intended reason and port 4010 remained free.
- **Committed in:** `a50af89`

**2. [Rule 3 - Blocking] Reconciled GSD state after locale-incompatible SDK handlers**

- **Found during:** Plan close-out.
- **Issue:** `state.advance-plan` and `state.update-progress` could not parse the Spanish `Plan: 03-01 de 03-08` / `Progress v3.0` fields, while the metric handler placed its row outside the performance table.
- **Fix:** Used the supported flag-based handlers for metrics, decisions and session data, then reconciled the localized current-position/progress fields and metric table directly.
- **Files modified:** `.planning/STATE.md`
- **Verification:** STATE points to `03-02`, Phase 3 reports 1/8 and 13%, and no metric row remains in Deferred Items.
- **Committed in:** Plan metadata commit.

---

**Total deviations:** 2 auto-fixed (1 Rule 1 bug, 1 Rule 3 blocking issue).
**Impact on plan:** Both fixes were required for truthful failure-path verification and atomic GSD close-out; product scope did not expand.

## Authentication Gates

None.

## Known Stubs

None.

## Verification

- `node --test scripts/run-mock-gate.test.mjs` — PASS, 5/5.
- `npm run test:coverage-script` — PASS, 9/9.
- `npm run mock:gate` — PASS; reminder list/create/edit/deactivate smoke completed.
- Forced smoke child exit 7 — expected failure; port 4010 remained free.
- D-15 guard — PASS; root, branch, stash object and CMake SHA-256 match the baseline.
- Ticket diff/staging guard — PASS; `windows/flutter/generated_plugins.cmake` is absent from every `03-01` commit and staging.
- Stub scan and `git diff --check` — PASS.

## Issues Encountered

None beyond the auto-fixed import guard documented above.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

The HBM-13 contract and reusable quality gates are ready for `03-02`. No work from `03-02` was started.

## Self-Check: PASSED

All declared created files exist, and commits `c4aa5cb`, `7fe1ef0`, `c555124` and `a50af89` resolve in repository history.

---
*Phase: 03-reminders*
*Completed: 2026-07-29*
