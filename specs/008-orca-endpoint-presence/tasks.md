# Tasks: Orca Endpoint Presence

**Input**: `specs/008-orca-endpoint-presence/` (spec.md, plan.md, research.md, tdd/test-list.md)

**Tests**: Required, not optional.
Every behavior test precedes its implementation task, and each test must be seen failing for the right reason first, with the failure recorded in `tdd/cycle-log.md`.
Tests extend `tests/fm-backend-orca.test.sh`, `tests/fm-session-start.test.sh`, `tests/fm-crew-state.test.sh`, and `tests/fm-backend-orca-smoke.test.sh`; run each with `bin/fm-test-run.sh <file>`, and the lab only with `env -u ORCA_USER_DATA_PATH FM_ORCA_LIVE_E2E=1` and a pinned `HOME`.

## Format: `[ID] [P?] [Behaviors] [Story] Description`

- **[A1,U1]**: the behavior ids from `tdd/test-list.md` that the task covers
- **[Story]**: US1 presence read, US2 digest and crew state, US3 `missing` verdict, US4 live proof

## Phase 1: Setup

- [X] T001 Run the baseline `bin/fm-test-run.sh` for `tests/fm-backend-orca.test.sh`, `tests/fm-session-start.test.sh`, `tests/fm-crew-state.test.sh`, and `tests/fm-backend.test.sh`, and record each result in `tdd/cycle-log.md` before any edit.
- [X] T002 Probe the real `terminal show` and `terminal read` answers for a live, exited, closed, and stale terminal in the isolated lab and record them in `research.md`.

## Phase 2: Adapter endpoint state (US1, US3)

### Tests (write first, see them fail)

- [X] T003 [U1,U2,U3,U4,U5] [US1] Add the endpoint-state cases to `tests/fm-backend-orca.test.sh`.
- [X] T004 [A1] [US1] Add the `fm_backend_target_exists` four-state case.
- [X] T005 [A5,U6] [US3] Add the `fm_backend_agent_state` and `fm_backend_agent_alive` case.
- [X] T006 [A6] [US3] Add the control-plane refusal characterization.

### Implementation

- [X] T007 [U1,U2,U3,U4,U5] [US1] Add `fm_backend_orca_endpoint_state` to `bin/backends/orca.sh`.
- [X] T008 [A1] [US1] Point the Orca arm of `fm_backend_target_exists` at it and update that header.
- [X] T009 [A5,U6] [US3] Add `fm_backend_orca_agent_state`, the Orca arm of `fm_backend_agent_state`, and update that header.

## Phase 3: Callers (US2)

### Tests (write first, see them fail)

- [X] T010 [A2] [US2] Add the digest case to `tests/fm-session-start.test.sh`.
- [X] T011 [A3,A4] [US2] Add the crew-state cases to `tests/fm-backend-orca.test.sh` (it already drives `fm-crew-state.sh` against the fake `orca`) and update its two older expectations.

### Implementation

- [X] T012 [A3,A4] [US2] Make `pane_readable` and the no-run fallback in `bin/fm-crew-state.sh` handle Orca.

## Phase 4: Live proof and records (US4)

- [X] T013 [US4] Add lab step A13 to `tests/fm-backend-orca-smoke.test.sh`: the four states through the adapter and `fm_backend_target_exists`, with every assertion inside the isolated runtime.
- [X] T014 [US4] Run the lab with a pinned `HOME` and record the dated entry in `docs/verification/runtime-backends.md`.
- [X] T015 Correct `docs/orca-backend.md` and the `fm-control-lib.sh` comment.

## Phase 5: Gates

- [X] T016 Run `/speckit.tdd.verify` with deliberate mutants, `bin/fm-lint.sh`, `bin/fm-doc-audience-check.sh`, then `/speckit.implement`, `/speckit.checklist`, `/speckit.analyze`, and `/speckit.converge`.
