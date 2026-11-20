# Tasks: Orca Close-and-Recreate Reclaim, Exit, and Relaunch

**Input**: `specs/010-orca-reclaim/` (spec.md, plan.md, tdd/test-list.md)

**Tests**: Required, not optional.
Every behavior test precedes its implementation task, and each test must be seen failing for the right reason first, with the failure recorded in `tdd/cycle-log.md`.
Run each file with `bin/fm-test-run.sh <file>`, and the lab only with `env -u ORCA_USER_DATA_PATH FM_ORCA_LIVE_E2E=1`.

## Phase 1: Setup

- [X] T001 Run the baseline for `tests/fm-backend-orca.test.sh`, `tests/fm-control.test.sh`, `tests/fm-control-relaunch.test.sh`, and the live lab, and record each result in `tdd/cycle-log.md` before any edit.
- [X] T002 Probe the lab for the real `terminal close` receipt, the answer for an already-closed and a never-issued handle, and `terminal list` after a close, and record them in `research.md`.

## Phase 2: Adapter (US2, US3)

### Tests (write first, see them fail)

- [X] T003 [U2] Add the close receipt verdict cases to `tests/fm-backend-orca.test.sh`.
- [X] T004 [U3] Add the Orca absence verdict cases.
- [X] T005 [U4] Add the reclaim cases.

### Implementation

- [X] T006 Add `fm_backend_orca_close_terminal`, `fm_backend_orca_terminal_handles`, and `fm_backend_orca_reclaim_terminal` to `bin/backends/orca.sh`.
- [X] T007 Add the Orca arm to `fm_control_endpoint_absence_verdict` in `bin/fm-control-lib.sh`.

## Phase 3: Control plane (US1, US3, US4)

### Tests (write first, see them fail)

- [X] T008 [U1,U5] Update the capability-table and interrupt cases in `tests/fm-control.test.sh`.
- [X] T009 [A1,A2,A3] Add the exit matrix.
- [X] T010 [A6,A8] Add the `--close-terminal` cases.

### Implementation

- [X] T011 Admit Orca in `fm_control_backend_state_verified`, add the `--close-terminal` flag and the Orca arm of `do_exit`, and keep the interrupt proof, in `bin/fm-control-lib.sh` and `bin/fm-control.sh`.

## Phase 4: Launch owner (US1, US2, US3)

### Tests (write first, see them fail)

- [X] T012 [A4,A5,A7,A9,U6] Add the relaunch cases to `tests/fm-control-relaunch.test.sh`.

### Implementation

- [X] T013 Carry the Orca identity through `bin/fm-spawn.sh --relaunch`, call the reclaim on a rebind, keep the abort cleanup from touching the worktree, and refuse a secondmate.

## Phase 5: Live proof (US1, US2, US3, US5)

- [X] T014 [A10,A11,A12,A13] Add step A15 to `tests/fm-backend-orca-smoke.test.sh` and update the stale refusal in section F; run the lab.

## Phase 6: Documentation and records

- [X] T015 Update `docs/agent-control.md`, `docs/orca-backend.md`, `.agents/skills/stuck-crewmate-recovery/SKILL.md`, the headers of `bin/fm-control.sh`, `bin/fm-control-lib.sh`, and `bin/backends/orca.sh`, and `docs/verification/runtime-backends.md`.

## Phase 7: Lifecycle

- [X] T016 Run `/speckit.tdd.verify`, `/speckit.implement`, `/speckit.checklist`, `/speckit.analyze`, and `/speckit.converge` in order, and run `bin/fm-lint.sh` and `bin/fm-doc-audience-check.sh`.
