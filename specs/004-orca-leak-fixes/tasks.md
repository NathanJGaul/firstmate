# Tasks: Orca Backend Leak Fixes

**Input**: `specs/004-orca-leak-fixes/` (spec.md, plan.md, research.md, quickstart.md, tdd/test-list.md)

**Tests**: Required, not optional.
Every behavior test precedes its implementation task, and each test must be seen failing for the right reason first, with the failure recorded in `tdd/cycle-log.md`.
All tests extend `tests/fm-backend-orca.test.sh`; run with `bin/fm-test-run.sh tests/fm-backend-orca.test.sh`.

## Format: `[ID] [P?] [Behaviors] [Story] Description`

- **[P]**: can run in parallel (different files, no dependencies)
- **[A1,U1]**: the behavior ids from `tdd/test-list.md` that the task covers; `/speckit.tdd.run` ticks a behavioral task only from these markers
- **[Story]**: US1 is the single-terminal story, US2 is the branch-deleting release story

## Phase 1: Setup

- [X] T001 Run the baseline `bin/fm-test-run.sh tests/fm-backend-orca.test.sh` and `bin/fm-test-run.sh tests/fm-teardown-endpoint-safety.test.sh`, and record that both are green before any edit (recorded in `tdd/cycle-log.md`).

## Phase 2: Foundational

- [ ] T002 Add shared fake-Orca response helpers to `tests/fm-backend-orca.test.sh` (a worktree-create response builder taking the terminal shape, and a log helper counting `terminal create` and `terminal rename` lines) so every new case reads its evidence the same way.

## Phase 3: User Story 1 - An Orca task has exactly one terminal (Priority: P1)

**Goal**: a startup terminal is adopted, titled, and recorded, and no second terminal is created.

**Independent Test**: spawn and adapter cases against the fake Orca in `tests/fm-backend-orca.test.sh`.

### Tests for User Story 1 (write first, see them fail)

- [ ] T003 [U1,U2,U3,U4,U5,U6] [US1] Test: `fm_backend_orca_json_get worktree-terminal-handle` reads `startupTerminal.handle` when `spawned` is `true` or absent, ignores it when `spawned` is `false` or the handle is empty or absent, prefers `result.terminal` when both are present, and `terminal-handle` still ignores `startupTerminal`, in `tests/fm-backend-orca.test.sh`.
- [ ] T004 [U7,U8,U11] [US1] Test: `fm_backend_orca_worktree_create` prints the startup handle as the third field, issues exactly one `terminal rename` with the task name as title, and issues none when no terminal is returned, in `tests/fm-backend-orca.test.sh`.
- [ ] T005 [U9,U10] [US1] Test: `fm_backend_orca_worktree_create` still succeeds when the rename exits non-zero and when it reports `ok:false`, in `tests/fm-backend-orca.test.sh`.
- [ ] T006 [U12] [US1] Test: `fm_backend_orca_worktree_create` with a startup terminal and no path closes the terminal, releases the worktree, issues no rename, and fails, in `tests/fm-backend-orca.test.sh`.
- [ ] T007 [A1] [US1] Test: spawn against a fake Orca that reports a startup terminal records `terminal=<handle>` in task metadata, logs zero `terminal create` and one rename, and sends the launch through that terminal, in `tests/fm-backend-orca.test.sh`.
- [ ] T008 [P] [A2] [US1] Test: spawn with a `terminal` result adopts it with no create, and with both shapes records the `terminal` one, in `tests/fm-backend-orca.test.sh`.
- [ ] T009 [P] [A3] [US1] Test: spawn with neither shape logs exactly one `terminal create` titled with the task name and no rename, in `tests/fm-backend-orca.test.sh`.
- [ ] T010 [P] [A4] [US1] Test: spawn with `spawned:false`, an empty handle, and a missing handle each creates one titled terminal, in `tests/fm-backend-orca.test.sh`.
- [ ] T011 [P] [A5] [US1] Test: spawn with a startup terminal and no path fails, closes that terminal, releases the worktree, and issues no rename, in `tests/fm-backend-orca.test.sh`.
- [ ] T012 [P] [A6] [US1] Test: spawn succeeds with the adopted terminal recorded when the rename fails, in `tests/fm-backend-orca.test.sh`.

### Implementation for User Story 1

- [ ] T013 [U1,U2,U3,U4,U5,U6] [US1] Make `fm_backend_orca_json_get worktree-terminal-handle` fall back to `result.startupTerminal.handle` when `spawned` is not `false`, keeping `result.terminal` first, in `bin/backends/orca.sh`.
- [ ] T014 [U7,U8,U9,U10,U11,U12] [US1] Make `fm_backend_orca_worktree_create` title the adopted terminal with `orca terminal rename --terminal <handle> --title <name> --json` after the path resolves, ignoring a failure, in `bin/backends/orca.sh`.
- [ ] T015 [US1] Update the `fm_backend_orca_json_get` header comment and the terminal-shape statements in `bin/backends/orca.sh` so they name both shapes accurately.

**Checkpoint**: US1 tests green; a spawn leaves one terminal.

## Phase 4: User Story 2 - Releasing an Orca task removes the branch Orca made (Priority: P1)

**Goal**: the Orca release passes the safe branch-deleting option and never a forced one.

**Independent Test**: release and teardown cases against the fake Orca in `tests/fm-backend-orca.test.sh`.

### Tests for User Story 2 (write first, see them fail)

- [ ] T016 [U13] [US2] Test: `fm_backend_orca_remove_worktree` logs exactly `worktree rm --worktree id:<id> --force --delete-branch --json`, in `tests/fm-backend-orca.test.sh`.
- [ ] T017 [A7,A9] [US2] Update the existing `worktree rm` assertions in `tests/fm-backend-orca.test.sh` (path-missing, pathless cleanup, nonisolated worktree, terminal-create failure, abort-cleanup failure, metadata-write failure, scout teardown, missing-path teardown, ship teardown, secondmate child cleanup) to expect `--force` followed by `--delete-branch`.
- [ ] T018 [A8] [US2] Test: a teardown whose release result is an ok result that reports the branch kept completes and removes the task records, in `tests/fm-backend-orca.test.sh`.
- [ ] T019 [A10,U14,U15] [US2] Confirm the existing refusal tests (id or path mismatch, unresolvable id, empty id, `ok:false` release) stay green and unchanged; no new test.

### Implementation for User Story 2

- [ ] T020 [U13,A7,A8,A9] [US2] Add `--delete-branch` after `--force` in `fm_backend_orca_remove_worktree` in `bin/backends/orca.sh`.

**Checkpoint**: US2 tests green; teardown and abort cleanup both release with the safe option.

## Phase 5: Polish and cross-cutting

- [ ] T021 [P] Update the spawn and release statements in `docs/orca-backend.md` (startup terminal adopted, release deletes the Orca-made branch only when Orca proves it merged), qualified as proven against the fake only.
- [ ] T022 [P] Add the new cases to the fake-suite coverage sentence in `docs/verification/runtime-backends.md`, with no live claim.
- [ ] T023 Run `bin/fm-lint.sh`, `bin/fm-doc-audience-check.sh`, `bin/fm-test-run.sh tests/fm-backend-orca.test.sh`, `bin/fm-test-run.sh tests/fm-teardown-endpoint-safety.test.sh`, and `bin/fm-test-run.sh --check-coverage`.
- [ ] T024 Confirm `git status` shows no deleted branch or stray file in any project, and that no test or fixture issues `git branch -D` against a path outside its own temporary root (FR-009).

## Phase 6: Outer-loop gates

One per acceptance behavior; the story is not complete until its outer-loop test is green.

- [ ] T025 [A1] Outer loop A1 green: startup terminal adopted, titled, recorded, no second terminal.
- [ ] T026 [A2] Outer loop A2 green: `terminal` shape adopted and winning.
- [ ] T027 [A3] Outer loop A3 green: neither shape creates exactly one terminal.
- [ ] T028 [A4] Outer loop A4 green: not-started or handle-less startup terminal falls back to create.
- [ ] T029 [A5] Outer loop A5 green: pathless startup-terminal spawn closes and releases.
- [ ] T030 [A6] Outer loop A6 green: a failing rename does not fail the spawn.
- [ ] T031 [A7] Outer loop A7 green: ship teardown releases with `--force --delete-branch`.
- [ ] T032 [A8] Outer loop A8 green: a kept branch does not fail teardown.
- [ ] T033 [A9] Outer loop A9 green: spawn abort cleanup releases with the same option.
- [ ] T034 [A10] Outer loop A10 green: refusals log no release.

## Dependencies

- T002 first; T001 is done.
- US1 and US2 are independent of each other; each runs tests, then implementation.
- T017 fails first (the existing assertions now expect the new argument) and passes with T020.
- Polish runs after both stories; outer-loop gates close out each story.
