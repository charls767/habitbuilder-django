# Phase 3: Reminders - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution
> agents. Decisions are captured in CONTEXT.md.

**Date:** 2026-07-28
**Phase:** 03-reminders
**Areas discussed:** contract shape, CU-006 behavior, eligibility, local scheduling

---

## Reminder Ownership And Contract

| Option | Description | Selected |
| --- | --- | --- |
| One reminder per habit | Simpler but contradicts epic success criteria | |
| Multiple reminders per habit | Message, time, days and state per entry | Yes |
| Device-only reminders | No shared API representation | |

**User's choice:** Jira HBM-13/HBB-23 and the request to execute both tracks
lock multiple reminders with a shared contract.

## Eligibility

| Option | Description | Selected |
| --- | --- | --- |
| Hide reminders on inactive habits | Existing configuration becomes inaccessible | |
| Allow every mutation | Violates REMINDER-03 | |
| Block create/reactivate only | Existing entries remain editable/deactivatable | Yes |

**User's choice:** Derived from HBM-13, HBB-24 and the epic success criteria.

## Scheduling Source Of Truth

| Option | Description | Selected |
| --- | --- | --- |
| Device local clock | Changes behavior when device zone differs | |
| Profile IANA timezone | Matches REMINDER-02 and HBM-14 | Yes |
| UTC-only display | Loses the user's intended wall-clock time | |

**User's choice:** Jira explicitly requires profile timezone and `TZDateTime`.

## Native Integration Boundary

| Option | Description | Selected |
| --- | --- | --- |
| Call plugin from widgets | Hard to test and couples UI to platforms | |
| Port plus native adapter | Deterministic domain tests and web fallback | Yes |
| Backend-delivered notifications | Out of HBM-14 scope | |

**User's choice:** Technical implementation delegated to the agent; the port
is the option consistent with HBB-23 and QUALITY-14.

## The Agent's Discretion

- DTO naming, deterministic notification IDs and iOS occurrence allocation.
- Exact internal component breakdown while preserving CU-006.

## Deferred Ideas

- Push provider, snooze, geofencing, campaigns and notification analytics.
