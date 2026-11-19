# Tasks: Orca Spare Terminal

## Phase 1: Setup

- [X] T001 Verify `.specify/`, the TDD extension, and `.specify/memory/tdd-profile.md` exist, and record baseline results in `tdd/cycle-log.md`.
- [X] T002 Observe the live `terminal list --worktree` response shape and timing in the isolated lab and record it in `research.md` R1 and R2.

## Phase 2: Tests first (US1, US2)

- [X] T003 [U1] Test: `fm_backend_orca_json_get listed-terminal-handle <id>` reads the first usable row and skips orphaned, unwritable, other-worktree, and empty-handle rows, in `tests/fm-backend-orca.test.sh`.
- [X] T004 [U2] Test: `fm_backend_orca_worktree_create` with no response terminal adopts the listed terminal, titles it, and prints it as the third field.
- [X] T005 [A1] Test: spawn with no response terminal and one listed terminal records it, logs zero `terminal create` and one rename.
- [X] T006 [A2] Test: spawn with a `terminal` or spawned `startupTerminal` response issues no `terminal list`.
- [X] T007 [A3] Test: spawn with no response terminal and an empty list creates exactly one terminal.
- [X] T008 [A4] Test: a list that fails, reports an error, or is unparseable falls back to one created terminal and the spawn succeeds.
- [X] T009 [A5] Test: a list of only unusable terminals falls back to one created terminal.
- [X] T010 [A6] Test: a pathless worktree with a listed terminal closes it, releases the worktree, and issues no rename.
- [X] T011 [A7] Test: a failing rename of the listed terminal does not fail the spawn.
- [X] T012 [A8] Test: teardown of a task whose recorded terminal was adopted from the list closes exactly that handle.

## Phase 3: Implementation

- [X] T013 Make the shared fake Orca answer `terminal list` from a keyed file without advancing the numbered sequence.
- [X] T014 [U1] Add the `listed-terminal-handle` field to `fm_backend_orca_json_get`.
- [X] T015 [U2,A1..A7] Add `fm_backend_orca_terminal_list_adopt` and use it in `fm_backend_orca_worktree_create` before the path check.

## Phase 4: Live lab and documentation

- [X] T016 Turn the lab's spare-terminal finding into a hard `liveTerminalCount=1` assertion after spawn, and record the list shape.
- [X] T017 Run the isolated live lab and keep its output as evidence outside the worktree.
- [X] T018 Update `docs/orca-backend.md` and `docs/verification/runtime-backends.md`.

## Phase 5: Verify

- [X] T019 `/speckit.tdd.verify`: test-first evidence, deliberate mutants, acceptance coverage.
- [X] T020 Run the touched suites, `bin/fm-lint.sh`, and `bin/fm-doc-audience-check.sh`.
- [X] T021 `/speckit.implement` remainder, `/speckit.checklist`, `/speckit.analyze`, `/speckit.converge`.
