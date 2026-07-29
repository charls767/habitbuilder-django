---
phase: 03-reminders
plan: "03"
subsystem: ui
tags: [flutter, riverpod, go_router, tdd, responsive, reminders]

requires:
  - phase: 03-reminders
    provides: Strict reminder domain/data boundary, executable contract and immutable HBM-13 baseline
provides:
  - Protected habit-scoped CU-006 route reachable from every habit
  - Riverpod reminder controller with shared eligibility and scoped invalidation
  - Responsive create, edit, toggle and delete reminder management
  - Widget semantics, preserved failure state and duplicate-write protection
affects: [03-04, HBM-13, HBM-14]

tech-stack:
  added: []
  patterns:
    - Controller and UI share one habit eligibility predicate
    - Reminder mutations preserve authoritative list state until repository success
    - Form controllers hydrate once and retain every field after validation or API failure

key-files:
  created:
    - lib/features/reminders/presentation/providers/reminder_providers.dart
    - lib/features/reminders/presentation/screens/reminders_screen.dart
    - lib/features/reminders/presentation/widgets/reminder_card.dart
    - lib/features/reminders/presentation/widgets/reminder_form_sheet.dart
    - test/features/reminders/presentation/reminder_controller_test.dart
    - test/features/reminders/presentation/reminders_screen_test.dart
  modified:
    - lib/features/habits/presentation/screens/habits_list_screen.dart
    - lib/core/router/app_routes.dart
    - lib/core/router/app_router.dart
    - test/app_test.dart

key-decisions:
  - "Create and inactive-to-active transitions use one shared habit eligibility predicate in controller and UI."
  - "Switches are not optimistic; the list invalidates only after repository success so failures retain authoritative state."
  - "Edit accepts the existing Recordatorio and sends a complete ReminderDraft, preserving active state and every writable field."
  - "Form state is initialized once and guarded locally plus in the controller to prevent duplicate writes."

patterns-established:
  - "Scoped mutation: every successful operation invalidates only remindersListProvider(habitId)."
  - "Responsive CU-006: expandable card content, wrapped day chips and scrollable layout remain usable at 320x640."

requirements-completed: [REMINDER-01, REMINDER-03, REMINDER-04, QUALITY-13, QUALITY-16, QUALITY-17]

duration: 25min
completed: 2026-07-29
---

# Phase 3 Plan 3: CU-006 Reminder Management Summary

**Protected, responsive CU-006 reminder management with eligibility-safe Riverpod mutations and authoritative failure handling**

## Performance

- **Duration:** 25 min
- **Started:** 2026-07-29T14:44:28Z
- **Completed:** 2026-07-29T15:09:53Z
- **Tasks:** 2
- **Files modified:** 10

## Accomplishments

- Added `/habits/:habitId/reminders` behind the existing authentication redirect and a per-habit reminder action.
- Added family data/repository/list providers and a controller that blocks create/reactivate for paused or completed habits before repository calls.
- Completed create, edit, toggle and confirmed delete flows without optimistic false success or cross-habit invalidation.
- Matched the CU-006 frame with a green summary, prominent time/message, day chips, switches, overflow actions and a dashed add action.
- Proved state preservation, duplicate-submit prevention, semantics and a no-overflow 320x640 layout.

## Task Commits

Both tasks followed RED then GREEN with atomic commits:

1. **Task 1 RED — controller, route and screen tracer:** `feb1037` (`test`)
2. **Task 1 RED — habit reminder navigation:** `cc62e1b` (`test`)
3. **Task 1 GREEN — route-to-create CU-006 tracer:** `59091b3` (`feat`)
4. **Task 2 RED — complete CU-006 behavior:** `c237408` (`test`)
5. **Task 2 GREEN — full reminder management:** `5c92cb4` (`feat`)

## Files Created/Modified

- `lib/features/reminders/presentation/providers/reminder_providers.dart` — typed providers, shared eligibility and mutation controller.
- `lib/features/reminders/presentation/screens/reminders_screen.dart` — CU-006 state composition and mutation feedback.
- `lib/features/reminders/presentation/widgets/reminder_card.dart` — responsive semantic card, switch and overflow actions.
- `lib/features/reminders/presentation/widgets/reminder_form_sheet.dart` — create/edit validation with one-time hydration and preserved failures.
- `lib/features/habits/presentation/screens/habits_list_screen.dart` — direct reminder action per habit.
- `lib/core/router/app_routes.dart` — encoded habit reminder route helper.
- `lib/core/router/app_router.dart` — protected reminder route registration.
- `test/features/reminders/presentation/reminder_controller_test.dart` — eligibility, full-shape mutation, failure and duplicate-lock coverage.
- `test/features/reminders/presentation/reminders_screen_test.dart` — CRUD states, degraded eligibility, semantics and 320px evidence.
- `test/app_test.dart` — route protection and habit-action navigation evidence.

Ignored Riverpod outputs were regenerated locally with the pinned Dart SDK, including `reminder_providers.g.dart`; generated files remain ignored per repository convention.

## Decisions Made

- Shared `canActivateReminders` between controller and UI so eligibility cannot be bypassed by presentation-only checks.
- Kept edit available for active reminders on paused/completed habits; only inactive-to-active transitions require eligibility.
- Avoided optimistic switch or delete state. Repository success precedes scoped list invalidation and visible removal.
- Used a full `ReminderDraft` for edit/toggle so message, wall-clock time and weekdays cannot be discarded.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Kept the auto-dispose controller alive during form mutations**

- **Found during:** Task 1 GREEN create widget test.
- **Issue:** Reading the family notifier without watching its state allowed Riverpod to dispose it across the async repository gap.
- **Fix:** The form watches `reminderControllerProvider(habitId)` while mounted.
- **Files modified:** `lib/features/reminders/presentation/screens/reminders_screen.dart` (later extracted to `reminder_form_sheet.dart`).
- **Verification:** Create and duplicate-pending widget tests complete without `UnmountedRefException`.
- **Committed in:** `59091b3`

**2. [Rule 3 - Blocking] Avoided the inherited AsyncNotifier update method collision**

- **Found during:** Task 2 RED compilation.
- **Issue:** `AsyncNotifier` already exposes an `update` method with an incompatible callback signature.
- **Fix:** Named the public domain operation `updateReminder`, preserving clear controller semantics without shadowing framework API.
- **Files modified:** `lib/features/reminders/presentation/providers/reminder_providers.dart`, controller and widget tests.
- **Verification:** All controller and widget suites compile and pass.
- **Committed in:** `5c92cb4`

---

**Total deviations:** 2 auto-fixed (1 Rule 1 bug, 1 Rule 3 blocking issue).
**Impact on plan:** Both changes preserve the planned architecture and scope while making async mutations reliable under Riverpod 3.

## Authentication Gates

None.

## Known Stubs

None.

## Verification

- Riverpod codegen with the pinned Dart SDK — PASS; ignored generated output refreshed.
- Focused reminder/router suites — PASS, 26/26.
- Full `flutter test --coverage --no-pub` — PASS, 186/186.
- Measurable changed production coverage from HBM-13 `startSha` — 585/619, 94.51%.
- Coverage helper unit suite — PASS, 9/9.
- `dart format --output=none --set-exit-if-changed` over all plan paths — PASS.
- `flutter analyze --no-pub` — PASS, no issues.
- `flutter build web --release --no-pub` — PASS, including Wasm dry run.
- D-15 root/branch/stash/CMake guard — PASS before and after each task.
- Protected CMake SHA-256 — `C6C0F0C5E484A957961E8653DC9A19A240B799B9FCD7D1120D7FF7D0F2F23AFE`.
- Scope and protected-commit scan — PASS; all 03-03 commits contain only the ten planned paths.
- Stub scan and `git diff --check` — PASS.

## Issues Encountered

- The branch-wide `coverage:changed` CLI reports changed test files and the pure `ReminderRepository` interface as missing LCOV records. Flutter's LCOV output does not instrument test files or zero-executable-line interfaces. The same run measured covered production code at 94.51%, and all 186 tests passed. The helper is outside 03-03's authorized paths; 03-04 owns delivery-gate reconciliation.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- HBM-13 CU-006 implementation is complete and ready for 03-04 delivery gates.
- 03-04 should reconcile the strict LCOV changed-path classification before publication.
- No PR was opened and no 03-04 implementation work was started.

## Self-Check: PASSED

All declared key files exist, and commits `feb1037`, `cc62e1b`, `59091b3`, `c237408` and `5c92cb4` resolve in repository history.

---
*Phase: 03-reminders*
*Completed: 2026-07-29*
