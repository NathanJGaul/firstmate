---
feature: 004-orca-leak-fixes
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 9
planned_at: af20b2c9
updated_at: af20b2c9
suite_baseline: unknown
---

# Test List: Orca Backend Leak Fixes

Baseline note: the two suites that exercise the changed code were run green before any edit (`tests/fm-backend-orca.test.sh`, `tests/fm-teardown-endpoint-safety.test.sh`).
The profile's full suite was not run here, so `suite_baseline` is `unknown` rather than `green`; broad regression coverage is owned by CI.
No component below lacks tests, so there are no characterization-first behaviors.

All tests live in `tests/fm-backend-orca.test.sh` and use the fake `orca` CLI already in that file.
`traces` values name spec acceptance scenarios (`US1.n`, `US2.n`), functional requirements (`FR-nnn`), and the spec's edge cases (`EC`).

## Outer loop: acceptance behaviors

Each runs through a real entry point, `bin/fm-spawn.sh --backend orca` or `bin/fm-teardown.sh`, against the fake Orca.

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| A1  | A spawn whose worktree creation reports a started startup terminal records that terminal in task metadata, titles it with the task name, creates no second terminal, and launches the harness through it | US1.1, FR-001, FR-003, FR-004 | example | PENDING | |
| A2  | A spawn whose worktree creation reports a `terminal` adopts it with no create, and when a startup terminal is also reported the `terminal` one is recorded | US1.2, FR-002, FR-004 | example | PENDING | |
| A3  | A spawn whose worktree creation reports neither shape creates exactly one terminal titled with the task name, issues no rename, and records it | US1.3, FR-005 | example | PENDING | |
| A4  | A spawn whose startup terminal is reported not started, or has an empty or missing handle, creates one titled terminal instead | US1.4, FR-001, FR-005 | example | PENDING | |
| A5  | A spawn whose worktree creation reports a startup terminal and no path fails, closes that terminal, releases the worktree, and issues no rename | US1.5, FR-006 | example | PENDING | |
| A6  | A failing title rename leaves the spawn successful with the adopted terminal recorded | EC, FR-003 | example | PENDING | |
| A7  | Tearing down an Orca ship task releases its worktree with `--force --delete-branch` and succeeds | US2.1, FR-007 | example | PENDING | |
| A8  | A release in which Orca reports success but keeps the branch completes teardown and removes the task records | US2.2 | example | PENDING | |
| A9  | A spawn that fails after the worktree was created releases the worktree with the same branch-deleting release | US2.3, FR-007 | example | PENDING | |
| A10 | Every teardown refusal (id or path mismatch, unresolvable id) logs no worktree release | US2.4, FR-008 | example | DONE | `tests/fm-backend-orca.test.sh` refusal cases at the four `assert_not_contains ... worktree rm` sites |

## Inner loop: unit behaviors

### `bin/backends/orca.sh` - `fm_backend_orca_json_get`

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| U1  | `worktree-terminal-handle` returns `result.startupTerminal.handle` when `spawned` is `true` | FR-001 | example | PENDING | |
| U2  | `worktree-terminal-handle` returns the startup handle when `spawned` is absent (boundary: not `false`) | FR-001 | example | PENDING | |
| U3  | `worktree-terminal-handle` returns nothing when `spawned` is `false` (boundary: `false` side) | FR-001 | example | PENDING | |
| U4  | `worktree-terminal-handle` returns nothing for an empty or absent startup handle | FR-001, EC | example | PENDING | |
| U5  | `worktree-terminal-handle` returns `result.terminal.handle` when both shapes are present | FR-002 | example | PENDING | |
| U6  | `terminal-handle`, used to parse a `terminal create` result, still ignores `startupTerminal` | FR-001 | example | PENDING | |

### `bin/backends/orca.sh` - `fm_backend_orca_worktree_create`

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| U7  | Prints `<id> <path> <startup handle>` for a startup-terminal result | FR-001 | example | PENDING | |
| U8  | Issues exactly one `terminal rename --terminal <handle> --title <name>` for an adopted terminal | FR-003 | example | PENDING | |
| U9  | Returns success when the rename exits non-zero | FR-003, EC | example | PENDING | |
| U10 | Returns success when the rename reports `ok:false` | FR-003, EC | example | PENDING | |
| U11 | Issues no rename when no terminal is returned | FR-005 | example | PENDING | |
| U12 | With a startup terminal and no path, closes the terminal, releases the worktree, issues no rename, and fails | FR-006 | example | PENDING | |

### `bin/backends/orca.sh` - `fm_backend_orca_remove_worktree`

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| U13 | Calls `orca worktree rm --worktree id:<id> --force --delete-branch --json` and nothing else | FR-007 | example | PENDING | |
| U14 | Refuses an empty worktree id without calling Orca | FR-008 | example | DONE | `tests/fm-backend-orca.test.sh::test_remove_worktree_refuses_empty_id` |
| U15 | Fails on an Orca `ok:false` result and surfaces its message | FR-008 | example | DONE | `tests/fm-backend-orca.test.sh::test_remove_worktree_rejects_orca_error_json` |

## Invariants and edge cases still to place

- A `terminal create` fallback result is still parsed through the shapes it was parsed through before; the existing `test_json_get_ignores_undocumented_terminal_id_shapes` and `test_worktree_and_terminal_helpers_parse_json` already pin this and must stay green unchanged.
- No test or fixture issues a branch deletion against anything outside its own temporary repository (FR-009); checked in the polish task rather than by a new test.

## Out of scope

- Live proof against a real Orca runtime: no Linux Orca lab exists, so the single live terminal and the landed-versus-unlanded branch outcomes are not testable here.
- Deleting the existing stale branch in `projects/pricing-sheet`: a separate captain call.
- Other evaluation-plan slices (folder-kind rejection, CLI discovery, version gate, Escape, recovery, receipts): separate workers.

## Verification commands

Copied verbatim from `.specify/memory/tdd-profile.md` at planning time:

- Single test: `bin/fm-test-run.sh {file}`
- Full suite: `bin/fm-test-run.sh --all --exclude-family real-herdr-gated --exclude-family live-harness-optin`
- Coverage: `bin/fm-test-run.sh --check-coverage`
- Mutation: none installed; high-risk behavior gets deliberate-mutant checks in `tdd/verification.md`.
