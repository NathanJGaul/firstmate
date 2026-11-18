# Cycle Log: Orca Fleet Plumbing

Append only. Newest last.
Every entry's red block is the evidence that the test existed and failed before the implementation.

## Baseline

- `bin/fm-test-run.sh tests/fm-bootstrap.test.sh` -> failed=1 on `main`: the herdr missing-CLI case passed only on a host without a real `herdr` on `PATH`; this host has one.
  Fixed first as its own commit (`test(bootstrap): keep a host-installed backend CLI ...`), after which the suite is green.
- `bin/fm-test-run.sh tests/fm-spawn-orca-worktree.test.sh` -> `failed=0` (4 s)
- `bin/fm-test-run.sh tests/fm-watch-triage.test.sh` -> `failed=0` (1158 s)
- `bin/fm-test-run.sh tests/fm-daemon.test.sh` -> `failed=0` (43 s)
- full profile suite: not run here, left to CI
- commit: `018cde5d`

Method notes:

- None of the touched suites has a per-test selector, so each red below was observed by running only the named functions through a scratch wrapper that sources the same file with its call list replaced; nothing in the wrapper is committed.
- One commit per cycle holds the tests, the implementation, and the log entry.

## Cycle 1: US1 bootstrap follows recorded backends (A1-A7, U1)

- tests (new): `test_fleet_required_tools_orders_default_first` (U1), `test_bootstrap_checks_the_backend_a_live_task_runs_on` (A1, A2), `test_bootstrap_treats_an_unrecorded_task_backend_as_tmux` (A3), `test_bootstrap_reports_a_shared_tool_once` (A4), `test_bootstrap_without_task_records_is_unchanged` (A5), `test_bootstrap_ignores_an_unknown_recorded_backend` (A6), `test_treehouse_lease_check_follows_recorded_backends` (A7)
- red against the unchanged scripts:
  - U1 `fm_backend_fleet_required_tools: command not found` then `not ok - the union should list the default first ...`
  - A1 `not ok - a live Orca task in a tmux home should report orca missing, got: `
  - A3 `not ok - a task with no recorded backend runs on tmux, so an orca home must still check tmux (missing: 'MISSING: tmux')`
  - A4 `not ok - jq is required by three recorded backends and should be reported once, got 0 in: `
  - A7 `not ok - a recorded herdr task uses treehouse, so a lease-less treehouse must be reported in an orca home`
  - A5 and A6 were green before the change: they are guards that pin "unchanged when no task names another backend" and "an unknown recorded backend adds nothing", which the implementation must keep true.
    Their strength is shown by the mutants in `tdd/verification.md`.
- green: `fm_backend_fleet_required_tools` in `bin/fm-backend.sh` unions the default's set with each known recorded backend's set; `bin/fm-bootstrap.sh` checks every `<tool> <backend>` line through the owning backend's availability function. All seven tests and the full `tests/fm-bootstrap.test.sh` pass (116 s).
- correction: U1's second expectation was first written with the wrong first-seen order (herdr's `treehouse` precedes `tmux` when the records are read in file order); the expectation, not the function, was wrong, and was fixed before the green run.
- refactor: none.
- docs: `docs/configuration.md` "Backend requirements" and the bootstrap header now state the union.

## Cycle 2: US2 an allowlisted Orca launch keeps Orca's variables (A8-A11)

- tests (new, in `tests/fm-spawn-orca-worktree.test.sh`, whose fake `orca` now also logs every call): `test_orca_allowlisted_launch_keeps_the_orca_floor` (A8, A9, A10), `test_orca_launch_without_an_allowlist_is_unfiltered` (A11)
- red against the unchanged `bin/fm-spawn.sh`:
  - A8 `not ok - an allowlisted Orca launch dropped ORCA_AGENT_HOOK_ENDPOINT from the agent environment`
  - A11 was green before the change: it pins that an absent allowlist file still inherits the whole terminal environment, which the change must keep true.
- green: the observed Orca 1.4.261 names are listed once in `ORCA_FLOOR_NAMES` in `bin/fm-spawn.sh` and joined into the floor loop beside the `TMUX*` and `HERDR_*` names. Both tests and the three neighbouring launch-env suites (`fm-spawn-compact-adviser-disable`, `fm-spawn-dispatch-profile`, `fm-trace-context-spawn`) pass.
- refactor: none.
- docs: the `fm-spawn.sh` header contract and `docs/configuration.md` "Variables retained" name the Orca variables.

