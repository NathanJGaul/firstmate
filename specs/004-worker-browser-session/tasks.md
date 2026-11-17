---

description: "Task list for the per-worker browser session feature"
---

# Tasks: Per-Worker Browser Session

**Input**: Design documents from `specs/004-worker-browser-session/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/launch-and-cleanup.md, tdd/test-list.md

**Tests**: Mandatory.
This repository's TDD rule requires a failing test before each behavior change, and test tasks precede implementation tasks.
Every test must be observed failing for the right reason first, with the evidence recorded in `tdd/cycle-log.md`.

**Organization**: Tasks are grouped by user story so each story can be implemented and tested independently.
All stories share one foundational helper, so that comes first.
A bracketed `[A#]` or `[U#]` is the behavior id from `tdd/test-list.md` that the task covers.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1 to US4)
- Test files are `tests/fm-spawn-compact-adviser-disable.test.sh` (launch and helper) and `tests/fm-teardown.test.sh` (cleanup), both run through `bin/fm-test-run.sh <file>`

## Phase 1: Setup

- [ ] T001 Record the baseline: run `bin/fm-test-run.sh tests/fm-spawn-compact-adviser-disable.test.sh` and `bin/fm-test-run.sh tests/fm-teardown.test.sh` on the untouched branch and note that both pass, in `specs/004-worker-browser-session/tdd/cycle-log.md`

## Phase 2: Foundational (blocks all user stories)

- [ ] T002 Write failing tests that source `bin/fm-pr-lib.sh` under `bash` and assert `fm_browser_session_name` accepts `fix-a1` [U1], `a.b_c-9` [U2], a 64-character id [U3], and `default-2` [U6], and refuses a 65-character id [U4], `default` [U5], an empty id [U7], a leading-dot id [U8], and an id with a space [U9], in `tests/fm-spawn-compact-adviser-disable.test.sh`
- [ ] T003 Add `fm_browser_session_name` beside `fm_task_id_creation_valid` in `bin/fm-pr-lib.sh` so the T002 tests pass [U1] [U2] [U3] [U4] [U5] [U6] [U7] [U8] [U9]

**Checkpoint**: the shared rule exists; user stories can proceed.

## Phase 3: User Story 1 - A worker's browser is its own (Priority: P1)

**Goal**: every local launch starts its agent with `CHROME_DEVTOOLS_AXI_SESSION=<task id>`.

**Independent Test**: spawn against a fake pane, run the emitted launch with a probe harness, read the variable.

### Tests for User Story 1 (write first, confirm they fail)

- [ ] T004 [US1] Add `CHROME_DEVTOOLS_AXI_SESSION` probe cases for a ship launch and a scout launch asserting the agent sees the task id [A1] [A2], in `tests/fm-spawn-compact-adviser-disable.test.sh`
- [ ] T005 [US1] Add a local secondmate launch case asserting the agent sees the secondmate's id [A3], in `tests/fm-spawn-compact-adviser-disable.test.sh`
- [ ] T006 [US1] Add a case where the pane carries a contrary `CHROME_DEVTOOLS_AXI_SESSION=other` and the agent still sees the task id [A4], in `tests/fm-spawn-compact-adviser-disable.test.sh`
- [ ] T007 [US1] Add a case asserting two ship launches with different ids yield different sessions [A6], in `tests/fm-spawn-compact-adviser-disable.test.sh`
- [ ] T008 [US1] Add a relaunch case driven through `bin/fm-control.sh relaunch` asserting the replacement agent sees the same task id [A5], in `tests/fm-spawn-compact-adviser-disable.test.sh`

### Implementation for User Story 1

- [ ] T009 [US1] In `bin/fm-spawn.sh`, add the `export CHROME_DEVTOOLS_AXI_SESSION=<id>;` prefix to the launch text beside the `FM_TASK_INBOX` export, guarded by `fm_browser_session_name "$ID"`, so T004 to T008 pass [A1] [A2] [A3] [A4] [A5] [A6]
- [ ] T010 [US1] Outer-loop gate: confirm A1 to A6 are green through `bin/fm-test-run.sh tests/fm-spawn-compact-adviser-disable.test.sh` before calling User Story 1 complete [A1] [A2] [A3] [A4] [A5] [A6]

**Checkpoint**: User Story 1 passes on its own.

## Phase 4: User Story 2 - The session survives the allowlist (Priority: P1)

**Goal**: the variable reaches the agent under a present allowlist and without the pane-side exports.

**Independent Test**: spawn with an empty `config/launch-env-allowlist`, run the launch with and without the pane preamble.

### Tests for User Story 2 (write first, confirm they fail)

- [ ] T011 [US2] Add a ship case under an empty allowlist asserting the cleared-environment launch still gives the agent its task-id session [A7], in `tests/fm-spawn-compact-adviser-disable.test.sh`
- [ ] T012 [US2] Add a case replaying only the launch command, with a contrary ambient value, under both allowlist postures, asserting the task id wins [A8], in `tests/fm-spawn-compact-adviser-disable.test.sh`

### Implementation for User Story 2

- [ ] T013 [US2] Confirm T011 and T012 pass with the T009 export alone, and change no floor list; if either fails, fix the export site in `bin/fm-spawn.sh` and record the finding in `specs/004-worker-browser-session/tdd/cycle-log.md` [A7] [A8]
- [ ] T014 [US2] Outer-loop gate: confirm A7 and A8 are green before calling User Story 2 complete [A7] [A8]

**Checkpoint**: both allowlist postures give per-worker sessions.

## Phase 5: User Story 3 - Cleanup stops the task's own session (Priority: P1)

**Goal**: cleanup stops that task's session once, after the leaked-process cleanup, without ever blocking.

**Independent Test**: run `bin/fm-teardown.sh` with a fake `chrome-devtools-axi` first on `PATH` that logs its arguments and session variable.

### Tests for User Story 3 (write first, confirm they fail)

- [ ] T015 [US3] Add a cleanup case asserting exactly one `stop` call whose session variable equals the task id [A9], in `tests/fm-teardown.test.sh`
- [ ] T016 [US3] Add an ordering case asserting the stop follows the leaked-process cleanup, modeled on `test_run_abort_precedes_process_reap_precedes_worktree_removal` [A10], in `tests/fm-teardown.test.sh`
- [ ] T017 [US3] Add a case where the fake exits non-zero, a case where it hangs past `FM_TEARDOWN_BROWSER_STOP_TIMEOUT=1`, and a case with a non-numeric bound, asserting cleanup still succeeds with the same exit status and a warning where a stop failed [A11] [U10] [U11], in `tests/fm-teardown.test.sh`
- [ ] T018 [US3] Add a case with no `chrome-devtools-axi` on `PATH` asserting cleanup succeeds with no warning [A12], in `tests/fm-teardown.test.sh`
- [ ] T019 [US3] Add a refusal case (unlanded work) asserting the fake sees no call [A13], in `tests/fm-teardown.test.sh`

### Implementation for User Story 3

- [ ] T020 [US3] In `bin/fm-teardown.sh`, add `teardown_stop_browser_session` using `fm_browser_session_name` and `fm_run_timed` with a `FM_TEARDOWN_BROWSER_STOP_TIMEOUT` bound (default 15, invalid values fall back), and call it right after the leaked-process cleanup and pipeline-spend block, so T015 to T019 pass [A9] [A10] [A11] [A12] [A13] [U10] [U11]
- [ ] T021 [US3] Outer-loop gate: confirm A9 to A13 are green through `bin/fm-test-run.sh tests/fm-teardown.test.sh` before calling User Story 3 complete [A9] [A10] [A11] [A12] [A13]

**Checkpoint**: cleanup stops the task's session and never blocks.

## Phase 6: User Story 4 - The shared default session is never touched (Priority: P1)

**Goal**: the default session and any session that is not the task's own are left alone.

**Independent Test**: spawn and clean up a task whose id is `default`, and clean up while the caller's environment names another session.

### Tests for User Story 4 (write first, confirm they fail)

- [ ] T022 [US4] Add a spawn case for id `default` asserting the agent sees no Firstmate-exported session [A14], in `tests/fm-spawn-compact-adviser-disable.test.sh`
- [ ] T023 [US4] Add a cleanup case for id `default` asserting the fake sees no call [A15], in `tests/fm-teardown.test.sh`
- [ ] T024 [US4] Add a cleanup case whose caller exports `CHROME_DEVTOOLS_AXI_SESSION=default`, and another whose caller exports another name, asserting the stop still carries the task id [A16], in `tests/fm-teardown.test.sh`
- [ ] T025 [US4] Add a cleanup case for a legacy path-safe id longer than 64 characters asserting no call [A17], in `tests/fm-teardown.test.sh`

### Implementation for User Story 4

- [ ] T026 [US4] Confirm T022 to T025 pass with T003, T009, and T020 as written; if any fails, correct the helper or the call site and record the finding in `specs/004-worker-browser-session/tdd/cycle-log.md` [A14] [A15] [A16] [A17]
- [ ] T027 [US4] Outer-loop gate: confirm A14 to A17 are green before calling User Story 4 complete [A14] [A15] [A16] [A17]

**Checkpoint**: the default session is never touched in any test.

## Phase 7: Polish and cross-cutting

- [ ] T028 [P] Update the `Launch environment` paragraph in `bin/fm-spawn.sh`'s header to name `CHROME_DEVTOOLS_AXI_SESSION` beside the `FM_TASK_INBOX` sentence
- [ ] T029 [P] Add a short "Fix 4" paragraph to `bin/fm-teardown.sh`'s header describing the bounded best-effort stop and its position after the reaper
- [ ] T030 [P] In `docs/configuration.md`, add one sentence to the worker launch environment section stating the variable is exported on every local launch and survives the allowlist, add `CHROME_DEVTOOLS_AXI_SESSION` to the internal-variables list beside `FM_TASK_INBOX`, and add `FM_TEARDOWN_BROWSER_STOP_TIMEOUT` beside `FM_TEARDOWN_NM_TIMEOUT`, one sentence per line
- [ ] T031 Update the header comment of `tests/fm-spawn-compact-adviser-disable.test.sh` and `tests/fm-teardown.test.sh` so each names the new coverage
- [ ] T032 Run `bin/fm-lint.sh`, `bin/fm-doc-audience-check.sh`, `bin/fm-test-run.sh --check-coverage`, and both focused test files; record the results in `specs/004-worker-browser-session/tdd/verification.md`
- [ ] T033 Run the `quickstart.md` validation and confirm every expected outcome

## Dependencies and execution order

- Phase 1, then Phase 2, then Phases 3 to 6 in order (they share two test files, so they are sequential), then Phase 7.
- Within each story phase, tests precede implementation and must be seen failing for the right reason first.
- T028 to T030 touch different files and may run in parallel.

## Implementation strategy

- MVP is Phases 1 to 3: the launch export alone already separates workers.
- Phase 5 follows so bridges do not leak, and Phases 4 and 6 lock in the allowlist and default-session guarantees with tests.
