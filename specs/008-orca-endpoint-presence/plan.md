# Implementation Plan: Orca Endpoint Presence

**Branch**: `fm/firstmate-orca-endpoint-presence` | **Date**: 2026-11-19 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/008-orca-endpoint-presence/spec.md`

## Summary

`bin/backends/orca.sh` gains `fm_backend_orca_endpoint_state <terminal>`, one `terminal show` read classified by an inline Node snippet like the adapter's other JSON readers, and `fm_backend_orca_agent_state <terminal>`, which maps it onto the recovery vocabulary.
`bin/fm-backend.sh` points the Orca arms of `fm_backend_target_exists` and `fm_backend_agent_state` at them.
`bin/fm-crew-state.sh` reads Orca presence through `fm_backend_target_exists` and extends its no-run fallback to Orca's three outcomes.
The digest needs no change: its `endpoint:` line already turns a failing `fm_backend_target_exists` into `endpoint: dead`.

## Technical Context

**Language/Version**: Bash 3.2-compatible shell with the adapter's existing inline Node JSON snippets

**Primary Dependencies**: none new; the fake `orca` in `tests/fm-backend-orca.test.sh` and the opt-in lab

**Storage**: none

**Testing**: extend `tests/fm-backend-orca.test.sh`, `tests/fm-session-start.test.sh`, `tests/fm-crew-state.test.sh`, and `tests/fm-backend-orca-smoke.test.sh`; run each with `bin/fm-test-run.sh <file>`, the lab only with `env -u ORCA_USER_DATA_PATH FM_ORCA_LIVE_E2E=1` and a pinned `HOME`

**Target Platform**: Linux and macOS

**Project Type**: shell CLI toolkit, single project

**Constraints**: shellcheck-clean through `bin/fm-lint.sh`; no other backend changes; the live-terminal path costs one `orca` spawn, the same as before

**Scale/Scope**: three scripts, four test files, two docs

## Constitution Check

The constitution carries only the TDD principle in `.specify/memory/tdd-profile.md`; every behavior below is driven by a test that failed first.

## Design

### D1: One read, one classifier

`fm_backend_orca_endpoint_state` calls `fm_backend_orca_tool_check`, then `orca terminal show --terminal "$terminal" --json`, and hands the answer plus the requested handle to a Node snippet that prints exactly one word.
The CLI's exit status is ignored because Orca prints its `ok:false` JSON and exits 1 for a stale handle; the JSON decides.
A failed spawn, empty output, or a parse error prints `unreadable`.

| answer | word |
| --- | --- |
| `ok:true`, handle equal, `connected:true`, `writable:true`, no contradicting `status` | `present` |
| `ok:true`, handle equal, `connected:false`, `writable:false`, no contradicting `status` | `missing` |
| `ok:false`, `error.code` is `terminal_handle_stale` | `missing` |
| anything else | `unreadable` |

### D2: Presence and the recovery vocabulary

`fm_backend_target_exists orca` is `present`-only.
`fm_backend_orca_agent_state` prints `missing`, `unreadable`, or `unverified` (live endpoint, no classifier).
`fm_backend_agent_alive` already folds `missing` to `dead` and the rest to `unknown`.

### D3: Callers

- The digest's endpoint line is unchanged.
- `fm-crew-state.sh`'s `pane_readable` uses `fm_backend_target_exists` for Orca, and its fallback maps `orca:missing` to `backend target gone` and other Orca states to `backend unreachable (orca endpoint state: ...)`.
- `fm_control_backend_state_verified` stays tmux and herdr only, so `exit`, `relaunch`, and secondmate restart keep refusing on Orca; the watcher's existing `dead|missing` branch now sees a dead Orca endpoint and stops typing into it.

### D4: Docs and records

`docs/orca-backend.md` corrects the "stays unverified" line, `bin/fm-backend.sh` and `bin/fm-control-lib.sh` headers name the Orca arm, and `docs/verification/runtime-backends.md` gets a dated lab entry.

## Project Structure

```text
bin/backends/orca.sh           endpoint_state, agent_state
bin/fm-backend.sh              target_exists and agent_state Orca arms, header
bin/fm-crew-state.sh           pane_readable and no-run fallback for Orca
bin/fm-control-lib.sh          comment only
docs/orca-backend.md           presence and verdict paragraph
docs/verification/runtime-backends.md  dated lab record
tests/fm-backend-orca.test.sh  adapter and backend fixtures
tests/fm-session-start.test.sh digest endpoint line on Orca
tests/fm-crew-state.test.sh    crew state on Orca
tests/fm-backend-orca-smoke.test.sh  live lab step A13
```
