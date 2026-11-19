# Cycle Log: Orca Local Process Classifier

Append only. Newest last.
Every entry's red block is the evidence that the test existed and failed before the implementation.

## Baseline

Run from an export of the starting commit `1ccee8e5` (no edits had been made yet; the export has no git metadata).

- `bin/fm-test-run.sh tests/fm-backend-orca.test.sh` -> rc=0 (307 s)
- `bin/fm-test-run.sh tests/fm-session-start.test.sh` -> rc=0 (501 s)
- `bin/fm-test-run.sh tests/fm-backend.test.sh` -> rc=1 in the export only, because that test needs a git repository with a local or remote main; re-run in the worktree before any edit -> rc=0 (134 s)
- `bin/fm-test-run.sh tests/fm-crew-state.test.sh` -> rc=1 in the export, one failure (`alive remote mate with a working log reads working`) in a case this feature does not touch; re-run in the worktree after the change -> rc=0 (119 s), so it was a load-dependent flake while four suites ran in parallel
- full profile suite: not run here, left to CI
- commit: `1ccee8e5`

Method notes:

- None of the suites has a per-test selector, so each red was observed by running only the named function through a scratch copy that sources the same file with its bare call lines replaced, against the unchanged `bin/`; the wrapper is not committed.
- The fake process table is a directory laid out like `/proc` under `FM_ORCA_PROC_ROOT`, so the tests exercise the real scan and the real shared classifier with no mocking of either.

## Cycle 1: scan, classification, and verdicts (A1-A10, U1-U8)

- tests (new) in `tests/fm-backend-orca.test.sh`: `test_agent_state_alive_for_a_harness_process` (A1), `test_agent_state_alive_for_a_descendant_harness` (A2), `test_agent_state_alive_for_an_argv0_harness` (A3), `test_agent_state_dead_for_only_shells` (A4), `test_agent_state_ambiguous_for_another_process` (A5), `test_agent_state_unverified_for_a_non_local_runtime` (A6), `test_agent_state_unverified_without_attribution` (A7), `test_agent_state_unreadable_matrix` (A8), `test_agent_state_endpoint_verdicts_do_not_read_the_table` (A9), `test_agent_state_makes_one_orca_call_and_uses_no_native_state`, `test_a_dead_orca_endpoint_does_not_unlock_the_control_plane` (A10), `test_process_scan_*` (U1-U6), `test_process_state_precedence` (U7), `test_process_state_settles_a_transient_other` (U8)
- red against the unchanged code:
  - A1 `not ok - agent state for a shell with a harness process carrying the handle: expected 'alive', got 'unverified'`
  - A2 `... a harness below a process carrying the handle: expected 'alive', got 'unverified'`
  - A3 `... a bare node whose argv[0] is a harness: expected 'alive', got 'unverified'`
  - A4 `... one shell: expected 'dead', got 'unverified'`
  - A5 `... a shell and an editor: expected 'ambiguous', got 'unverified'`
  - A6 `... an empty ORCA_ENVIRONMENT selects nothing, expected alive, got 'unverified'`
  - A8 `... a process table that cannot be listed: expected 'unreadable', got 'unverified'`
  - A10 `not ok - a dead Orca endpoint must leave the stop-proving verbs refused, got 'refused unverified'`
  - U1-U8 `not ok - the scan header should be 'ok 0', got: ` (no scan function), `... should be agent, got ''`
- already green before the implementation, as characterizations that guard the new code: A7, A9, and the one-orca-call case all hold for the old `unverified`/endpoint-first behavior; each is killed by a mutant below
- green after: `bin/backends/orca.sh` (`fm_backend_orca_process_scan`, `fm_backend_orca_process_state_sample`, `fm_backend_orca_process_state`, `fm_backend_orca_runtime_is_local`, and the extended `fm_backend_orca_agent_state`)
- three defects in the new tests found while going green, each fixed with the test kept: the helper that runs adapter functions did not source the Orca adapter, a `shift` dropped the function name, and a control-plane expectation had a stray trailing space
- one existing test changed: `test_agent_state_missing_unverified_unreadable` now points the process table at an empty directory and expects `unverified` because no local process carries the handle
- refactor: none
- commit: the one commit holding this feature

## Cycle 2: a refused environment is opaque (U10)

- trigger: the first live lab run (A13) read `unreadable` for an idle shell.
  Cause: `systemd --user` and `(sd-pam)` belong to the same user and refuse an `environ` read (`EACCES`), and the first version tallied every failed read as unreadable, which made `dead` unreachable on a normal desktop.
- test (new): `test_process_scan_opaque_environment_is_reached_through_the_tree` (U10), plus the descendant and other-user cases reworked so the parent links come from every process
- red: the mutant that tallies a refused environment (the first version's behavior) is killed by it, and the live run was the red: `not ok - A13 LIVE: fm_backend_agent_state was 'unreadable', expected dead`
- green after: the scan reads `stat` for every process, reads `environ` only for the current user's, treats `EACCES` and `EPERM` as opaque, and keeps the tally for every other failure
- live check on the real table: the scan of an unused handle reports `ok 0`

## Live lab (A13, A14, and the Firstmate-level section)

- Orca-level section, pinned `HOME`, isolated runtime: A13's live terminal now reads `dead` (an idle shell), and A14 passed: a copy of `sleep` named `claude` reads `alive`, `dead` after SIGKILL with the terminal still present, `unverified` through `ORCA_ENVIRONMENT`, and `missing` once closed (`passed=37 findings=3`).
- The full lab's first run failed in the Firstmate-level section: `fm-control interrupt` was refused because the stand-in harness `sh -c cat` read `ambiguous`.
  That is the control plane working as designed on a stand-in no classifier recognizes, so the lab's stand-in became the same real binary named `claude`.
