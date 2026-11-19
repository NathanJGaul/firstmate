# TDD Verification: Orca Spare Terminal

Verdict: PASS, with the limits listed at the end.

## Test-first evidence

- Cycle 1 (commit `623b16cc` carries all three cycles together): U1 and U2 were written first and failed with `not ok - listed-terminal-handle should read the first usable row, got ''` against the unchanged adapter.
- Cycle 2: U6, U7, and A1 failed against the cycle 1 adapter, each run alone (see `cycle-log.md`).
- Cycle 3: A2-A8 are guards over behavior the cycle 2 implementation already had by construction, and `cycle-log.md` says so; they are not claimed as red-first.
- The live assertion (A9) was shown red against the previous adapter and green against the new one:
  - previous adapter: `not ok - F: after fm-spawn the task worktree holds 2 listed and 2 live terminals, not exactly 1 (a spare terminal leaked)`
  - new adapter: `ok - F: after fm-spawn the task worktree holds exactly one live terminal, and it is the recorded one (worktree ps liveTerminalCount=1)`

## Deliberate mutants

No mutation tool is installed for Bash, so each guard was checked against a deliberate mutant of `bin/backends/orca.sh`, each reverted afterwards.

| mutant | change | killed by |
| ------ | ------ | --------- |
| M1 | always list terminals, even when the response names one | `test_spawn_does_not_list_terminals_when_the_response_names_one` |
| M2 | drop the orphaned check | `test_json_get_listed_terminal_skips_unusable_rows` |
| M2b | drop the worktree-id check | `test_json_get_listed_terminal_skips_unusable_rows` |
| M2c | drop the writable check | `test_json_get_listed_terminal_skips_unusable_rows` |
| M3 | an unreadable list aborts the create | `test_spawn_creates_a_terminal_when_the_list_cannot_be_read` |
| M4 | adopt the listed terminal after the path check | `test_spawn_with_a_pathless_listed_terminal_closes_and_releases_everything` |
| M5 | return the listed terminal without titling it | `test_worktree_create_titles_the_listed_terminal` |

All seven mutants were killed.

## Acceptance coverage

| scenario | tests | real entry point |
| -------- | ----- | ---------------- |
| US1.1 listed terminal adopted | A1, U1, U6, U7, A9 | `fm-spawn.sh`, live lab |
| US1.2 empty list creates one | A3 | `fm-spawn.sh` |
| US1.3 response terminal wins, no list | A2 | `fm-spawn.sh` |
| US1.4 unreadable list falls back | A4 | `fm-spawn.sh` |
| US1.5 unusable or foreign rows | A5, U2-U5 | `fm-spawn.sh` |
| US1.6 pathless worktree | A6 | `fm-spawn.sh` |
| US2.1 teardown closes exactly the recorded terminal | A8 | `fm-teardown.sh` |
| US2.2 zero leftovers live | A9 | live lab final inventory |

## Test smells

- No assertion reads adapter source bytes; every test drives the adapter, `fm-spawn.sh`, or `fm-teardown.sh` through the fake `orca` CLI and inspects its call log and the task metadata.
- Fixtures use the response shape observed live, including `worktreeId`, `orphaned`, and `writable`.
- No test is skipped, weakened, or filtered.

## Limits

- No coverage or mutation tool exists for this Bash stack; the mutants above stand in for it.
- The adoption was proven live only on the Linux headless runtime 1.4.261; macOS and the desktop app were not available.
- A runtime that creates its terminal asynchronously after the response returns would fall back to creating one terminal, the pre-fix behavior; no such runtime was observed.
