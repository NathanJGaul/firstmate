# Tasks: Orca Local Process Classifier

**Input**: `specs/009-orca-process-classifier/` (spec.md, plan.md, research.md, tdd/test-list.md)

**Tests**: Required, not optional.
Every behavior test precedes its implementation task, and each test must be seen failing for the right reason first, with the failure recorded in `tdd/cycle-log.md`.
Tests extend `tests/fm-backend-orca.test.sh` and `tests/fm-backend-orca-smoke.test.sh`; run each with `bin/fm-test-run.sh <file>`, and the lab only with `env -u ORCA_USER_DATA_PATH FM_ORCA_LIVE_E2E=1` and a pinned `HOME`.

## Format: `[ID] [P?] [Behaviors] [Story] Description`

- **[A1,U1]**: the behavior ids from `tdd/test-list.md` that the task covers
- **[Story]**: US1 alive, US2 dead, US3 uncertain cases, US4 control plane, US5 live proof

## Phase 1: Setup

- [X] T001 Run the baseline `bin/fm-test-run.sh` for `tests/fm-backend-orca.test.sh`, `tests/fm-backend.test.sh`, `tests/fm-crew-state.test.sh`, and `tests/fm-session-start.test.sh`, and record each result in `tdd/cycle-log.md` before any edit.
- [X] T002 Probe the real process table for a lab terminal (environment, parent, comm, cmdline, zombie shape) in the isolated lab and record it in `research.md`.

## Phase 2: Process scan and classification (US1, US2, US3)

### Tests (write first, see them fail)

- [X] T003 [U1,U2,U3,U4,U5,U6] [US1,US2,US3] Add the fake process-table helper and the scan cases to `tests/fm-backend-orca.test.sh`.
- [X] T004 [U7,U8,U9] [US3] Add the classification cases (verdict precedence, settle, unreadable tally).
- [X] T005 [A1,A2,A3] [US1,US2] Add the agent-state cases for alive, descendant alive, argv0 alive, dead, and the killed-agent shape.
- [X] T006 [A4,A5,A6,A7,A8] [US3] Add the ambiguous, non-local, no-table, no-carrier, and unreadable cases.
- [X] T007 [A9] [US3] Add the missing and unreadable endpoint cases that must not read the process table.
- [X] T008 [A10] [US4] Add the control-plane refusal characterization for a `dead` endpoint.

### Implementation

- [X] T009 [U1,U2,U3,U4,U5,U6] Add `fm_backend_orca_process_scan` to `bin/backends/orca.sh`.
- [X] T010 [U7,U8,U9] Add `fm_backend_orca_process_state`.
- [X] T011 [A1-A9] Extend `fm_backend_orca_agent_state` and update its header and the `bin/fm-backend.sh` and `bin/fm-control-lib.sh` headers.

## Phase 3: Live proof and records (US5)

- [X] T012 [US5] Update lab step A13's live verdict and add lab step A14 to `tests/fm-backend-orca-smoke.test.sh`: a real binary named `claude` reads `alive`, `dead` after SIGKILL while Orca's native state still names it, `missing` once the terminal is closed, with every assertion inside the isolated runtime.
- [X] T013 [US5] Run the lab with a pinned `HOME` and record the dated entry in `docs/verification/runtime-backends.md`.
- [X] T014 Correct `docs/orca-backend.md` and register the new spec files in `docs/documentation-audiences.json`.

## Phase 4: Gates

- [X] T015 Run `/speckit.tdd.verify` with deliberate mutants, `bin/fm-lint.sh`, `bin/fm-doc-audience-check.sh`, then `/speckit.implement`, `/speckit.checklist`, `/speckit.analyze`, and `/speckit.converge`.
