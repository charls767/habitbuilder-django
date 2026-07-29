---
phase: 3
slug: reminders
status: planned
nyquist_compliant: true
wave_0_complete: false
created: 2026-07-29
plans: [03-01, 03-02, 03-03, 03-04, 03-05, 03-06, 03-07, 03-08]
requirements: [REMINDER-01, REMINDER-02, REMINDER-03, REMINDER-04, REMINDER-05, QUALITY-13, QUALITY-14, QUALITY-15, QUALITY-16, QUALITY-17, QUALITY-18, DELIVERY-07, DELIVERY-08]
decisions: [D-01, D-02, D-03, D-04, D-05, D-06, D-07, D-08, D-09, D-10, D-11, D-12, D-13, D-14, D-15, D-16]
---

# Phase 3 — Validation Strategy

## Eight-Plan Sequential Graph

| Wave | Plan | Ticket | Root | Needs | Produces |
|---|---|---|---|---|---|
| 1 | 03-01 | HBM-13 | primary | Phase 2/main | immutable base, tooling, contract |
| 2 | 03-02 | HBM-13 | primary | 03-01 | domain/data |
| 3 | 03-03 | HBM-13 | primary | 03-02 | CU-006/controller |
| 4 | 03-04 | HBM-13 | primary | 03-03 | exact product tip, PR/merge, local metadata |
| 5 | 03-05 | HBM-14 | isolated | 03-04 | worktree/base, D-16 helpers, pure planner |
| 6 | 03-06 | HBM-14 | isolated | 03-05 | native/no-op adapters and native config |
| 7 | 03-07 | HBM-14 | isolated | 03-06 | reconciliation and triggers |
| 8 | 03-08 | HBM-14 | isolated + primary metadata | 03-07 | exact product tip, PR/merge, final metadata |

Dependencies are acyclic and strictly sequential. Plans create exactly two
product branches and two PRs:

- `HBM-13/reminder-ui`
- `HBM-14/local-notifications`

No metadata branch or replacement PR is permitted.

## Manual Worktree Protocol

`.planning/config.json` fixes `workflow.use_worktrees=false`. This is a runtime
constraint, not an invitation for the orchestrator to select another root.

1. Execute 03-01..04 with cwd exactly
   `C:\Users\USER\Desktop\DPPF\HabitBuilder\habitbuilder-mobile`.
2. After 03-04 proves HBM-13 `productTipSha` merged into fetched `origin/main`,
   fetch from the primary root and fail if the isolated path, local HBM-14
   branch, or remote HBM-14 branch already exists unexpectedly.
3. Run:
   `git worktree add -b HBM-14/local-notifications C:\Users\USER\Desktop\DPPF\HabitBuilder\habitbuilder-mobile-hbm14 origin/main`.
4. Assert the isolated root, branch and HEAD=`origin/main`; launch every
   03-05..08 executor with cwd exactly that isolated root. Executors read plans
   and prior handoffs by absolute primary-root path when necessary.
5. Write/version every HBM-14 `SUMMARY.md` and every post-merge handoff through
   absolute paths under the primary root so the orchestrator detects them.
   Metadata commits remain on local primary `main`; never push them.
6. Before final local metadata after HBM-14 merge, merge fetched `origin/main`
   into local primary `main` without stash/autostash. Preserve existing local
   metadata commits and the protected dirty CMake file.

Every step is fail-closed: a root/branch/ancestry mismatch halts before mutation.

## Product Tip Versus Metadata Commits

For each ticket:

1. `startSha` is captured before ticket mutation and drives diff/coverage.
2. All product, test and tooling commits complete.
3. `productTipSha=git rev-parse HEAD` is captured once; no later commit is
   allowed on the product branch.
4. Push exactly
   `git push origin "$productTipSha`:refs/heads/<ticket-branch>"`.
5. `git ls-remote` and Bitbucket `source.commit.hash` must both equal
   `productTipSha`. Exactly one PR targets `main`.
6. Merge that same PR with `merge_commit`; fetch and require
   `git merge-base --is-ancestor <productTipSha> origin/main`.
7. Only after ancestry succeeds, write SUMMARY/handoff from primary-root local
   `main`. The first metadata commit is `metadataTipSha`; a second local record
   commit may persist it as `metadataRecordSha`.
8. Assert the remote product branch still equals `productTipSha`, remote main
   contains it, `metadataPublished=false`, and neither metadata SHA was pushed.

This preserves PR source identity while allowing orchestration-visible evidence.

## D-15 Safety Guard

| Field | Required value |
|---|---|
| Primary root | `C:\Users\USER\Desktop\DPPF\HabitBuilder\habitbuilder-mobile` |
| HBM-13 branch | `HBM-13/reminder-ui` |
| Isolated root | `C:\Users\USER\Desktop\DPPF\HabitBuilder\habitbuilder-mobile-hbm14` |
| HBM-14 branch | `HBM-14/local-notifications` |
| Protected path | `windows/flutter/generated_plugins.cmake` |
| Protected SHA-256 | `C6C0F0C5E484A957961E8653DC9A19A240B799B9FCD7D1120D7FF7D0F2F23AFE` |
| Stash ref/object | `stash@{0}` / `a6764834f136258ef8c971f6e206f4110e81dee6` |

Before/after every task assert root, branch, protected hash and stash object.
Fail if the protected path appears in branch diff, staged paths or ticket
commits. Never apply, pop, drop, rewrite or autostash the stash. Never stage
broadly.

## Fail-Closed Test Infrastructure

All command lists use `&&` (`&amp;&amp;` in PLAN XML) or explicit
`$LASTEXITCODE`/exception checks after every command. No verify relies on the
exit code of only its final command.

| Gate | Command/owner |
|---|---|
| Coverage helper | `npm run test:coverage-script` |
| Prism lifecycle | `node --test scripts/run-mock-gate.test.mjs && npm run mock:gate` |
| HBM-13 focused | `flutter test --no-pub test/features/reminders` |
| HBM-14 focused | explicit domain/application/infrastructure test paths |
| Analyze/full suite | `flutter analyze` and `flutter test --coverage` chained |
| Changed coverage | `node scripts/check-changed-coverage.mjs --base <startSha> --lcov coverage/lcov.info --min 80` |
| Web | `flutter build web --release` |
| Android | `powershell -NoProfile -File scripts/run-android-reminder-acceptance.ps1` |
| D-16 | tested `verify-reminder-package-gate.mjs pre/post` |
| Boundaries | tested `check-reminder-boundaries.mjs` |

The HBM-14 boundary helper fails on:

- `flutter_local_notifications` imports in domain, application, presentation
  or tests;
- any `.cancelAll(` use in reminder code;
- `DateTime.now()`, `TZDateTime.local()` or `.toLocal()` in scheduling code;
- missing/erroring `rg`.

The only managed payload prefix is the exact literal
`habit-reminder:v1:`. Static scans fail if any reminder payload omits that exact
versioned prefix in source, tests, scripts or Phase 3 planning artifacts.

## D-16 Automated Package Gate

The tested helper is used twice around mutation:

### Pre

- Query exact official HTTPS version APIs for
  `flutter_local_notifications` 22.2.0 and `timezone` 0.11.1.
- Validate exact names/versions and exact HTTPS archive URLs.
- Require FLN `homepage` exactly
  `https://github.com/MaikuB/flutter_local_notifications/tree/master/flutter_local_notifications`
  and official `repository == null`.
- Require timezone `repository` exactly
  `https://github.com/dart-lang/labs/tree/main/pkgs/timezone` and official
  `homepage == null`.
- Persist `checkedAtUtc`, API responses, canonical `sourceUrl` and before
  hashes for pubspec/lock.

### Post

- Require `checkedAtUtc < mutationStartedAtUtc` and both timestamps UTC.
- Require pubspec and lockfile resulting mtimes/hashes after mutation start.
- Require exact direct pins and exact resolved lock versions.
- Revalidate evidence schema/URLs; any mismatch exits non-zero.

The pre helper must pass before `pubspec.yaml` mutation; the post helper must
pass immediately after `pub get` and in every later HBM-14 delivery verify.

## Per-Task Nyquist Map

| Task | Requirements | Automated evidence |
|---|---|---|
| 03-01-01 | QUALITY-15/16 | coverage-helper tests + D-15 guard |
| 03-01-02 | REMINDER-01, QUALITY-18 | Prism lifecycle tests + mock gate |
| 03-02-01 | REMINDER-01, QUALITY-13 | domain tests + import scan |
| 03-02-02 | REMINDER-01/03/04, QUALITY-13/16 | DTO/data/repository tests + Prism |
| 03-03-01 | REMINDER-01/03, QUALITY-13 | controller/router/widget tracer |
| 03-03-02 | REMINDER-01/03/04, QUALITY-13/17 | full CU-006 + 320 px |
| 03-04-01 | QUALITY-13/15..18, DELIVERY-07 | immutable gates + exact remote OPEN PR |
| 03-04-02 | DELIVERY-07 | merge_commit + ancestry + local metadata |
| 03-05-01 | QUALITY-14/15, DELIVERY-08 | root/ancestry + helper tests |
| 03-05-02 | QUALITY-15/17 | D-16 pre/post + exact lock |
| 03-05-03 | REMINDER-02/05, QUALITY-14 | DST/64/ID/payload pure tests + scans |
| 03-06-01 | REMINDER-05, QUALITY-14/16 | Android policy + Pixel_6 |
| 03-06-02 | REMINDER-05, QUALITY-14/17 | iOS policy/no-op + web + scans |
| 03-07-01 | REMINDER-02/03/05, QUALITY-14 | fail-safe reconciliation |
| 03-07-02 | REMINDER-03/05, QUALITY-14/16/17 | every trigger + degraded UI/web |
| 03-08-01 | QUALITY-14..18, DELIVERY-08 | all gates/scans + exact remote OPEN PR |
| 03-08-02 | DELIVERY-08 | merge_commit + ancestry + local truthful metadata |

Every task has concrete `<read_first>`, `<files>`, `<action>`, fail-closed
`<verify><automated>`, preserved `<acceptance_criteria>` and `<done>`.

## Platform Evidence

- Android: local `Pixel_6` runner waits for boot, executes actual permission,
  exact/inexact, mutation, reboot and package-replace paths, and cleans only its
  own emulator.
- iOS: this Windows planning/execution path cannot run Xcode. The Phase 3
  record remains exactly `pending_external`; no plan promises or claims native
  iOS PASS. A later external run may attach independent evidence, but it is not
  a prerequisite for truthful Windows completion.

## Multi-Source Coverage Audit

| Source | ID | Plan(s) | Status | Notes |
|---|---|---|---|---|
| GOAL | — | 03-01..08 | COVERED | configuration through local scheduling and truthful evidence |
| REQ | REMINDER-01 | 03-01..03 | COVERED | contract/domain/data/CU-006 |
| REQ | REMINDER-02 | 03-05/07 | COVERED | profile-zone planner/reconciliation |
| REQ | REMINDER-03 | 03-02/03/07 | COVERED | UI/controller/scheduler eligibility |
| REQ | REMINDER-04 | 03-02/03 | COVERED | full-field toggle preservation |
| REQ | REMINDER-05 | 03-05..07 | COVERED | permissions/reboot/iOS 64 |
| REQ | QUALITY-13 | 03-02..04 | COVERED | HBM-13 tests/gates |
| REQ | QUALITY-14 | 03-05..08 | COVERED | pure/adapter/reconciliation/scans |
| REQ | QUALITY-15 | 03-01/04/05/08 | COVERED | strict immutable-base coverage |
| REQ | QUALITY-16 | 03-01..08 | COVERED | analyze/test per implementation/delivery |
| REQ | QUALITY-17 | 03-03..08 | COVERED | web/no-op |
| REQ | QUALITY-18 | 03-01/04/08 | COVERED | self-contained Prism |
| REQ | DELIVERY-07 | 03-04 | COVERED | exact HBM-13 tip/PR/merge |
| REQ | DELIVERY-08 | 03-05/08 | COVERED | isolated base and exact HBM-14 delivery |
| CONTEXT | D-01 | 03-04/05 | COVERED | HBM-13 ancestry gates worktree |
| CONTEXT | D-02 | 03-01/04/08 | COVERED | frontend-first contract/handoff |
| CONTEXT | D-03 | 03-01/02 | COVERED | several reminders per habit |
| CONTEXT | D-04 | 03-03 | COVERED | exact route |
| CONTEXT | D-05 | 03-03 | COVERED | CU-006 composition |
| CONTEXT | D-06 | 03-02/03/07 | COVERED | eligibility |
| CONTEXT | D-07 | 03-01..03 | COVERED | resilient validation |
| CONTEXT | D-08 | 03-05/07 | COVERED | profile zone/DST |
| CONTEXT | D-09 | 03-05..08 | COVERED | port/plugin boundary |
| CONTEXT | D-10 | 03-06/07/08 | COVERED | Android permission/exact fallback |
| CONTEXT | D-11 | 03-05/06/08 | COVERED | iOS 64/web no-op/pending evidence |
| CONTEXT | D-12 | 03-07 | COVERED | all reconciliation triggers |
| CONTEXT | D-13 | all | COVERED | tests/coverage |
| CONTEXT | D-14 | 03-04/05/08 | COVERED | exactly two branches/PRs |
| CONTEXT | D-15 | all | COVERED | root/CMake/stash guards |
| CONTEXT | D-16 | 03-05/08 | COVERED | tested pre/post package gate |
| RESEARCH | HBB-23 order | 03-01/04/08 | COVERED | frontend handoff, no false backend claim |
| RESEARCH | DST policy | 03-05 | COVERED | first-valid gap/one earliest overlap |
| RESEARCH | Android venue | 03-06/08 | COVERED | local Pixel_6 |
| RESEARCH | iOS limitation | 03-06/08 | COVERED | pending_external only |
| RESEARCH | architecture/security | 03-02..08 | COVERED | DTO/repository/port/managed cancellation |

Deferred push, campaigns, snooze, geofencing, tracking, metrics and backend
business logic remain excluded and are not gaps.

## Sign-Off

- [x] Eight plans/waves, acyclic, exactly two product branches/PRs.
- [x] 03-05..08 use the locked isolated root with auto-worktrees disabled.
- [x] Product tips and local metadata commits are separate and verifiable.
- [x] Every task has concrete read-first input and fail-closed automation.
- [x] D-16 helper is automated, tested and used pre/post mutation.
- [x] Plugin, cancelAll, local-time and payload-literal scans are mandatory.
- [x] All 13 requirements and D-01..D-16 are covered.
- [x] iOS evidence is not overstated.

**Approval:** planned — execution evidence pending.
