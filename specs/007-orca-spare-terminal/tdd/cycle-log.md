# Cycle Log: Orca Spare Terminal

Append only. Newest last.
Every entry's red block is the evidence that the test existed and failed before the implementation.

## Baseline

- `bin/fm-test-run.sh tests/fm-backend-orca.test.sh` on an unmodified export of `46987259` -> `FM_TEST_SUMMARY total=1 failed=0` (238 s)
- `bin/fm-test-run.sh tests/fm-spawn-orca-worktree.test.sh` -> `total=1 failed=0` (22 s)
- `bin/fm-test-run.sh tests/fm-backend-orca-lab-guard.test.sh` -> `total=1 failed=0` (66 s)
- opt-in live lab, `FM_ORCA_LIVE_SECTIONS=orca`, isolated runtime -> `summary: passed=23 findings=4`
- full profile suite: not run here, left to CI
- commit: `46987259`

Method notes:

- `tests/fm-backend-orca.test.sh` has no per-test selector, so each red below was observed by running only the named test function through a scratch wrapper that sources the same file; nothing in the wrapper is committed.
- The shared fake Orca now answers `terminal list` from keyed files without advancing the numbered response sequence, so every existing numbered case keeps its meaning.
- One commit per cycle holds the tests and the adapter change together.

## Cycle 1: U1-U5 the parser reads a usable row of a `terminal list` result

- tests (new): `test_json_get_listed_terminal_reads_the_first_handle`, `test_json_get_listed_terminal_skips_unusable_rows`
- red against the unchanged adapter: `not ok - listed-terminal-handle should read the first usable row, got ''`
- green: `fm_backend_orca_json_get` gains the field `listed-terminal-handle <worktree id>`: the first `result.terminals[]` row with a non-empty string handle, not `orphaned`, not `writable:false`, and, when it names a worktree, the requested one.
- refactor: none.

## Cycle 2: U6, U7, A1 worktree create adopts the listed terminal

- tests (new): `test_worktree_create_adopts_the_listed_terminal_as_the_third_field` (U6), `test_worktree_create_titles_the_listed_terminal` (U7), `test_spawn_adopts_the_listed_terminal_when_the_response_names_none` (A1)
- red against the cycle 1 adapter, each run alone:
  - U6 `not ok - worktree create should print id, path, and the listed handle, got 'wt-create-list-adopt::/orca/wt-create-list-adopt	/tmp/orca-wt'`
  - U7 `not ok - worktree create should title the listed terminal exactly once`
  - A1 `not ok - spawn should adopt the listed terminal`
- green: `fm_backend_orca_terminal_list_adopt <worktree id>` runs `orca terminal list --worktree id:<id> --json`, prints the parser's handle, and never fails; `fm_backend_orca_worktree_create` calls it only when the response named no terminal, before the path check.
- refactor: none.

## Cycle 3: A2-A8 guards around the adoption (characterization, mutant-checked)

- tests (new): `test_spawn_does_not_list_terminals_when_the_response_names_one` (A2), `test_spawn_creates_one_terminal_when_the_list_is_empty` (A3), `test_spawn_creates_a_terminal_when_the_list_cannot_be_read` (A4), `test_spawn_creates_a_terminal_when_no_listed_terminal_is_usable` (A5), `test_spawn_with_a_pathless_listed_terminal_closes_and_releases_everything` (A6), `test_spawn_succeeds_when_titling_the_listed_terminal_fails` (A7), `test_teardown_closes_exactly_the_adopted_listed_terminal` (A8)
- red: these constrain behavior the cycle 2 implementation already had by construction, so they passed on first run, with one exception: A5 first failed with `not ok - spawn should create exactly one terminal when no listed terminal is usable` because the test's own second row was a usable terminal of the same worktree; the row was corrected to an unwritable one and the test then passed.
  They are therefore recorded as guards, and their strength is established by the deliberate mutants in `verification.md`, not by a red run.
- green: no adapter change.
- refactor: none.
