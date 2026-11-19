# Feature Specification: Orca Endpoint Presence

**Feature Branch**: `fm/firstmate-orca-endpoint-presence`

**Created**: 2026-11-19

**Status**: Draft

**Input**: Make the cheap endpoint-presence read on Orca tell a live terminal from an exited, closed, or unknown one, and add a `missing` verdict (slice N2a of the Orca agentic CLI scout report, section 3.2 and section 6.2).

## Overview

On Orca, `fm_backend_target_exists` runs `terminal read` and treats any successful answer as "present".
Orca answers a read with `ok:true` for a terminal whose shell has exited and for one that was closed (`status:"exited"`), so a dead endpoint reads as alive.
The session-start digest prints `endpoint: alive` for it, `bin/fm-crew-state.sh` classifies it through the same read and never says the target is gone, and the watcher cannot tell a dead Orca terminal from a live one before it types into it.

Orca reports the truth in the terminal's own record.
`terminal show` returns `connected` and `writable` (both true for a live terminal, both false with an `exitCause` for an exited or closed one) and answers `terminal_handle_stale` for a handle the runtime does not know.

This feature reads those fields.
A terminal is present only when it is connected and writable, missing when it is positively not, and unreadable when the answer is anything else.
`fm_backend_agent_state` gains an Orca arm that prints `missing` for an authoritatively absent endpoint, `unreadable` for a read that failed or contradicted itself, and `unverified` for a live endpoint, because no process classifier exists yet.
It does not build that classifier, a reclaim, or any new control verb (later slices).

## User Scenarios & Testing

### User Story 1 - The cheap presence read stops calling a dead terminal present (Priority: P1)

Anything that asks "does this task's Orca terminal still exist" gets a true answer.

**Why this priority**: Every recovery decision on Orca starts from this read, and today it is wrong for the one case that matters.

**Independent Test**: Source `bin/fm-backend.sh` against a fake `orca` answering `terminal show` with each of the four real shapes and read `fm_backend_target_exists`.

**Acceptance Scenarios**:

1. **Given** a live terminal (`connected:true`, `writable:true`), **When** presence is read, **Then** it succeeds.
2. **Given** an exited shell or a closed terminal (`connected:false`, `writable:false`, with an `exitCause`), **When** presence is read, **Then** it fails.
3. **Given** a handle the runtime answers `terminal_handle_stale` for, **When** presence is read, **Then** it fails.
4. **Given** any other answer (another error code, a contradictory record, invalid JSON, no `orca` CLI), **When** presence is read, **Then** it fails, as an unreadable terminal always did.

---

### User Story 2 - A dead Orca endpoint shows as dead in the digest and in crew state (Priority: P1)

**Why this priority**: These are the two surfaces the supervisor reads to decide a task needs recovery.

**Independent Test**: Run `bin/fm-session-start.sh` and `bin/fm-crew-state.sh` against task records on Orca with a fake `orca` answering each state.

**Acceptance Scenarios**:

1. **Given** an Orca task whose terminal has exited or been closed, **When** the digest is built, **Then** its line reads `endpoint: dead`.
2. **Given** a live Orca terminal, **When** the digest is built, **Then** its line reads `endpoint: alive`.
3. **Given** an Orca task with no run attributed and a dead or stale terminal, **When** crew state is read, **Then** it is `unknown` with the detail `backend target gone`.
4. **Given** an Orca terminal whose read fails without proving absence, **When** crew state is read, **Then** the detail says the endpoint state is unreadable and is never reported as gone.

---

### User Story 3 - `missing` is a verdict on Orca (Priority: P2)

**Why this priority**: The recovery contract only licenses action on `dead` and `missing`, and the watcher already refuses to type into an endpoint it reads as missing.

**Independent Test**: Call `fm_backend_agent_state orca <terminal>` and `fm_backend_agent_alive` against the same fixtures.

**Acceptance Scenarios**:

1. **Given** an exited, closed, or stale terminal, **When** the agent state is read, **Then** it is `missing` and `fm_backend_agent_alive` is `dead`.
2. **Given** a live terminal, **When** the agent state is read, **Then** it is `unverified` and `fm_backend_agent_alive` is `unknown`, exactly as before.
3. **Given** a failed or contradictory read, **When** the agent state is read, **Then** it is `unreadable` and `fm_backend_agent_alive` is `unknown`.
4. **Given** an Orca task, **When** `exit`, `relaunch`, or a secondmate restart is requested, **Then** the control plane still refuses, because the capability table is unchanged.

## Edge Cases

- A terminal that is connected but not writable, or writable but not connected, is neither present nor missing: it reads unreadable.
- A `terminal show` answer whose handle differs from the requested one is a contradiction and reads unreadable.
- A `status` field, when the answer carries one, must agree with the verdict (`exited` against a live record, or `running` against a dead one, reads unreadable).
- A runtime that is stopped, unreachable, or answers non-JSON is unreadable, never missing: only a positive answer from the runtime proves absence.
- `terminal_handle_stale` also answers for a handle that belongs to another paired server; this adapter only ever addresses the local runtime that issued the handle, so a stale answer from it means the terminal is gone from it.
- The read is read-only, names the terminal explicitly, and never starts a runtime, creates anything, or reads scrollback.

## Requirements

### Functional Requirements

- **FR-001**: The adapter MUST expose one endpoint-state read that prints `present`, `missing`, or `unreadable` from a single `orca terminal show --terminal <handle> --json` call.
- **FR-002**: `present` MUST require `ok:true`, the requested handle, `connected:true`, and `writable:true`.
- **FR-003**: `missing` MUST require either `connected:false` and `writable:false` on an `ok:true` answer for the requested handle, or `ok:false` with `error.code` `terminal_handle_stale`.
- **FR-004**: Every other answer, including a `status` that contradicts the record, MUST be `unreadable`.
- **FR-005**: `fm_backend_target_exists orca` MUST succeed only for `present`.
- **FR-006**: `fm_backend_agent_state orca` MUST print `missing`, `unreadable`, or `unverified` for `missing`, `unreadable`, and `present` respectively, and its header MUST say so.
- **FR-007**: `bin/fm-crew-state.sh` MUST read Orca presence through `fm_backend_target_exists` and report `backend target gone` only for a `missing` state.
- **FR-008**: The session-start digest MUST need no code change to print `endpoint: dead` for a non-present Orca endpoint, and a test MUST prove it.
- **FR-009**: `fm_control_backend_state_verified` and the control plane MUST be unchanged, so no stop-proving verb becomes available on Orca.
- **FR-010**: The change MUST touch no backend other than Orca and MUST add no process classifier, reclaim, or control verb.
- **FR-011**: The four real states MUST be proven against the live lab, and the dated result recorded in `docs/verification/runtime-backends.md`.

## Success Criteria

- A closed or exited Orca terminal reads as not present on every surface that reads presence.
- A live Orca terminal reads as present, and nothing about a live task changes.
- The lab shows each of the four states the way the fixtures assume.
