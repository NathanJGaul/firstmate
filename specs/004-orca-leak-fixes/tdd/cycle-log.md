# Cycle Log: Orca Backend Leak Fixes

Append only. Newest last.
Every entry's red block is the evidence that the test existed and failed before the implementation.

## Baseline

- suite: `bin/fm-test-run.sh tests/fm-backend-orca.test.sh` -> `FM_TEST_SUMMARY total=1 failed=0` (114 s)
- suite: `bin/fm-test-run.sh tests/fm-teardown-endpoint-safety.test.sh` -> `FM_TEST_SUMMARY total=1 failed=0` (233 s)
- full profile suite: not run here, left to CI
- commit: `af20b2c9`
- recorded: cycle 0, before any change

Method notes (strict redo, at the captain's direction):

- An earlier pass of this feature wrote 16 behaviors green-first; the captain chose to redo them as strict cycles, so the branch was rebuilt from the planning commit and that earlier pass is superseded.
- `tests/fm-backend-orca.test.sh` has no per-test selector, so each red below was observed by running only the named test function through a scratch wrapper that sources the same file; nothing in the wrapper is committed.
- Every cycle writes its tests first and runs them against the adapter as it stood, recording the failure, then adds the smallest implementation.
  Where one implementation step was too naive to be kept (an unconditional read, an unconditional rename, a strict failure), that is the point: the next behavior's test goes red against it and forces the real rule.
- Each cycle runs its new tests plus a fixed 8-test regression subset of the same file; the full suites run once at the end, as the host is overloaded.
- One commit per cycle holds the test and the adapter change together.

## Cycle 1: U1 and U7 the startup terminal is adopted and printed by worktree create

- tests (new): `test_json_get_adopts_startup_terminal_handle` (U1), `test_worktree_create_prints_the_startup_terminal_as_the_third_field` (U7)
- red against the unchanged adapter:
  - U1 `not ok - worktree-terminal-handle should read result.startupTerminal.handle, got ''`
  - U7 `not ok - worktree create should print id, path, and the startup handle, got 'wt-create-print-startup::/orca/wt-create-print-startup	/tmp/orca-wt'`
- green: `fm_backend_orca_json_get` reads `r.startupTerminal` first and unconditionally, as the one terminal object both handle fields use (deliberately naive; later cycles refine it). Both tests and the 8-test regression subset pass.
- refactor: none.

## Cycle 2: U6 terminal create parsing ignores the startup terminal

- test (new): `test_json_get_terminal_handle_field_ignores_startup_terminal` (U6)
- red against the cycle 1 adapter: `not ok - terminal-handle parses a terminal create result and must not read startupTerminal, got 'term-startup'` (the shared terminal object leaked into the `terminal create` parser)
- green: the startup terminal gets its own variable used only by `worktree-terminal-handle`, tried before `result.terminal` for now. U1, U6, U7 and the regression subset pass.
- refactor: none.

## Cycle 3: U3 a startup terminal Orca did not spawn is ignored

- test (new): `test_json_get_ignores_startup_terminal_that_was_not_spawned` (U3)
- red against the cycle 2 adapter: `not ok - worktree-terminal-handle should find no terminal when spawned is false, got 'term-startup'`
- green: the startup terminal is read only when `spawned === true` (again naive: the next cycle tests the absent flag). U1 and U3 and the regression subset pass.
- refactor: none.

## Cycle 4: U2 a startup terminal with no spawned flag is adopted

- test (new): `test_json_get_adopts_startup_terminal_without_spawned_flag` (U2)
- red against the cycle 3 adapter: `not ok - a startup terminal with no spawned flag is not 'spawned: false' and should be adopted, got ''`
- green: the guard becomes `spawned !== false`. U1, U2, U3 and the regression subset pass.
- refactor: none.

## Cycle 5: U4 and A4 an unusable startup terminal is not adopted and spawn creates one

- tests (new): `test_json_get_ignores_startup_terminal_without_a_handle` (U4, adapter level), `test_spawn_creates_a_terminal_for_an_unusable_startup_terminal` (A4, through `fm-spawn.sh`; three shapes: not spawned, empty handle, no handle)
- red against the cycle 4 adapter:
  - U4 `not ok - worktree-terminal-handle should find no terminal for startup-nohandle, got 'undefined'`
  - A4 `not ok - spawn should create exactly one terminal for startup-nohandle` (the handle-less terminal was adopted as the string `undefined`)
- green: the startup terminal is passed through the shared handle reader, which accepts only a non-empty string or number. Both tests, U2, and the regression subset pass; the not-spawned and empty-handle shapes of A4 were already satisfied by earlier cycles.
- refactor: none.

## Cycle 6: U5 and A2 the terminal shape wins when both shapes are reported

- tests (new): `test_json_get_prefers_terminal_over_startup_terminal` (U5), `test_spawn_adopts_the_terminal_shape_and_prefers_it_over_a_startup_terminal` (A2, through `fm-spawn.sh`; shapes `terminal` and both)
- red against the cycle 5 adapter, where the startup terminal was tried first:
  - U5 `not ok - result.terminal should win when both shapes are present, got 'term-startup'`
  - A2 `not ok - meta should record the result.terminal handle for both`
- green: `result.terminal` is tried first and the startup terminal second, which is the final `worktree-terminal-handle` rule and header comment. Both tests, U4, and the regression subset pass.
- refactor: none.
