# Cycle Log: Per-Worker Browser Session

Append only.
Newest last.
Every entry's `red` block is the evidence that the test existed and failed before the implementation.

## Baseline

- focused: `bin/fm-test-run.sh tests/fm-spawn-compact-adviser-disable.test.sh` -> every test ok, exit 0, 78 s
- focused: `bin/fm-test-run.sh tests/fm-teardown.test.sh` -> 113 ok, 0 not ok, exit 0, 976 s
- full suite: not run locally; `bin/fm-test-run.sh --all` is a multi-hundred-script walk, and CI plus the no-mistakes pipeline own broad regression coverage for this repository
- commit: `af20b2c9`
- recorded: cycle 0, before any change

## Cycle 1: U1 a creation-valid id names its own session

- test: `tests/fm-spawn-compact-adviser-disable.test.sh::test_session_name_accepts_a_task_id` (new)
- red: `bin/fm-test-run.sh tests/fm-spawn-compact-adviser-disable.test.sh` -> `not ok - an ordinary task id: the id itself should be the session name (expected 'fix-a1', got '')`
- green: `fm_browser_session_name` added to `bin/fm-pr-lib.sh` (creation-valid check, then print the id)
- refactor: none needed
- commit: `1e76b531`

## Cycle 2: U5 the id default names no session

- test: `test_session_name_refuses_the_default_session` (new)
- red: same command -> `not ok - the default session name: a refused id must print nothing (expected '', got 'default')`
- green: `bin/fm-pr-lib.sh` refuses the exact id `default`; the focused file ran to exit 0
- refactor: none needed
- commit: `1e76b531` (cycles 1 and 2 share one commit, a deviation from one commit per cycle)

## Cycle 3: U2, U3, U4, U6, U7, U8, U9 the remaining id rules

- tests: seven new cases, one per behavior, in the same file
- red: none. All seven passed on first run because the helper delegates to `fm_task_id_creation_valid`. This is a test-after characterization of delegated behavior, so each was proven with deliberate mutants instead.
- mutants against `fm_browser_session_name` (each case run in isolation): creation-valid check removed -> U4, U7, U8, U9 fail; prefix match on default -> U6 fails; default check removed -> U5 fails; reject ids containing a dot -> U2 fails; reject length 64 -> U3 fails; unmutated -> all nine pass
- commit: `1e76b531`

## Cycles 4 to 11: A1, A2, A3, A4, A5, A6, A7, A8 launch export

- tests: eight new cases in `tests/fm-spawn-compact-adviser-disable.test.sh`, written as one batch before the single export line that satisfies them; each was run in isolation and its red recorded
- red (each in isolation, probe prints what the agent sees):
  - A1 `expected 'browser-ship-a1', got 'unset'`
  - A2 `expected 'browser-scout-a1', got 'unset'`
  - A3 `expected 'browser-sm-a1', got 'unset'`
  - A4 `expected 'browser-contrary-a1', got 'other-session'`
  - A6 `two workers must not share a browser session (unexpectedly got 'unset')`
  - A7 `expected 'browser-allow-a1', got 'unset'`
  - A8 `allowlist=absent: ... expected 'browser-nopane-absent-a1', got 'other-session'`
  - A5 `expected 'relaunch-absent-a1', got 'other-session'`
- green: `bin/fm-spawn.sh` prefixes the launch with `export CHROME_DEVTOOLS_AXI_SESSION=<id>;` beside the `FM_TASK_INBOX` export, guarded by `fm_browser_session_name`; all eight pass in isolation and the full focused file passes with 25 ok
- refactor: extracted `relaunch_case` from the existing relaunch test so the A5 test reuses it; the existing relaunch test still passes. A first version reused one scratch directory for both relaunch tests and printed git errors; it was fixed with a per-test tag and the log was clean afterwards.
- commit: `f048cac3`

## Cycle 12: A14 a task named default exports no session

- test: `test_default_named_task_exports_no_session` (new)
- red: none; it passed on first run because the helper already refuses `default`. Proven with a mutant.
- mutants against the launch export: unguarded export (`BROWSER_SESSION=$ID`) -> A14 fails; export removed -> A1 to A8 fail; export applied to ships only -> A2 and A3 fail; export removed and the name added to the allowlist floor instead -> A1 to A8 fail
- commit: `f048cac3`

## Cycles 13 to 22: A9 to A17, U10, U11 cleanup stop

- tests: ten new cases in `tests/fm-teardown.test.sh` with a fake `chrome-devtools-axi` that logs its arguments, its session variable, and whether the case's leaked process was already gone
- red (positive behaviors, each in isolation):
  - A9 `browser-stop: the task's browser session should be stopped exactly once (expected '1', got '0')`
  - A11 `browser-stop-fails: the stop should still have been attempted once (expected '1', got '0')`
  - A16 `browser-stop-caller-default: exactly one stop should be issued (expected '1', got '0')`
  - U10 `browser-stop-hangs: a stop that hit its bound should warn about the session`
  - A10 and U11 failed too, but see the deviation below
- passed on first run, vacuously (no stop existed yet): A12, A13, A15, A17. They are proven with mutants below.
- green: `bin/fm-teardown.sh` gains `teardown_stop_browser_session`, called right after the leaked-process reap and pipeline-spend block; all ten pass in isolation
- mutants against the stop, each run only against the tests it should trip: stop before the reap -> A10 fails; no name guard -> A15 and A17 fail; caller session not overridden -> A9 and A16 fail; no tool-presence check -> A12 fails; stop on every exit -> A13 fails; no bound -> U10 fails (teardown waited 72 s); bound not sanitized -> U11 fails; stop failure propagates -> A11 fails (exit 3); unmutated -> all ten pass
- refactor: none needed
- commit: `e71a44ce`

## Notes and deviations

- `.specify/memory/constitution.md` is still the unratified template, so the TDD principle is taken from `.agents/skills/spec-kit-workflow/SKILL.md`; the constitution is left untouched because changing it needs the captain's approval of its exact wording.
- The first draft of the teardown tests used `assert_grep` with regular-expression anchors and an alternation, but `assert_grep` is a fixed-string match. The A10 and U11 reds were therefore not valid evidence, and A12's no-warning assertion was vacuous. The patterns were corrected before green, and A10, U11, and A12 were proven afterwards by the mutants above (T1, T7, T4).
- Cycles 1 to 3 share one commit, and cycles 4 to 12 share one commit, because the helper and the single export line satisfy their behaviors together.
- The teardown baseline run overlapped the first helper edit; that edit only added a function, so the baseline stands.
- Mutation tooling is not installed for Bash, so the mutants above were applied by hand with a script in the scratch directory and always restored; the working tree was verified identical to the committed files afterwards.
- A shell `-c` script that contained a removal was blocked by a permission check mid-session; no file was removed by it, and later cleanup used a plain removal of literal temporary file names.
