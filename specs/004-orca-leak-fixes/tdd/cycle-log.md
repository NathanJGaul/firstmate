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
