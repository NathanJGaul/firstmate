# Tasks: Orca Adapter Hygiene

**Input**: `specs/005-orca-adapter-hygiene/` (spec.md, plan.md, tdd/test-list.md)

**Tests**: Required, not optional.
Every behavior test precedes its implementation task, and each test must be seen failing for the right reason first, with the failure recorded in `tdd/cycle-log.md`.
Adapter tests extend `tests/fm-backend-orca.test.sh`; bootstrap tests extend `tests/fm-bootstrap.test.sh`.
Run with `bin/fm-test-run.sh <file>`.

## Format: `[ID] [P?] [Behaviors] [Story] Description`

- **[P]**: can run in parallel (different files, no dependencies)
- **[A1,U1]**: the behavior ids from `tdd/test-list.md` that the task covers
- **[Story]**: US1 folder refusal, US2 CLI discovery, US3 Linux install hint

## Phase 1: Setup

- [ ] T001 Run the baseline `bin/fm-test-run.sh tests/fm-bootstrap.test.sh` and record it in `tdd/cycle-log.md`; the Orca adapter suite baseline is recorded the same way when the host allows (it is long and the host is shared).
- [ ] T002 Pin `HOME` and `ORCA_CLI_BIN_DIR` in the one existing adapter test that runs with no `orca` on `PATH` (`test_kill_refuses_when_the_orca_cli_is_absent`), so the new `~/.orca/cli/bin` fallback can never reach the operator's real Orca CLI from a test.

## Phase 2: User Story 1 - Folder repositories refused early (P1)

### Tests (write first, see them fail)

- [ ] T003 [U1,U2] [US1] Test: `fm_backend_orca_json_get repo-kind` reads `result.repo.kind`, falls back to `result.kind`, and is empty when absent, in `tests/fm-backend-orca.test.sh`.
- [ ] T004 [U3,U4] [US1] Test: `fm_backend_orca_repo_ensure` refuses a `folder` kind naming the project and `--backend` and issues only `repo show`; returns the id for `git` and for no kind, in `tests/fm-backend-orca.test.sh`.
- [ ] T005 [A1] [US1] Test: `fm-spawn --backend orca` for a folder-registered project fails with the refusal and the fake log holds no `repo add`, `repo rm`, `repo set`, `worktree create`, or `terminal` call, in `tests/fm-backend-orca.test.sh`.

### Implementation

- [ ] T006 [U1,U2] [US1] Add the `repo-kind` field to `fm_backend_orca_json_get` in `bin/backends/orca.sh`.
- [ ] T007 [U3,U4,A1] [US1] Make `fm_backend_orca_repo_ensure` read the kind from `repo show` and refuse `folder` in `bin/backends/orca.sh`.

## Phase 3: User Story 2 - CLI discovery (P1)

### Tests (write first, see them fail)

- [ ] T008 [U5,U6,U7,U8,U9] [US2] Test: the tool check order and skipping rules, with a later call proving the resolved CLI is the one run, in `tests/fm-backend-orca.test.sh`.
- [ ] T009 [U10] [US2] Test: nothing found refuses, names all three locations and the fix, keeps the existing "not installed" wording, and makes no Orca call, in `tests/fm-backend-orca.test.sh`.
- [ ] T010 [U11] [US2] Test: a whole `fm_backend_orca_worktree_create` completes with the CLI only under `ORCA_CLI_BIN_DIR`, in `tests/fm-backend-orca.test.sh`.
- [ ] T011 [A2] [US2] Test: `fm-spawn --backend orca` completes with the CLI only under `ORCA_CLI_BIN_DIR`, in `tests/fm-backend-orca.test.sh`.
- [ ] T012 [A3] [US2] Test: bootstrap with `backend=orca` and the CLI only under `ORCA_CLI_BIN_DIR` does not report `orca` missing, in `tests/fm-bootstrap.test.sh`.

### Implementation

- [ ] T013 [U5,U6,U7,U8,U9,U10] [US2] Resolve the CLI in `fm_backend_orca_tool_check` in `bin/backends/orca.sh`.
- [ ] T014 [U11,A2] [US2] Call the tool check at the top of `fm_backend_orca_worktree_create` in `bin/backends/orca.sh`.
- [ ] T015 [A3] [US2] Route `orca:orca` through the adapter tool check in `fm_backend_required_tool_available` in `bin/fm-backend.sh`.

## Phase 4: User Story 3 - Install hint (P2)

- [ ] T016 [A4,A5] [US3] Test: bootstrap's `orca` hint with a fake `uname` for Linux and Darwin, and update the existing exact-string expectation to be platform-aware, in `tests/fm-bootstrap.test.sh`.
- [ ] T017 [A4,A5] [US3] Split `orca` out of the shared Homebrew line in `install_cmd` in `bin/fm-bootstrap.sh`.

## Phase 5: Polish

- [ ] T018 Patch `docs/orca-backend.md` for the resolution order and the folder refusal; run `bin/fm-doc-audience-check.sh`.
- [ ] T019 Run `bin/fm-lint.sh`, both test files, and `bin/fm-test-run.sh --check-coverage`.
- [ ] T020 Complete `tdd/verification.md`, `checklist.md`, `analyze.md`, and `converge.md`.
