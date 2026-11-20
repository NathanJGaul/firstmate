# Implementation Plan: Orca Close-and-Recreate Reclaim, Exit, and Relaunch

**Branch**: `fm/firstmate-orca-reclaim` | **Date**: 2026-11-19 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/010-orca-reclaim/spec.md`

## Summary

`bin/backends/orca.sh` gains a close that reads the runtime's receipt, a terminal listing for one worktree, and a reclaim that closes a dead terminal, creates one fresh terminal by the recorded worktree id, and proves the result.
`bin/fm-control-lib.sh` admits Orca to the stop-proving table and gives Orca its own endpoint-absence proof.
`bin/fm-control.sh` gains `--close-terminal` and an Orca arm in `do_exit`.
`bin/fm-spawn.sh --relaunch` reads the Orca identity from the record, reclaims or adopts, republishes the record, and never lets the abort cleanup that removes a worktree run.

## Technical Context

**Language/Version**: Bash 3.2-compatible shell with the adapter's existing inline Node JSON snippets

**Primary Dependencies**: none new; the existing endpoint read (`fm_backend_orca_endpoint_state`), process scan (`fm_backend_orca_process_state`), runtime locality (`fm_backend_orca_runtime_is_local`), and terminal create

**Storage**: the task record's `terminal=` line, republished through `fm_backlog_atomic_transition publish`

**Testing**: extend `tests/fm-backend-orca.test.sh` (fake `orca` and fake process table), `tests/fm-control.test.sh` and `tests/fm-control-relaunch.test.sh` (control plane), and `tests/fm-backend-orca-smoke.test.sh` (live lab); each with `bin/fm-test-run.sh <file>`, the lab only with `env -u ORCA_USER_DATA_PATH FM_ORCA_LIVE_E2E=1`

**Target Platform**: Linux for proof (process table); macOS reads `unverified` for a present terminal and keeps refusing `dead` recovery

**Project Type**: shell CLI toolkit, single project

**Constraints**: shellcheck-clean through `bin/fm-lint.sh`; every `orca` call names its terminal or worktree explicitly; the lab never reaches the operator's Orca; no new dependency

## Constitution Check

The constitution carries the TDD principle in `.specify/memory/tdd-profile.md`; every behavior below is driven by a test that failed first.

## Design

### D1: The close receipt

`fm_backend_orca_close_terminal <terminal>` runs `orca terminal close --terminal <terminal> --json` and prints one verdict:
`killed` when the answer is `ok` and `result.close.ptyKilled` is `true`, `gone` when the runtime answers `terminal_handle_stale`, `unkilled` for any other readable answer, and `unreadable` for no CLI, invalid JSON, or no answer.
Only `killed` is stopped proof.
`fm_backend_orca_kill` keeps its best-effort contract for teardown.

### D2: The absence proof

`fm_control_endpoint_absence_verdict orca` prints `gone` only when all three hold: the runtime is local, `fm_backend_orca_endpoint_state` reads `missing`, and the process scan finds no process carrying the handle.
A live agent process under a handle the runtime calls gone reads `alive`, any other process reads `unproven`, and a non-local runtime, an unreadable table, or a present endpoint that does not classify reads `unproven` with the reason.
A host with no process table (`unsupported`) accepts the runtime's own answer, because that is the only evidence available there.

### D3: The control plane

`fm_control_backend_state_verified` admits `orca`.
`do_exit` on Orca: `dead` is `already-stopped`; `missing` goes through D2 and is `endpoint-gone`; `alive` refuses naming the state and `--close-terminal` unless the flag is set; every other state refuses naming it.
`--close-terminal` runs D1, requires `killed`, then waits (bounded by `FM_CONTROL_EXIT_WAIT`) for the endpoint to read `missing` and the table to hold no process for the handle, retires the busy incarnation, and reports `closed`.
`do_relaunch` is unchanged apart from carrying the flag: after `closed` or `endpoint-gone` the launch owner sees `missing` and reclaims.
`verify_interrupt_running` keeps the endpoint proof on Orca for `unverified`, `ambiguous`, and `unreadable`.

### D4: The launch owner

`bin/fm-spawn.sh --relaunch` already admits a `dead` endpoint and rebinds a proven-gone one.
For Orca it additionally checks the runtime's readiness before any mutation, refuses a secondmate, reads `orca_worktree_id=` and `terminal=` from the record into `ORCA_WORKTREE_ID` and `ORCA_TERMINAL`, and on a rebind calls `fm_backend_orca_reclaim_terminal` instead of the Herdr container code.
The published record then writes the republished `terminal=`.
`ORCA_ABORT_CLEANUP` stays 0 on a relaunch, because that cleanup removes the worktree; a separate variable names the one terminal a reclaim created, and the abort path closes only that.

### D5: The reclaim

`fm_backend_orca_reclaim_terminal <worktree-id> <old-terminal> <title>` closes the old terminal (an already-gone answer is accepted), requires the old terminal to read `missing`, creates one terminal with `terminal create --worktree id:<worktree-id> --title <title>`, and requires the new handle to read `present` and appear in `terminal list --worktree id:<worktree-id>` while the old handle does not.
It prints the new handle and touches no other terminal.

### D6: Documentation and records

`docs/agent-control.md` and `docs/orca-backend.md` drop the refusal wording and own the Orca reclaim; the `stuck-crewmate-recovery` skill line is corrected; `docs/verification/runtime-backends.md` records the dated lab run and the commands that refresh it.
