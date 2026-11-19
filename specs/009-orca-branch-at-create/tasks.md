# Tasks: Orca Branch At Create

**Input**: `specs/009-orca-branch-at-create/` (spec.md, plan.md, tdd/test-list.md)

**Tests**: Required, not optional.
Every behavior test precedes its implementation task, and each test must be seen failing for the right reason first, with the failure recorded in `tdd/cycle-log.md`.

## Format: `[ID] [Behaviors] [Story] Description`

## Phase 1: Setup

- [X] T001 Run the baseline `bin/fm-test-run.sh` for `tests/fm-backend-orca.test.sh`, `tests/fm-spawn-orca-worktree.test.sh`, `tests/fm-brief.test.sh`, and record each result in `tdd/cycle-log.md` before any edit.

## Phase 2: Adapter and spawn (US1)

### Tests (write first, see them fail)

- [X] T002 [U1,U2] [US1] Add the argument cases to `tests/fm-backend-orca.test.sh`.
- [X] T003 [A1,A2,A3,A4] [US1] Make the spawn test's fake `orca` honor `--branch` and `--base-branch`, and add the four spawn cases.

### Implementation

- [X] T004 [U1,U2] [US1] Add the optional branch and base arguments to `fm_backend_orca_worktree_create`.
- [X] T005 [A1,A2,A3,A4] [US1] Pass them from the Orca arm of `bin/fm-spawn.sh` and add the branch proof.

## Phase 3: Brief (US2)

- [X] T006 [A5,A6,U3] [US2] Add the brief cases to `tests/fm-brief.test.sh` (and adapt the existing command-extraction test), see them fail.
- [X] T007 [A5,A6,U3] [US2] Change the first action and add the setup sentence in `bin/fm-brief.sh`.

## Phase 4: Teardown (US3)

- [X] T008 [A7] [US3] Add the teardown case to `tests/fm-backend-orca.test.sh` and see it fail.
- [X] T009 [A7] [US3] Drop the detach and `branch -D` from the Orca arm of `bin/fm-teardown.sh`.

## Phase 5: Live proof and records

- [X] T010 [A8] Extend the lab's firstmate level and run it with a pinned `HOME`.
- [X] T010b Fetch the base branch, pass `origin/<base>`, and report Orca's reason on a refused create (found by the lab; see `tdd/cycle-log.md` cycle 2).
- [X] T011 Correct `docs/orca-backend.md` and record the dated lab entry in `docs/verification/runtime-backends.md`.

## Phase 6: Gates

- [X] T012 Run `/speckit.tdd.verify` with deliberate mutants, `bin/fm-lint.sh`, `bin/fm-doc-audience-check.sh`, then `/speckit.implement`, `/speckit.checklist`, `/speckit.analyze`, and `/speckit.converge`.
