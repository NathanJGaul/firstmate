# Feature Specification: Orca Live Lab Hardening

**Feature Branch**: `fm/firstmate-orca-lab-hardening`

**Created**: 2026-11-19

**Status**: Approved by the dispatching instructions (slice L1 of the Orca agentic-CLI scout report)

**Input**: Harden the Orca live lab after the scout found two hazards: the lab launcher does not pin `HOME`, and the lab runtime starts a real `codex app-server` by name at boot.

## Overview

The opt-in Orca live lab (`tests/fm-backend-orca-smoke.test.sh`, guards in `tests/orca-lab-safety.sh`) starts its own headless Orca runtime on a throwaway data directory.
Two environment facts let a lab run reach outside that sandbox if it is ever extended past read-only calls.

First, `orca agent hooks status` computes its config-file paths client-side from the caller's `HOME`.
The lab launcher removes every `ORCA_*` variable but keeps `HOME`, so a CLI call through it named the operator's real agent config files.
`agent hooks on|off` and `skills install|update|share` write to those paths.

Second, the runtime starts `codex -c approval_policy=never ... app-server` by name about one second after it is ready.
A lab runtime whose `PATH` reaches a real `codex` would run it, and a real agent directory on that `PATH` makes the lab less inert than it looks.

Separately, a worker shell can inherit the primary terminal's `ORCA_TERMINAL_HANDLE` and `ORCA_WORKTREE_ID`, so a bare `orca terminal read|send` from it would act on the primary's terminal.
That is not a lab hazard but must be recorded with the launch path that carried it.

## User Scenarios & Testing

### User Story 1 - The lab launcher always pins HOME (Priority: P1)

A maintainer extends the lab past read-only calls.

**Independent Test**: Run the guard test; it needs no Orca.

**Acceptance Scenarios**:

1. **Given** a launcher written for a fresh lab home, **When** it is run with the operator's real `HOME` in the caller's environment, **Then** the CLI process receives `HOME` equal to the lab home.
2. **Given** a missing or empty home, **When** the launcher is written, **Then** the write is refused and no launcher file exists.
3. **Given** a home equal to, containing, or inside the operator's `HOME` agent config directories or Orca directories, **When** the launcher is written, **Then** the write is refused and no launcher file exists.
4. **Given** a home that already holds files, **When** the launcher is written, **Then** the write is refused.
5. **Given** the caller carries agent-config pointers such as `CODEX_HOME` or `CLAUDE_CONFIG_DIR` or `XDG_CONFIG_HOME`, **When** the launcher runs the CLI, **Then** none of them reaches it.

### User Story 2 - The lab runtime PATH holds no real agent (Priority: P1)

The lab starts its runtime.

**Acceptance Scenarios**:

1. **Given** the lab's fake-bin directory, **When** the runtime `PATH` is built, **Then** it is exactly that directory plus `/usr/bin:/bin`.
2. **Given** a `PATH` with any entry holding an executable named for a real agent (`claude`, `codex`, `opencode`, `pi`, `grok`, and the other harnesses), **When** it is checked, **Then** it is refused naming the entry and the agent.
3. **Given** a `PATH` with an empty or relative entry, **When** it is checked, **Then** it is refused because such an entry resolves against the working directory.

### User Story 3 - The lab proves the pin live (Priority: P2)

**Acceptance Scenarios**:

1. **Given** a running lab, **When** `agent hooks status --json` runs through the launcher, **Then** every `configPath` it reports lies inside the lab home, and a path outside it fails the lane.

### User Story 4 - The hazards and the inherited-handle fact are recorded (Priority: P2)

**Acceptance Scenarios**:

1. The Orca verification entry records the `codex app-server` boot probe, the `HOME` and `PATH` rules, and how to re-check them.
2. It records that a worker shell can inherit `ORCA_TERMINAL_HANDLE` and `ORCA_WORKTREE_ID` from the primary's terminal and names the launch path that was traced, or says the path is unknown.

## Requirements

- **FR-001**: `orca_lab_write_launcher` takes the lab home as a required fifth argument, refuses an unsafe home before writing anything, and the launcher it writes exports that `HOME`.
- **FR-002**: The launcher removes `CODEX_HOME`, `CLAUDE_CONFIG_DIR`, `OPENCODE_CONFIG_DIR`, `PI_CODING_AGENT_DIR` and the four `XDG_*_HOME` pointers.
- **FR-003**: `orca_lab_runtime_path` builds the runtime `PATH`, and `orca_lab_assert_path_agent_free` refuses a `PATH` that can reach a real agent or resolves against the working directory.
- **FR-004**: The live lane starts the runtime with that `PATH` and refuses to start when the check fails.
- **FR-005**: `orca_lab_paths_under_home` fails when any reported config path lies outside the lab home, and the live lane asserts it on `agent hooks status --json`.
- **FR-006**: `tests/fm-backend-orca-lab-guard.test.sh` covers FR-001 to FR-003 and FR-005 without Orca.
- **FR-007**: `docs/verification/runtime-backends.md` records the boot probe, the rules, and the inherited-handle trace.

## Out of scope

Any change to the adapter, `fm-spawn`, staged Orca builds, Orca's agent launch, orchestration, hooks or accounts verbs, and the other open Orca slices.
