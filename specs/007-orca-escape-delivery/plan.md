# Implementation Plan: Orca Escape and Ctrl+U Delivery

**Branch**: `fm/firstmate-orca-escape-delivery` | **Date**: 2026-11-19 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/007-orca-escape-delivery/spec.md`

## Summary

Two edits to the Orca adapter and the lists that describe it.

1. **Status facts and the version floor** (`bin/backends/orca.sh`).
   `fm_backend_orca_status_read` reads `orca status --json`, requires a ready runtime, and records the version, the capability list, and whether a readable version is below the floor.
   `fm_backend_orca_runtime_check` becomes that read plus the floor refusal.
2. **Escape and Ctrl+U** (`bin/backends/orca.sh`).
   `fm_backend_orca_send_key` gains the two keys, each guarded by `fm_backend_orca_control_bytes_ready` and sent through the existing literal send.
   `fm_control_backend_supports_key` lists them for Orca.

Documentation, the key-support comments, the recovery wording, the verification record, and the opt-in lab follow.

## Technical Context

**Language/Version**: Bash 3.2-compatible shell, with a Node snippet for the JSON the adapter already parses that way

**Primary Dependencies**: none new; the fake `orca` already used by the suites

**Storage**: none

**Testing**: extend `tests/fm-backend-orca.test.sh` and `tests/fm-control.test.sh`; run each with `bin/fm-test-run.sh <file>`; the opt-in lab is `tests/fm-backend-orca-smoke.test.sh`

**Target Platform**: Linux and macOS

**Project Type**: shell CLI toolkit, single project

**Constraints**: shellcheck-clean through `bin/fm-lint.sh`; Enter, Ctrl+C, and every other backend byte-identical; no live Orca beyond the lab's own runtime

**Scale/Scope**: one adapter, one table, two test files, the lab, and five documentation surfaces

## Constitution Check

The constitution carries the TDD principle recorded in `.specify/memory/tdd-profile.md`: every behavior was driven by a failing test first (`tdd/cycle-log.md`), and no test was weakened.

## Design

### D1: The adapter owns the live gate

See `research.md` D1 and D2.
`send_key` calls `fm_backend_orca_control_bytes_ready` before any send for Escape and Ctrl+U, and the function reads the status itself, so every caller (`fm-control`, `fm-send --key`) is gated by one mechanism.

### D2: One reader, two consumers

`fm_backend_orca_status_read` is the single parse of the status document.
The runtime check consumes the floor flag, and the key gate consumes the capability list.
The readiness test that was inline in the runtime check moves into it unchanged, so its messages and exit behavior are the same.

### D3: Version comparison in the parser

The Node snippet that already parses the status compares the first three numeric parts and emits one flag, so there is no shell version arithmetic and no `sort -V`, which older macOS lacks.

### D4: The key table stays a fact about the adapter

`fm_control_backend_supports_key orca` returns true for all four keys, and its comment points at the live gate, so `docs/agent-control.md`'s description of it as a pure table stays true.

### D5: Lab proof without a model turn

The lab sends the keys through the adapter, through `fm-send`, and through `fm-control interrupt` with the lab task's own record labelled as a verified harness, then reads the echoed `^[` back.
It does not start an agent turn.
