# Cycle Log: Orca Endpoint Presence

Append only. Newest last.
Every entry's red block is the evidence that the test existed and failed before the implementation.

## Baseline

Run from an export of the starting commit `5766667f` (the working tree was edited while the first runs were in flight, so the two suites I edited were re-run from the export).

- `bin/fm-test-run.sh tests/fm-backend-orca.test.sh` -> rc=0 (414 s)
- `bin/fm-test-run.sh tests/fm-session-start.test.sh` -> rc=0 (837 s)
- `bin/fm-test-run.sh tests/fm-crew-state.test.sh` -> rc=0 (397 s)
- `bin/fm-test-run.sh tests/fm-backend.test.sh` -> rc=0 (153 s)
- full profile suite: not run here, left to CI
- commit: `5766667f`

Method notes:

- None of the suites has a per-test selector, so each red was observed by running only the named function through a scratch copy that sources the same file with its bare call lines replaced, against the unchanged `bin/`; the wrapper is not committed.
- Research step before any test: a scratch probe in the isolated lab recorded the real `terminal show` and `terminal read` answers for the four states (`research.md`).
- Fixtures answer `terminal read` the way the real runtime does (ok:true, status exited for an exited or closed terminal), so a presence check that still used `terminal read` fails the tests for the real reason.

## Cycle 1: endpoint presence, verdicts, and callers (A1-A6, U1-U6)

- tests (new): `test_endpoint_state_four_states` (U1, U5), `test_endpoint_state_unreadable_matrix` (U2), `test_endpoint_state_is_one_read_only_call` (U3), `test_endpoint_state_without_the_cli_is_unreadable` (U4), `test_target_exists_reads_the_four_endpoint_states` (A1), `test_agent_state_missing_unverified_unreadable` (A5, U6), `test_a_missing_orca_endpoint_does_not_unlock_the_control_plane` (A6), `test_crew_state_reports_a_dead_orca_endpoint_gone` (A3), `test_crew_state_does_not_call_an_unreadable_orca_endpoint_gone` (A4) in `tests/fm-backend-orca.test.sh`; `test_orca_endpoint_states_in_the_digest` (A2) in `tests/fm-session-start.test.sh`
- red against the unchanged code:
  - U1 `not ok - endpoint state for a live terminal: expected 'present', got ''`
  - U2 `not ok - endpoint state for connected but not writable: expected 'unreadable', got ''`
  - U3 `not ok - an endpoint read should make exactly one orca call, made 0`
  - U4 `not ok - with no orca CLI the endpoint read should be unreadable, got ''`
  - A1 `not ok - an exited shell must not read as present`
  - A5 `not ok - an exited Orca terminal should be missing, got 'unverified'`
  - A6 `not ok - a missing Orca endpoint must leave the stop-proving verbs refused, got 'refused unverified'`
  - A3 `not ok - crew-state should report an exited Orca terminal as gone` (output `state: unknown - source: pane - harness state unavailable`)
  - A4 `not ok - crew-state should name the unreadable endpoint state`
  - A2 `not ok - an exited Orca shell was not reported dead` (digest printed `endpoint: alive` for the exited and closed terminals)
- green after: `bin/backends/orca.sh` (`fm_backend_orca_endpoint_state`, `fm_backend_orca_agent_state`), `bin/fm-backend.sh` (Orca arms of `fm_backend_target_exists` and `fm_backend_agent_state`), `bin/fm-crew-state.sh` (`pane_readable` reads Orca once and the fallback reuses the verdict)
- two defects found while going green, each fixed with its test kept:
  - the digest case needed the real `node`, because the shared toolchain stubs it out;
  - `fm-crew-state.sh` first read the endpoint twice (once in `pane_readable`, once through `fm_backend_agent_state`), so the existing stale-handle test saw a second unanswered read; the verdict is now read once and reused, and that test asserts a single `terminal show`
- two existing tests changed: the stale-handle crew-state test now also asserts the endpoint read; the A6 expectation string was corrected to the real output
- refactor: none beyond the single-read reuse above
- commit: the one commit holding this feature

## Live lab (A13, T013-T014)

- Orca-level section only, pinned `HOME`, isolated runtime: `passed=28 findings=4` (A13 held for live, exited, closed, and stale).
- Whole lab including the Firstmate-level section: `passed=44 findings=5`; the findings are the pre-existing worktree-create and plugin-dir observations, none new.
