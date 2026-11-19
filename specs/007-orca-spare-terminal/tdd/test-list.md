---
feature: 007-orca-spare-terminal
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 9
planned_at: 46987259
updated_at: 46987259
suite_baseline: unknown
---

# Test List: Orca Spare Terminal

All tests live in `tests/fm-backend-orca.test.sh` and use its fake `orca` CLI, plus the live lab.
`traces` values name spec acceptance scenarios (`US1.n`, `US2.n`), functional requirements (`FR-nnn`), and edge cases (`EC`).

## Outer loop: acceptance behaviors

Each runs through a real entry point, `bin/fm-spawn.sh --backend orca` or `bin/fm-teardown.sh`, against the fake Orca.

| id | behavior | traces | kind | state | test |
| -- | -------- | ------ | ---- | ----- | ---- |
| A1 | A spawn whose creation response names no terminal and whose list holds one records that terminal, titles it once, and creates none | US1.1, FR-001, FR-003, FR-004 | example | DONE | `test_spawn_adopts_the_listed_terminal_when_the_response_names_none` |
| A2 | A spawn whose response names a `terminal` or a spawned `startupTerminal` never issues `terminal list` | US1.3, FR-002 | example | DONE | `test_spawn_does_not_list_terminals_when_the_response_names_one` |
| A3 | A spawn whose response names none and whose list is empty creates exactly one titled terminal | US1.2, FR-005 | example | DONE | `test_spawn_creates_one_terminal_when_the_list_is_empty` |
| A4 | A list that fails, reports an error, or is unparseable falls back to one created terminal and the spawn succeeds | US1.4, FR-005 | example | DONE | `test_spawn_creates_a_terminal_when_the_list_cannot_be_read` |
| A5 | A list holding only unusable terminals falls back to one created terminal | US1.5, FR-001 | example | DONE | `test_spawn_creates_a_terminal_when_no_listed_terminal_is_usable` |
| A6 | A pathless worktree with a listed terminal fails, closes the listed terminal, releases the worktree, and issues no rename | US1.6, FR-006 | example | DONE | `test_spawn_with_a_pathless_listed_terminal_closes_and_releases_everything` |
| A7 | A failing rename of the listed terminal leaves the spawn successful with the terminal recorded | EC, FR-003 | example | DONE | `test_spawn_succeeds_when_titling_the_listed_terminal_fails` |
| A8 | Teardown of a task whose recorded terminal was adopted from the list closes exactly that handle | US2.1, FR-007 | example | DONE | `test_teardown_closes_exactly_the_adopted_listed_terminal` |
| A9 | Live lab: after `fm-spawn --backend orca` the worktree holds exactly one live terminal, and teardown leaves zero leftovers | SC-003, US2.2 | live | DONE | `tests/fm-backend-orca-smoke.test.sh` section F |

## Inner loop: unit behaviors

### `bin/backends/orca.sh` - `fm_backend_orca_json_get listed-terminal-handle <id>`

| id | behavior | traces | kind | state | test |
| -- | -------- | ------ | ---- | ----- | ---- |
| U1 | Returns the first row's handle from `result.terminals[]` | FR-001 | example | DONE | `test_json_get_listed_terminal_reads_the_first_handle` |
| U2 | Skips an orphaned row | FR-001 | example | DONE | `test_json_get_listed_terminal_skips_unusable_rows` |
| U3 | Skips a row reported `writable:false`, keeps one with no `writable` field | FR-001 | example | DONE | same |
| U4 | Skips a row naming another worktree, keeps one that names none | FR-001, FR-008 | example | DONE | same |
| U5 | Skips an empty or missing handle, prints nothing and exits non-zero when nothing usable | FR-001 | example | DONE | same |

### `bin/backends/orca.sh` - `fm_backend_orca_worktree_create`

| id | behavior | traces | kind | state | test |
| -- | -------- | ------ | ---- | ----- | ---- |
| U6 | With no response terminal it asks `orca terminal list --worktree id:<id> --json` and prints the listed handle as the third field | FR-001, FR-009 | example | DONE | `test_worktree_create_adopts_the_listed_terminal_as_the_third_field` |
| U7 | The listed terminal is titled with the task name, and a rename that fails does not fail the create | FR-003 | example | DONE | `test_worktree_create_titles_the_listed_terminal` |
| U8 | A response terminal wins and no list is issued | FR-002 | example | DONE | covered by A2 |
