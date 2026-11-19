# Tasks: Orca Live Test Lab

**Input**: `specs/006-orca-test-lab/` (spec.md, plan.md, research.md, quickstart.md)

**Format**: `- [X] T### [P?] [US?] description with file path`

## Phase 1: Setup

- [X] T001 Confirm the baseline: `bin/fm-test-run.sh --check-coverage` and `tests/fm-backend-orca.test.sh` pass before any change

## Phase 2: Foundational (the guard library)

- [X] T002 [US1] [A1] [A2] [A3] [U1] [U2] [U3] [U4] [U5] [U6] [U7] Write `tests/fm-backend-orca-lab-guard.test.sh` cases for protected-path refusal (equal, child, parent, symlink, `$HOME`, `/`, orca install dir), non-empty directory refusal, and opt-in refusal; run and record the red in `specs/006-orca-test-lab/tdd/cycle-log.md`
- [X] T003 [US1] [A2] [A3] [U1] [U2] [U3] [U4] [U5] [U6] [U7] Create `tests/orca-lab-safety.sh` with the environment validation functions so T002 passes
- [X] T004 [US1] [A4] [U8] [U9] Add guard cases for the own-child proof (wrong pid, wrong environment owner, runtime id mismatch, operator pid) and for signal refusal of a non-lab process, using fake processes; record the red
- [X] T005 [US1] [A4] [U8] [U9] Implement `orca_lab_assert_own_runtime` and `orca_lab_signal` in `tests/orca-lab-safety.sh`
- [X] T006 [US1] [A5] [A6] [U10] [U11] Add guard cases for launcher generation (data directory pinned, caller Orca variables removed) and fake-runtime start and stop with leftover scan; record the red
- [X] T007 [US1] [A5] [A6] [U10] [U11] Implement lab creation, launcher, start, stop, and leftover scan in `tests/orca-lab-safety.sh`

## Phase 3: User Story 2 - Real shapes (the live lane)

- [X] T008 [US2] [A7] [A8] [A9] Create `tests/fm-backend-orca-smoke.test.sh` with the gate, lab start, and assertions 1 to 4 (status, repos and folder, worktree create, terminal count)
- [X] T009 [US2] [A10] [A11] [A12] Add assertions 5 to 8 (Escape, Ctrl+U, interrupt, wait; read status and source; fake agent identity; receipts and retry)
- [X] T010 [US2] [A13] [A14] Add assertions 9 and 10 (close and remove for landed and unmerged branches; runtime restart survival) and the assertion 11 not-run record

## Phase 4: User Story 3 - Firstmate-level checks

- [X] T011 [US3] [A15] Add the lab firstmate home and the spawn, peek, send text and key, and crew-state checks to `tests/fm-backend-orca-smoke.test.sh`
- [X] T012 [US3] [A16] [A17] Add the dirty and unlanded teardown refusals, the clean teardown, and the final inventory

## Phase 5: User Story 4 - Record and registration

- [X] T013 [P] [US4] [A18] Register both tests in `bin/fm-test-run.sh` (family classification and weight hints) and run `bin/fm-test-run.sh --check-coverage`
- [X] T014 [P] [US4] Add the Linux headless lab entry, per-assertion slice mapping, and unknowns to `docs/verification/runtime-backends.md`
- [X] T015 [US4] Run the live lane locally and paste its real shapes into the record

## Phase 6: Polish

- [X] T016 `bin/fm-lint.sh`, `bin/fm-doc-audience-check.sh`, the Orca regression list from report section 6.3, and a final inventory of leftover processes and directories

## Acceptance gates

- [X] T017 Outer loop green: A1 to A6 pass in the guard test and A7 to A17 show their lines in a local live run

## Phase 7: TDD remediation

- [X] T018 [U1] [U5] [U12] Finding 1: add relative-symlink, chained-symlink, parent-symlink, and dot-dot-after-link cases to `tests/fm-backend-orca-lab-guard.test.sh`; run `bin/fm-test-run.sh tests/fm-backend-orca-lab-guard.test.sh` and a deliberate mutant of `orca_lab_resolve`
