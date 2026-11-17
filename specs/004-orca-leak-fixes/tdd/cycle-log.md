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

## Cycle 7: U8, A1, U11, A3 the adopted terminal is titled once, and only when there is one

- tests (new): `test_worktree_create_titles_the_adopted_startup_terminal` (U8), `test_spawn_adopts_startup_terminal_without_creating_another` (A1, the outer test), `test_worktree_create_issues_no_rename_without_a_terminal` (U11), `test_spawn_creates_one_titled_terminal_when_orca_reports_none` (A3)
- red, step 1, against the cycle 6 adapter (no rename exists): U8 `not ok - worktree create should title the adopted terminal exactly once`; A1 `not ok - spawn should title the adopted startup terminal exactly once`. U11 and A3 pass here because nothing renames yet.
- step 2, the obvious implementation: a new `fm_backend_orca_terminal_rename` helper called unconditionally and strictly (`|| return 1`) right after the terminal is read. U8 and A1 go green, and the same step turns the other two red:
  - U11 `not ok - there is no terminal to title, so no rename should be issued`
  - A3 `not ok - spawn should fall back to creating a terminal` (a rename with no terminal consumed the create response)
  - the regression subset also breaks under this step (3 of 8 tests ran ok before the first failure).
- green, step 3: the rename runs only when a terminal exists and, for now, only for a terminal that did not come from `result.terminal`. All four tests and the 8-test regression subset pass.
- refactor: none.

## Cycle 8: U12 and A5 a worktree result with no path is closed and released, never titled

- tests (new): `test_worktree_create_releases_a_pathless_worktree_and_its_startup_terminal` (U12), `test_spawn_with_a_pathless_startup_terminal_closes_and_releases_everything` (A5, through `fm-spawn.sh`)
- red against the cycle 7 adapter, which titled the terminal before the path was checked:
  - U12 `not ok - a worktree that is being released must not have its terminal titled`
  - A5 `not ok - a worktree being released must not have its terminal titled`
- green: the rename moves after the path check, so the existing close-and-release cleanup runs first. Both tests, U8, A1, and the regression subset pass.
- refactor: none.

## Cycle 9: U9, U10, A6 a failed title never fails the spawn

- tests (new): `test_worktree_create_survives_a_rename_that_exits_non_zero` (U9), `test_worktree_create_survives_a_rename_that_reports_an_error` (U10), `test_spawn_succeeds_when_titling_the_adopted_terminal_fails` (A6, through `fm-spawn.sh`)
  One cause fails all three, so they share one cycle and one commit; each was red on its own before the change.
- red against the cycle 8 adapter, where a failed rename returned 1:
  - U9 `not ok - a rename that exits non-zero must not fail worktree create`
  - U10 `not ok - a rename that reports ok:false must not fail worktree create`
  - A6 `not ok - a failed title must not fail the spawn`
- green: a failed rename is ignored (`|| true`), with a comment saying why. All three pass with the regression subset.
- refactor: none.

## Cycle 10: A11 a terminal reported in the result.terminal shape is titled too

- test (new): `test_spawn_titles_a_terminal_reported_in_the_terminal_shape` (A11, through `fm-spawn.sh`)
- red against the cycle 9 adapter, which titled only startup-shaped terminals: `not ok - spawn should title an adopted result.terminal terminal exactly once`
- green: the shape condition is dropped, so whichever terminal worktree creation hands back is titled with the task name (FR-003, plan decision D4). A11, A2, and the regression subset pass.
- refactor: none.
