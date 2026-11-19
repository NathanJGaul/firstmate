# Implementation Plan: Orca Local Process Classifier

**Branch**: `fm/firstmate-orca-process-classifier` | **Date**: 2026-11-19 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/009-orca-process-classifier/spec.md`

## Summary

`bin/backends/orca.sh` gains `fm_backend_orca_process_scan <terminal>`, one inline Node scan of the process table that lists every process carrying the exact handle plus its descendants, and `fm_backend_orca_process_state <terminal>`, which classifies that list with the shared classifier and settles a transient `other`.
`fm_backend_orca_agent_state` keeps its endpoint read and maps the process state onto the recovery vocabulary.
`bin/fm-backend.sh` already routes `fm_backend_agent_state orca` to it, so only the headers there and in `bin/fm-control-lib.sh` change; the control plane's capability table does not.

## Technical Context

**Language/Version**: Bash 3.2-compatible shell with the adapter's existing inline Node JSON snippets

**Primary Dependencies**: none new; `bin/fm-agent-process-lib.sh` (already the owner of the name classifier), the fake `orca` in `tests/fm-backend-orca.test.sh`, and the opt-in lab

**Storage**: none

**Testing**: extend `tests/fm-backend-orca.test.sh` (fake `orca` plus a fake process table under a temporary `FM_ORCA_PROC_ROOT`) and `tests/fm-backend-orca-smoke.test.sh` (live lab); run each with `bin/fm-test-run.sh <file>`, the lab only with `env -u ORCA_USER_DATA_PATH FM_ORCA_LIVE_E2E=1` and a pinned `HOME`

**Target Platform**: Linux (process table at `/proc`); macOS and any host without `/proc` read `unverified`

**Project Type**: shell CLI toolkit, single project

**Constraints**: shellcheck-clean through `bin/fm-lint.sh`; no other backend changes; no native Orca agent state; no extra `orca` call beyond the presence read

**Scale/Scope**: one adapter, two headers, one test file plus the lab, two docs

## Constitution Check

The constitution carries only the TDD principle in `.specify/memory/tdd-profile.md`; every behavior below is driven by a test that failed first.

## Design

### D1: What the scan reads

The scan lists the process table (`FM_ORCA_PROC_ROOT`, default `/proc`) once.
For each numeric entry it reads the parent from `stat`, which is world-readable, so the parent links cover every process whoever owns it.
For an entry owned by the current user it also reads `environ` and marks the process as a carrier when it holds the exact entry `ORCA_TERMINAL_HANDLE=<handle>`.
The kept set is every carrier plus every descendant of a carrier, so a harness relaunched by a launcher that cleans the environment, or one below a helper whose own environment is hidden, is still found.
For every kept process it reads `comm` and `cmdline` (argv[0] and the flattened line).

A process in state `Z` or `X`, the scanner's own pid, and a process whose files vanish mid-read are dropped.
An own process whose `environ` the kernel refuses (`EACCES` or `EPERM`) is opaque: it stays in the tree, cannot be shown to be a carrier, and is not tallied, because `systemd --user` is opaque on a normal desktop and tallying it would make every negative verdict unreachable (the first live run read `unreadable` for exactly that reason).
Any other failure to place or read an own process, or to read a kept process's `comm` or `cmdline`, counts toward an `unreadable` tally.

Output is a header `<status> <unreadable-count>` where status is `ok`, `unsupported` (no process table directory), or `unreadable` (the directory cannot be listed), followed by one tab-separated row per kept process: pid, comm, argv[0], flattened command line.

### D2: Classification

`fm_backend_orca_process_state` classifies each row with `fm_agent_process_classify <comm> <argv0> <args> [pid]`, which wraps the shared name classifier and adds the node-bundle harness rules.
The pid is passed only when the table is the real `/proc`, because the Gemini rule reads the live process by pid.
It prints `agent` if any row is an agent, else `unreadable` when the scan tallied unreadable processes, else `none` when no row was found, `shell` when every row is a shell, and `other` otherwise.
A scan status of `unsupported` prints `unsupported` and `unreadable` prints `unreadable`.
`other` is resampled for a bounded settle (`FM_BACKEND_ORCA_PROCESS_SETTLE_POLLS`, default 5, 0.1 s apart) and the first non-`other` reading wins, because an idle shell transiently hosts prompt helpers.

### D3: The recovery verdict

`fm_backend_orca_agent_state` reads `fm_backend_orca_endpoint_state` first.

| endpoint | process state | verdict |
| --- | --- | --- |
| `missing` | not read | `missing` |
| `unreadable` | not read | `unreadable` |
| `present`, non-local runtime selected | not read | `unverified` |
| `present` | `agent` | `alive` |
| `present` | `shell` | `dead` |
| `present` | `other` | `ambiguous` |
| `present` | `none` or `unsupported` | `unverified` |
| `present` | `unreadable` | `unreadable` |

A non-local runtime is one the CLI would address remotely: `ORCA_ENVIRONMENT`, `ORCA_PAIRING_CODE`, or `ORCA_REMOTE_PAIRING` non-empty in the adapter's environment.
`none` is `unverified` rather than `dead` because a live local terminal always has at least its shell carrying the handle, so an empty answer means the runtime is not on this host or its processes are not visible.

### D4: Callers and the control plane

`fm_backend_agent_alive` already folds `dead` to `dead` and `ambiguous` to `unknown`.
`fm_control_backend_state_verified` stays tmux and herdr only, so `exit`, `relaunch`, and secondmate restart keep refusing on Orca.
The consumers that read `dead` today (the watcher's no-typing and wedge-report branches, the doorbell, the legacy-record teardown gate) already handle it for tmux and Herdr, and none of them licenses a control action on its own.

### D5: Docs and records

`docs/orca-backend.md` replaces the "stays unverified" line, the `bin/fm-backend.sh` and `bin/fm-control-lib.sh` headers name the Orca classifier, and `docs/verification/runtime-backends.md` gets a dated lab entry and a re-run entry for the endpoint step whose live verdict changed from `unverified` to `dead`.

## Project Structure

```text
bin/backends/orca.sh           process_scan, process_state, agent_state mapping
bin/fm-backend.sh              header only
bin/fm-control-lib.sh          header only
docs/orca-backend.md           verdict paragraph and limits
docs/verification/runtime-backends.md  dated lab record
tests/fm-backend-orca.test.sh  fake process-table cases
tests/fm-backend-orca-smoke.test.sh  live lab step A14, and A13's live verdict
```
