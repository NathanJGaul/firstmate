# Tasks: Orca Fleet Plumbing

**Input**: `specs/005-orca-fleet-plumbing/` (spec.md, plan.md, research.md, quickstart.md, tdd/test-list.md)

**Tests**: Required, not optional.
Every behavior test precedes its implementation task, and each test must be seen failing for the right reason first, with the failure recorded in `tdd/cycle-log.md`.
Tests extend `tests/fm-bootstrap.test.sh`, `tests/fm-spawn-orca-worktree.test.sh`, and `tests/fm-watch-triage.test.sh`; run each with `bin/fm-test-run.sh <file>`.

## Format: `[ID] [P?] [Behaviors] [Story] Description`

- **[P]**: can run in parallel (different files, no dependencies)
- **[A1,U1]**: the behavior ids from `tdd/test-list.md` that the task covers; `/speckit.tdd.run` ticks a behavioral task only from these markers
- **[Story]**: US1 bootstrap follows recorded backends, US2 launch-env floor, US3 wake naming

## Phase 1: Setup

- [X] T001 Run the baseline `bin/fm-test-run.sh tests/fm-bootstrap.test.sh`, `tests/fm-spawn-orca-worktree.test.sh`, `tests/fm-watch-triage.test.sh`, and `tests/fm-daemon.test.sh`, and record that each is green before any edit (recorded in `tdd/cycle-log.md`).

## Phase 2: User Story 1 - Bootstrap follows recorded backends (Priority: P1)

**Goal**: required tools are the union of the default backend and every live task record's backend.

**Independent Test**: bootstrap cases in `tests/fm-bootstrap.test.sh` with a fake home and `state/*.meta` records.

### Tests for User Story 1 (write first, see them fail)

- [X] T002 [P] [A1,A2,U1] [US1] Add the mixed-fleet cases to `tests/fm-bootstrap.test.sh`: an Orca task in a tmux home reports `orca` missing and is silent once `orca` is present, and the union function prints the default's tools first.
- [X] T003 [P] [A3,A5] [US1] Add the legacy-record case: an orca home with a meta carrying no backend field reports `tmux` and `treehouse`, and a home with no records is unchanged.
- [X] T004 [P] [A4,A6,A7] [US1] Add the dedupe, unknown-backend, and treehouse-lease cases.

### Implementation for User Story 1

- [X] T005 [US1] Add `fm_backend_fleet_required_tools` to `bin/fm-backend.sh`.
- [X] T006 [US1] Make `bin/fm-bootstrap.sh` check that union and update its header and `docs/configuration.md` "Backend requirements".

## Phase 3: User Story 2 - An allowlisted Orca launch keeps Orca's variables (Priority: P1)

**Goal**: the floor retains the observed Orca names and nothing else new.

**Independent Test**: spawn on the fake Orca with an empty allowlist and replay the launch.

### Tests for User Story 2 (write first, see them fail)

- [ ] T007 [A8,A9,A10,A11] [US2] Extend `tests/fm-spawn-orca-worktree.test.sh` so its fake Orca logs sent text, then add the retained, unset-stays-unset, outside-the-floor-removed, and no-allowlist cases.

### Implementation for User Story 2

- [ ] T008 [US2] Add the Orca names to the floor loop in `bin/fm-spawn.sh` and update its header contract and `docs/configuration.md` "Variables retained".

## Phase 4: User Story 3 - Wakes name the task (Priority: P2)

**Goal**: stale reasons read `fm-<id>` for opaque handles, with the queue key and daemon resolution unchanged.

**Independent Test**: pure-function cases against the classifier library, a watcher run on a fake Orca fleet, and a daemon classification of a label-form reason.

### Tests for User Story 3 (write first, see them fail)

- [ ] T009 [P] [U2,U3,U4] [US3] Add `window_wake_name` cases to `tests/fm-watch-triage.test.sh`: Herdr handle to label, no record keeps handle, tmux handle unchanged, Orca terminal handle to label.
- [ ] T010 [A12,A13] [US3] Add the watcher cases: an Orca task's stale wake reads `fm-<id>` with the terminal handle as the queue key, and a detail-suffixed reason keeps its suffix.
- [ ] T011 [P] [A14] [US3] Add the daemon case to `tests/fm-daemon.test.sh`: a label-form stale reason resolves the same task and markers as the handle form.

### Implementation for User Story 3

- [ ] T012 [US3] Split `window_to_task` and add `window_wake_name` in `bin/fm-classify-lib.sh`.
- [ ] T013 [US3] Render every stale reason in `bin/fm-watch.sh` and `bin/fm-push-transition-lib.sh` through it, keeping the handle as the queue key, and update the header reason list.

## Phase 5: Polish

- [ ] T014 Run `bin/fm-lint.sh`, `bin/fm-doc-audience-check.sh`, `bin/fm-test-run.sh --check-coverage`, and the neighbouring suites named in `quickstart.md`.
- [ ] T015 Classify the new feature records in `docs/documentation-audiences.json`.
