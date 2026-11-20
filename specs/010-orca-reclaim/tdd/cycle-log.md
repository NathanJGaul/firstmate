# Cycle Log: Orca Close-and-Recreate Reclaim, Exit, and Relaunch

Append only. Newest last.
Every entry's red block is the evidence that the test existed and failed before the implementation.

## Baseline

Run from the starting commit `402ac724` before any edit, with `bin/fm-test-run.sh` and the opt-in lab.

- `tests/fm-backend-orca.test.sh` -> rc=0 (116 s)
- `tests/fm-control.test.sh` -> rc=0 (61 s)
- `tests/fm-control-relaunch.test.sh` -> rc=0 (118 s)
- live lab, all sections -> rc=0, `# summary: passed=62 findings=3`
- full profile suite: not run here, left to CI
- commit: `402ac724`

Method notes:

- None of the suites has a per-test selector, so each red was observed by running only the named functions through a scratch copy that sources the same file with its bare call lines removed, against the unchanged `bin/`; the wrapper is not committed.
- `tests/orca-fake.sh` is a stateful fake `orca` and a fake process table laid out like `/proc`, so the tests exercise the real adapter, the real control plane, and the real launch owner with only the runtime faked.
- ShellCheck 0.11.0 was installed into a scratch directory with `bin/fm-install-shellcheck.sh` so `bin/fm-lint.sh` could run.

## Cycle 1: close receipt, absence proof, reclaim, and the capability table (U1-U4)

- tests (new) in `tests/fm-backend-orca.test.sh`: `test_close_terminal_verdicts` (U2), `test_absence_verdict_for_orca` (U3), `test_reclaim_terminal` (U4); two existing characterizations flipped to `test_a_missing_orca_endpoint_is_a_proven_state_for_the_control_plane` and `test_a_dead_orca_endpoint_is_a_proven_state_for_the_control_plane` (U1)
- red against the unchanged code:
  - U2 `not ok - closing a live terminal should print killed and return 0 (receipt ptyKilled true), got '' rc=127`
  - U3 `not ok - a closed terminal with no process carrying its handle is proven gone, got 'unproven|backend 'orca' has no recovery-grade classifier, so absence cannot be proven on it at all'`
  - U4 `not ok - a reclaim should print the one new handle, got '' rc=127: ... fm_backend_orca_reclaim_terminal: command not found`
  - U1 `not ok - a missing Orca endpoint is a recovery-grade state and the control plane must admit Orca, got 'refused missing'` and the dead twin `got 'refused dead'`
- green after: `bin/backends/orca.sh` (`fm_backend_orca_close_terminal`, `fm_backend_orca_terminal_handles`, `fm_backend_orca_absence_verdict`, `fm_backend_orca_reclaim_terminal`), `bin/fm-control-lib.sh` (Orca admitted, the Orca absence arm, `fm_control_backend_supports_close_terminal`), `bin/fm-backend.sh` (`fm_backend_close_terminal`)
- two defects in the new tests found while going green, each fixed with the test kept: a reason pattern said `carry` where the message says `carries`, and the control-plane expectation carried a stray trailing space
- refactor: none
- commit: the one commit holding this feature

## Cycle 2: the control plane (U5, A1-A3, A6, A8)

- tests (new) in `tests/fm-control.test.sh`: `test_orca_exit_matrix` (A1-A3), `test_orca_relaunch_refusals_change_nothing` (A3), `test_orca_exit_close_terminal` (A6), `test_orca_close_terminal_is_bounded` (A8), `test_orca_interrupt_keeps_endpoint_proof` (U5); `test_state_verified_backends_are_tmux_herdr_and_orca` replaces the exact-set test
- red against the code after cycle 1:
  - the three existing Orca interrupt tests failed as a regression of admitting Orca: `not ok - an Escape harness on orca should be interrupted: error: task t1's agent is 'unverified' after its interrupt key; an interrupt must leave the agent running`
  - A1-A3 `not ok - the alive refusal should name the state 'alive'` (the exit command was about to be typed: `composer state is 'unknown'`)
  - A6 `not ok - exit --close-terminal on an alive Orca agent should close its terminal ... error: unexpected argument '--close-terminal'`
  - A8 `not ok - the refusal should name the state 'dead' ... error: unexpected argument '--close-terminal'`
  - U5 `not ok - interrupt through a non-local runtime keeps its endpoint proof ... agent is 'unverified' after its interrupt key`
- green after: `bin/fm-control.sh` (`--close-terminal`, `close_terminal_gate`, `do_close_terminal`, the Orca arm of `do_exit`, the interrupt proof), and the relaunch preflight
- two message expectations in the new tests were reworded to match the messages (`applies only to`, `applies to`)
- refactor: none

## Cycle 3: the launch owner (A4, A5, A7, A9, U6)

- tests (new) in `tests/fm-control-relaunch.test.sh`: `test_orca_relaunch_adopts_a_dead_terminal` (A4), `test_orca_relaunch_reclaims_a_gone_terminal` (A5), `test_orca_relaunch_closes_a_wedged_agent` (A7), `test_orca_failed_reclaim_keeps_the_record` (A9), `test_orca_relaunch_checks_the_runtime` (U6), `test_orca_spawn_relaunch_refuses_what_it_cannot_prove`
- red against the code after cycle 2:
  - A4 `REFUSED: missing terminal in .../rl1.meta; cannot close Orca endpoint` (the republished record lost `terminal=`)
  - A5, A7 `fm-spawn.sh: line 3722: RELAUNCH_LAUNCHER_PANE_ID: unbound variable ... fm_backend_herdr_session: command not found` (the rebind ran the Herdr arm on Orca)
  - A9 `not ok - a published reclaim names its fresh terminal even when the harness did not start`
  - U6 `spawned rl8 ... expected exit 1, got 0` (no readiness check)
  - the secondmate and non-local refusals already held before the change through the generic gates; they are guarded by mutants
- green after: `bin/fm-spawn.sh` (the Orca identity read from the record, the Orca arm of the rebind, `ORCA_RELAUNCH_NEW_TERMINAL` and its abort cleanup, the runtime check, the secondmate refusal)
- one existing test changed: `tests/fm-spawn-orca-worktree.test.sh` asserted the old refusal ("no recovery-grade agent-state classifier"); it now drives a relaunch of a proven-dead Orca terminal whose recorded worktree is the project itself and asserts the RELAUNCH+orca carve-out refuses it
- refactor: none

## Cycle 4: the live lab (A10-A13)

- test (new): step A15 of `tests/fm-backend-orca-smoke.test.sh`, plus the Firstmate-level step that expected `fm-control exit` to refuse
- red against the code before cycle 1-3: the first run of the Firstmate-level section failed at the changed step: `not ok - F: the exit refusal does not name the alive state`, with `error: task test-orca-live runs on the orca backend, which has no recovery-grade agent-state classifier`
- the step read a live agent where there was none: the lab's own earlier `C-c` ended the renamed `sleep`, so the terminal read `dead` and `exit` reported `already-stopped`; the step now asserts exactly that, and A15 covers the running agent
- green after cycles 1-3: `FM_ORCA_LIVE_SECTIONS=firstmate` -> `passed=31 findings=0`; the full lab -> `passed=67 findings=3`, rc=0, nothing left behind
- finding from the first green run: a repeat close of an already closed terminal answers `ptyKilled: true`, so the stop verb's wait for the terminal to read missing and no process to carry the handle is what proves the stop (recorded in `research.md` and the verification record); the fake and one adapter test were corrected to match

## Cycle 5: gaps found by deliberate mutants

- two mutants survived the first run: a close receipt naming another handle was accepted, and an Orca secondmate relaunch was refused only by an unrelated gate
- tests extended: `close-wrong` receipt case in `test_close_terminal_verdicts`; the secondmate case now covers a dead terminal and asserts the Orca-specific refusal
- red: both mutants killed on the second run (see `verification.md`)
