---
feature: 010-orca-reclaim
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 14
planned_at: 402ac724
updated_at: 402ac724
suite_baseline: unknown
---

# Test List: Orca Close-and-Recreate Reclaim, Exit, and Relaunch

Baseline note: the suites that exercise the changed code are run green before any edit; the profile's full suite is left to CI, so `suite_baseline` is `unknown`.
`traces` values name spec acceptance scenarios (`USn.m`) and functional requirements (`FR-nnn`).
The fake `orca` and fake process table are the existing ones in `tests/fm-backend-orca.test.sh`; the live lab steps are the proof of the matrix rows the fakes cannot show.

## Outer loop: acceptance behaviors

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| A1  | `fm-control exit` on a dead Orca terminal reports `already-stopped` and sends nothing | US1.2, FR-002 | example | DONE | `tests/fm-control.test.sh::test_orca_exit_matrix` |
| A2  | `fm-control exit` on a locally proven missing terminal reports `endpoint-gone` | US2.1, FR-002, FR-005 | example | DONE | `tests/fm-control.test.sh::test_orca_exit_matrix` |
| A3  | `exit` and `relaunch` refuse alive, ambiguous, unverified, and unreadable, and a non-local missing, each naming the state | US3.1, US4.1, US4.2, FR-002 | example | DONE | `tests/fm-control.test.sh::test_orca_exit_matrix` |
| A4  | `relaunch` of a dead Orca terminal adopts it: no create, no close, `terminal=` unchanged, harness launched in it | US1.1, FR-006 | example | DONE | `tests/fm-control-relaunch.test.sh::test_orca_relaunch_adopts_a_dead_terminal` |
| A5  | `relaunch` of a gone terminal closes it, creates one terminal by the recorded worktree id, republishes `terminal=`, never calls `worktree rm`, and launches the harness there | US2.2, US2.3, FR-006, FR-007, FR-009 | example | DONE | `tests/fm-control-relaunch.test.sh::test_orca_relaunch_reclaims_a_gone_terminal` |
| A6 | `exit --close-terminal` on an alive agent takes `ptyKilled: true` as proof and reports `closed`; a missing receipt, a lingering terminal, or a lingering process refuses | US3.2, US3.4, FR-003, FR-004 | example | DONE | `tests/fm-control.test.sh::test_orca_exit_close_terminal` |
| A7 | `relaunch --close-terminal` on an alive agent closes, reclaims, and launches | US3.3 | example | DONE | `tests/fm-control-relaunch.test.sh::test_orca_relaunch_closes_a_wedged_agent` |
| A8 | `--close-terminal` is refused for a non-alive state, another backend, a non-lifecycle verb, and an Orca secondmate | US4.4, US4.5, FR-003, FR-011 | example | DONE | `tests/fm-control.test.sh::test_orca_close_terminal_is_bounded` and `tests/fm-control-relaunch.test.sh::test_orca_spawn_relaunch_refuses_what_it_cannot_prove` |
| A9 | A failed reclaim (close lingers, create fails, new terminal unlisted) leaves the record and worktree and closes only a terminal it created | US2.4, FR-008 | example | DONE | `tests/fm-control-relaunch.test.sh::test_orca_failed_reclaim_keeps_the_record` |
| A10 | Live lab: a renamed `sleep` named `claude` killed with SIGKILL is relaunched into the same terminal: one terminal, zero stray processes, worktree intact, record unchanged | US1.3 | example | DONE | `tests/fm-backend-orca-smoke.test.sh` step A15 (in section F) |
| A11 | Live lab: a closed terminal is reclaimed: one terminal, republished record, worktree and commits intact, zero stray processes | US2.2, US2.3 | example | DONE | `tests/fm-backend-orca-smoke.test.sh` step A15 (in section F) |
| A12 | Live lab: a running agent is closed with `--close-terminal` and relaunched | US3.2, US3.3 | example | DONE | `tests/fm-backend-orca-smoke.test.sh` step A15 (in section F) |
| A13 | Live lab: teardown still refuses an unlanded commit after a reclaim | US5.1 | example | DONE | `tests/fm-backend-orca-smoke.test.sh` step A15 (in section F) |

## Inner loop: unit behaviors

| id  | behavior | traces | state | test |
| --- | -------- | ------ | ----- | ---- |
| U1  | The stop-proving table admits Orca and still refuses zellij and cmux | FR-001 | DONE | `tests/fm-control.test.sh::test_state_verified_backends_are_tmux_herdr_and_orca` |
| U2  | The close receipt verdicts: killed, gone, unkilled, unreadable | FR-003 | DONE | `tests/fm-backend-orca.test.sh::test_close_terminal_verdicts` |
| U3  | The Orca absence verdict: gone, alive, unproven for a lingering process, an unreadable table, and a non-local runtime | FR-005 | DONE | `tests/fm-backend-orca.test.sh::test_absence_verdict_for_orca` |
| U4  | The reclaim closes before it creates, creates by the recorded id, and refuses when the old terminal persists, the create fails, or the new terminal is unlisted | FR-007 | DONE | `tests/fm-backend-orca.test.sh::test_reclaim_terminal` |
| U5  | Interrupt on Orca keeps the endpoint proof for unverified, ambiguous, and unreadable | FR-012 | DONE | `tests/fm-control.test.sh::test_orca_interrupt_keeps_endpoint_proof` |
| U6  | A relaunch checks the runtime floor before any mutation | FR-010 | DONE | `tests/fm-control-relaunch.test.sh::test_orca_relaunch_checks_the_runtime` |
