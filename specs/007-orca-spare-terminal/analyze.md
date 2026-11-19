# Analysis: Orca Spare Terminal

Cross-artifact consistency of `spec.md`, `plan.md`, `tasks.md`, the tests, and the implementation.

## Requirement coverage

| requirement | tasks | tests | implementation |
| ----------- | ----- | ----- | -------------- |
| FR-001 adopt the first usable listed terminal | T003, T004, T014, T015 | U1-U5, U6, A1, A5 | `fm_backend_orca_json_get listed-terminal-handle`, `fm_backend_orca_terminal_list_adopt` |
| FR-002 response terminal wins, no list | T006 | A2 | the `[ -n "$terminal" ] ||` guard in `fm_backend_orca_worktree_create` |
| FR-003 title the adopted terminal | T004, T011 | U7, A1, A7 | the existing rename after the path check |
| FR-004 no second terminal | T005 | A1 | `bin/fm-spawn.sh` skips `terminal create` when a third field is returned (unchanged) |
| FR-005 fall back to create | T007, T008, T009 | A3, A4, A5 | the adopt function never fails |
| FR-006 pathless worktree closes the terminal | T010 | A6 | adoption runs before the path check |
| FR-007 teardown closes exactly the recorded terminal | T012 | A8, A9 | `fm-teardown.sh` unchanged |
| FR-008 never touch another worktree's terminal | T003 | U4, A5 | the `worktreeId` filter |
| FR-009 stdout contract and metadata unchanged | T004 | U6 | unchanged |

## Findings

- No requirement lacks a task or a test, and no task lacks a requirement.
- The spec's assumption that the list reports the terminal on the first poll is backed by `research.md` R2 and the lab; the failure mode if it does not hold is the pre-fix behavior, which the spec states.
- The plan's "two documentation edits" became two files with several edits each; the extra edits were needed to remove statements the fix made false (the two-live-terminals limit and the two findings), not new scope.
- The plan named the lab change as "a hard assertion"; the lab also now asserts that the one live terminal is the recorded one, which is the same acceptance scenario made stricter.
