# Feature Specification: Orca Local Process Classifier

**Feature Branch**: `fm/firstmate-orca-process-classifier`

**Created**: 2026-11-19

**Status**: Draft

**Input**: Prove what runs inside a live Orca terminal from the local process table, so the recovery-grade agent state on Orca can print `alive`, `dead`, and `ambiguous` (slice N2b of the Orca agentic CLI scout report, section 3.2 and section 6.2).

## Overview

The endpoint-presence slice made `fm_backend_agent_state` on Orca print `missing` for an absent terminal and `unverified` for every live one, because nothing yet proved which process runs inside a live terminal.
Orca's own agent state cannot supply that proof.
`worktree ps`, `terminal show`, and `agent list|show` keep reporting an agent as present, with its last state, for as long as the terminal's shell lives, including after the agent was killed.

Every process started inside an Orca terminal carries the terminal's handle in its environment as `ORCA_TERMINAL_HANDLE=<handle>`.
On the host that runs the runtime, the process table therefore answers the question directly: the processes of one handle are an agent, only shells, or something else.
This is the same model the tmux and Herdr adapters use, and the same shared name classifier decides what counts as an agent or a shell.

This feature adds that classifier to the Orca adapter.
When the endpoint is present and the runtime is on this host, it scans the process table for the exact handle and prints `alive`, `dead`, or `ambiguous`.
Every case it cannot prove, a runtime that may be on another host, a process table that cannot be read, a handle no local process carries, stays `unverified` or `unreadable`.
It never prints `alive` or `dead` on a guess.

It does not enable `exit`, `relaunch`, or reclaim on Orca, which stay refused until the reclaim slice, and it does not read any native Orca agent state.

## User Scenarios & Testing

### User Story 1 - A live Orca terminal running a harness reads alive (Priority: P1)

**Why this priority**: A false `dead` is the one outcome that can launch a duplicate agent onto a live worktree, so the positive verdict has to be correct before any negative one is trusted.

**Independent Test**: Run `fm_backend_agent_state orca <terminal>` against a fake `orca` that answers a present terminal and a fake process table in which one process carries the handle and is named for a harness.

**Acceptance Scenarios**:

1. **Given** a present terminal whose handle is carried by a shell and a process named for a verified harness, **When** the agent state is read, **Then** it is `alive`.
2. **Given** a harness process that does not carry the handle itself but is a descendant of a process that does, **When** the agent state is read, **Then** it is `alive`.
3. **Given** a harness identified only by its argv[0] (a node-bundled harness run by a bare `node`), **When** the agent state is read, **Then** it is `alive`.

---

### User Story 2 - A live terminal with only a shell reads dead (Priority: P1)

**Why this priority**: This is the verdict recovery acts on, the Orca equivalent of Herdr's shell-only pane.

**Independent Test**: The same fake pair, with a process table holding only shells for the handle, and the live lab with a real binary named `claude` killed with SIGKILL.

**Acceptance Scenarios**:

1. **Given** a present terminal whose handle is carried only by recognized shells, **When** the agent state is read, **Then** it is `dead` and `fm_backend_agent_alive` is `dead`.
2. **Given** the same terminal after a harness process that carried the handle was killed, **When** the agent state is read, **Then** it is `dead`, even though Orca's native state still names the agent.
3. **Given** an exited agent that is still a zombie child of the shell, **When** the agent state is read, **Then** the zombie does not count as a running agent.

---

### User Story 3 - What cannot be attributed stays ambiguous, unverified, or unreadable (Priority: P1)

**Why this priority**: Only proof licenses recovery, so every uncertain case has to refuse.

**Independent Test**: Fake process tables for each case below.

**Acceptance Scenarios**:

1. **Given** processes for the handle that are neither a harness nor a shell, **When** the agent state is read, **Then** it is `ambiguous`.
2. **Given** an environment that selects a non-local Orca runtime (`ORCA_ENVIRONMENT`, `ORCA_PAIRING_CODE`, or `ORCA_REMOTE_PAIRING` set), **When** the agent state is read for a present terminal, **Then** it is `unverified` and the process table is not read.
3. **Given** a host with no readable process table, **When** the agent state is read, **Then** it is `unverified`.
4. **Given** a present terminal that no local process carries the handle of, **When** the agent state is read, **Then** it is `unverified`, because the runtime may be on another host.
5. **Given** a process table that cannot be listed, or a process that cannot be placed in the tree or classified, **When** the agent state is read, **Then** it is `unreadable`, unless a harness was positively found, which is `alive`.
6. **Given** an absent terminal or a failed endpoint read, **When** the agent state is read, **Then** it is `missing` or `unreadable` exactly as before and no process table is read.

---

### User Story 4 - The control plane stays refused (Priority: P2)

**Why this priority**: Enabling `exit`, `relaunch`, and reclaim is the next slice and needs its own proof.

**Independent Test**: The control-plane capability table, against an Orca endpoint that reads `dead`.

**Acceptance Scenarios**:

1. **Given** an Orca task whose agent state is `dead`, **When** `exit`, `relaunch`, or a secondmate restart is requested, **Then** the control plane still refuses.

## Edge Cases

- Terminal handles are matched as exact whole environment entries, so `term_1` never matches `term_10`.
- A harness whose launcher re-executes it with a cleaned environment no longer carries the handle itself, so the scan includes every descendant of a process that does.
- The scanner's own process is never counted, even when the caller itself runs inside the terminal being classified.
- A process that exits while the table is read is a vanished process, not an unreadable one.
- Only a process of the current user can be shown to carry the handle, because only its environment is read, and the runtime's terminal processes are that user's; the parent links of every process are read, so a descendant below a process of another user is still found.
- A process of the current user whose environment the kernel refuses to show (`systemd --user` on a normal desktop) is opaque: it is reached through the process tree when it descends from a carrier, and it is never treated as unreadable by itself, because that would make every negative verdict unreachable.
- A transient helper process in an otherwise idle shell (a prompt helper) reads `other` for a moment, so `ambiguous` is only reported after a short bounded settle.
- Native Orca agent state, hooks, `worktree ps`, `agent list`, and `agent show` are never read as proof of an agent or of its absence.

## Requirements

### Functional Requirements

- **FR-001**: The adapter MUST expose one process-state read for a terminal handle that scans the process table for processes whose environment holds the exact entry `ORCA_TERMINAL_HANDLE=<handle>`, together with every descendant of such a process, and classifies each with the shared classifier in `bin/fm-agent-process-lib.sh`.
- **FR-002**: The read MUST report `agent` when any such process is a verified harness, `shell` when at least one process was found and every one is a recognized shell, and `other` when a process was found that is neither.
- **FR-003**: `fm_backend_orca_agent_state` MUST first read endpoint presence; `missing` and `unreadable` endpoints keep their verdicts and read no process table.
- **FR-004**: For a present endpoint it MUST print `alive` for `agent`, `dead` for `shell`, and `ambiguous` for `other` after a bounded settle that resamples only `other`.
- **FR-005**: It MUST print `unverified` without reading the process table when the environment selects a non-local runtime (`ORCA_ENVIRONMENT`, `ORCA_PAIRING_CODE`, or `ORCA_REMOTE_PAIRING` non-empty), when the host has no process table, and when no local process carries the handle.
- **FR-006**: It MUST print `unreadable` when the process table cannot be listed or when a process cannot be placed in the tree or classified (a failed `stat`, a failed command line, or an environment that failed for a reason other than vanishing or a refused read) and no harness was found; a found harness stays `alive`.
- **FR-007**: A zombie and a process that vanished during the scan MUST NOT count as a running process.
- **FR-008**: The scan MUST be read-only, MUST NOT use any native Orca agent state, and MUST add no `orca` call beyond the endpoint presence read.
- **FR-009**: The process-table location MUST be overridable for tests through `FM_ORCA_PROC_ROOT`, defaulting to `/proc`.
- **FR-010**: `fm_control_backend_state_verified` and the control plane MUST be unchanged, so `exit`, `relaunch`, reclaim, and secondmate restart stay refused on Orca.
- **FR-011**: The change MUST touch no backend other than Orca and MUST add no reclaim or control verb.
- **FR-012**: The live lab MUST show a terminal running a real binary named `claude` as `alive`, the same terminal after SIGKILL as `dead`, and a closed terminal as `missing`, and the dated result MUST be recorded in `docs/verification/runtime-backends.md`.

## Success Criteria

- On the host that runs the runtime, a live Orca terminal reads `alive` while a harness runs in it and `dead` once the harness is gone, regardless of what Orca's native state still says.
- No uncertain case ever reads `alive` or `dead`.
- Nothing about a task's control-plane refusals on Orca changes.
