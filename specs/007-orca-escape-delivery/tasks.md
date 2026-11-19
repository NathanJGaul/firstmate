# Tasks: Orca Escape and Ctrl+U Delivery

**Input**: `specs/007-orca-escape-delivery/` (spec.md, plan.md, research.md, quickstart.md, tdd/test-list.md)

**Tests**: Required, not optional.
Every behavior test precedes its implementation task, and each test must be seen failing for the right reason first, with the failure recorded in `tdd/cycle-log.md`.
Tests extend `tests/fm-backend-orca.test.sh` and `tests/fm-control.test.sh`; run each with `bin/fm-test-run.sh <file>`.

## Format: `[ID] [P?] [Behaviors] [Story] Description`

- **[P]**: can run in parallel (different files, no dependencies)
- **[A1,U1]**: the behavior ids from `tdd/test-list.md` that the task covers
- **[Story]**: US1 interrupt works, US2 capability gate, US3 version floor, US4 exit and relaunch stay refused

## Phase 1: Setup

- [X] T001 Run the baseline `bin/fm-test-run.sh tests/fm-backend-orca.test.sh` and `tests/fm-control.test.sh` and record that each is green before any edit (`tdd/cycle-log.md`).

## Phase 2: User Story 3 and 2 - The status facts, the floor, and the gate (Priority: P1)

**Goal**: the adapter reads the runtime's version and capabilities once and gates on them.

**Independent Test**: adapter cases in `tests/fm-backend-orca.test.sh` against a fake `orca` whose status is a pinned file.

### Tests (write first, see them fail)

- [X] T002 [P] [U8,U9,U10,U11,U12] [US3] Add the runtime-check cases: facts recorded, below-floor refused, floor and later accepted, absent or unreadable version tolerated.
- [X] T003 [P] [U2,U3,U4,U5,U6,U7] [US2] Add the send-key cases: raw ESC, raw Ctrl+U, spellings, refusal without the capability, refusal on unreadable status, Enter and Ctrl+C ungated; replace the case that asserted Escape was unsupported.

### Implementation

- [X] T004 [US3] Add `fm_backend_orca_status_read` and rebuild `fm_backend_orca_runtime_check` on it in `bin/backends/orca.sh`.
- [X] T005 [US2] Add `fm_backend_orca_control_bytes_ready` and the Escape and Ctrl+U arms of `fm_backend_orca_send_key` in `bin/backends/orca.sh`.

## Phase 3: User Story 1 and 4 - Interrupt through the control plane (Priority: P1)

**Goal**: `fm-control interrupt` and `fm-send --key` deliver on Orca; `exit` and `relaunch` stay refused.

**Independent Test**: control cases in `tests/fm-control.test.sh` with a fake `orca` that logs every call.

### Tests (write first, see them fail)

- [X] T006 [P] [A1,A2,A3,A4,A5,A6,U1] [US1,US4] Add the fake `orca`, the Orca task helper, and the interrupt, gate, send-key, and stop-verb cases; invert the matrix assertions and replace the refusal case.

### Implementation

- [X] T007 [US1] List Escape and C-u for Orca in `fm_control_backend_supports_key` (`bin/fm-control-lib.sh`) and fix the key-support comments in `bin/fm-control.sh` and `bin/fm-send.sh`.

## Phase 4: Live proof and documentation

- [X] T008 [A7] Print the full capability list in the lab, send Escape and Ctrl+U through the adapter, `fm-send`, and `fm-control interrupt`, and assert the stop verbs stay refused (`tests/fm-backend-orca-smoke.test.sh`).
- [X] T009 [US1,US4] Update `docs/orca-backend.md`, `docs/agent-control.md`, `.agents/skills/stuck-crewmate-recovery/SKILL.md`, and `docs/verification/runtime-backends.md`; register the feature records in `docs/documentation-audiences.json`.

## Phase 5: Verification and convergence

- [X] T010 Run `/speckit.tdd.verify`, `/speckit.checklist`, `/speckit.analyze`, and `/speckit.converge` and record the results (`tdd/verification.md`, `checklist.md`, `analyze.md`, `converge.md`).
