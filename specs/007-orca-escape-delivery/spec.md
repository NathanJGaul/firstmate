# Feature Specification: Orca Escape and Ctrl+U Delivery

**Feature Branch**: `fm/firstmate-orca-escape-delivery`

**Created**: 2026-11-19

**Status**: Implemented

**Input**: Deliver Escape and Ctrl+U on Orca so interrupt works for the harnesses that cancel with Escape (slice 9, P2-A), with the small version and capability gate it needs (slice 8, P2-C).
These are slices from section 5.2 of the Orca evaluation plan.

## Overview

Firstmate interrupts a worker by sending its harness's cancel key.
Thirteen of the fourteen verified harnesses cancel with Escape, and one of them also needs a Ctrl+U to clear the prompt it restores.
The Orca adapter delivers only Enter and Ctrl+C, so `bin/fm-control.sh <id> interrupt` refuses for all of them, and a wedged Orca worker cannot be interrupted.

The live lab showed the gap is the adapter's alone: Orca writes text sent to a terminal without `--enter` verbatim, so one control byte is one key press.
This feature sends Escape and Ctrl+U that way.

Because that behavior is proven on one runtime, it also adds the small compatibility gate the plan calls for.
Firstmate reads the runtime's `appVersion` and capability list from `orca status --json`, refuses a runtime older than the lowest one proven, and sends Escape and Ctrl+U only to a runtime that reports the capability they are gated on.
A runtime that does not report it keeps today's behavior.

## User Scenarios & Testing

### User Story 1 - Interrupt works on Orca for Escape harnesses (Priority: P1)

An operator interrupts a looping or confused worker whose task runs on the Orca backend.

**Why this priority**: It is the only way to stop a wedged turn without tearing the task down, and it is refused today for every harness but one.

**Independent Test**: Run `bin/fm-control.sh <id> interrupt` against a task recorded on Orca with a fake `orca` on the path, then read the fake's call log.

**Acceptance Scenarios**:

1. **Given** a task whose harness interrupts with Escape and a runtime that reports the gating capability, **When** the operator interrupts it, **Then** exactly one `terminal send` is made whose text is the single ESC byte, with neither `--enter` nor `--interrupt`, and the command reports `interrupt-delivered`.
2. **Given** a harness whose interrupt restores its prompt into the composer, **When** the operator interrupts it, **Then** the ESC send is followed by one send whose text is the single Ctrl+U byte, in that order.
3. **Given** a harness that interrupts with Ctrl+C, **When** the operator interrupts it, **Then** the send is still one `--interrupt` and needs no capability.
4. **Given** `fm-send <id> --key Escape` or `--key C-u` for an Orca task, **When** the runtime reports the capability, **Then** the key is delivered as the same raw byte.

---

### User Story 2 - A runtime without the capability gets no control byte (Priority: P1)

An operator runs against an Orca runtime that does not report the capability Escape and Ctrl+U are gated on.

**Why this priority**: The behavior is proven on one runtime, and a byte sent to a runtime that treats it differently could type into a prompt.

**Independent Test**: Call the adapter and the control plane against a fake whose `status --json` lacks the capability, or is unreadable, and read the call log.

**Acceptance Scenarios**:

1. **Given** a runtime that does not report the capability, **When** Escape or Ctrl+U is requested, **Then** nothing is sent, the call fails, and the message names the capability and the runtime version.
2. **Given** a runtime whose status cannot be read, **When** Escape or Ctrl+U is requested, **Then** nothing is sent and the call fails.
3. **Given** Enter or Ctrl+C is requested, **When** the runtime reports no capabilities at all, **Then** it is delivered exactly as before and the status is not read.
4. **Given** `bin/fm-control.sh <id> interrupt` for an Escape harness on such a runtime, **When** it runs, **Then** it fails before any key is sent and the message names the capability.

---

### User Story 3 - A runtime older than the tested floor is refused at spawn (Priority: P2)

An operator selects Orca on a host whose runtime is older than the one this adapter was proven against.

**Why this priority**: Every other Orca shape the adapter reads was observed on one runtime, and an older one is unproven rather than known broken.

**Independent Test**: Run the adapter's runtime check against fake status documents carrying different `appVersion` values.

**Acceptance Scenarios**:

1. **Given** a ready runtime reporting a version below 1.4.261, **When** the runtime check runs, **Then** it fails, and the message names the reported version, the floor, and the per-task `--backend` option.
2. **Given** a ready runtime reporting 1.4.261 or any later version, **When** the runtime check runs, **Then** it succeeds, comparing numerically so 1.10.0 is later than 1.4.261.
3. **Given** a ready runtime that reports no readable version, **When** the runtime check runs, **Then** it succeeds as today and enables nothing that is gated on a capability.
4. **Given** a ready runtime, **When** the runtime check succeeds, **Then** the version and the capability list it read are available to the caller.

---

### User Story 4 - Exit and relaunch stay refused (Priority: P2)

An operator tries to stop or relaunch an Orca worker.

**Why this priority**: Both need proof that the agent stopped, which Orca does not yet provide, and delivering Escape must not weaken that.

**Independent Test**: Run `exit` and `relaunch` against an Orca task whose runtime reports the capability, and read the call log.

**Acceptance Scenarios**:

1. **Given** an Orca task on a runtime with the capability, **When** `exit` or `relaunch` runs, **Then** it is refused naming the missing agent-state classifier and sends nothing.
2. **Given** the documentation that described interrupt as refused on Orca, **When** this feature lands, **Then** it says interrupt works, that exit and relaunch refuse, and why.

## Edge Cases

- The version carries a prerelease or build suffix: its numeric prefix is compared.
- The version has fewer than three numeric parts, or none: it is treated as unreadable, not as old.
- The capability list is absent or not a list: it is treated as empty.
- A harness that must see its screen between interrupt presses is still refused on Orca, because Orca has no verified viewport read.
- A task already running when the floor rises is not re-checked: the runtime check runs at spawn.

## Requirements

### Functional Requirements

- **FR-001**: The adapter MUST read `appVersion` and the capability list from `orca status --json` and make them available to the calling shell after a successful runtime check.
- **FR-002**: The runtime check MUST refuse a runtime whose readable version is below 1.4.261, naming the version, the floor, and the per-task `--backend` option.
- **FR-003**: The runtime check MUST NOT refuse a runtime whose version is absent or unreadable, and MUST enable nothing gated on a capability for it.
- **FR-004**: Version comparison MUST be numeric on the first three numeric parts.
- **FR-005**: The adapter MUST deliver Escape as one ESC byte and Ctrl+U as one Ctrl+U byte through `terminal send --text`, without `--enter` and without `--interrupt`.
- **FR-006**: The adapter MUST accept the spellings `Escape`, `escape`, `Esc`, `esc`, and `C-u`, `ctrl+u`, `Ctrl-u`, `Ctrl-U`.
- **FR-007**: The adapter MUST read the runtime status fresh before sending either byte, and MUST send nothing and fail, naming the capability and version, when the status is unreadable or does not report `terminal.ordered-input.v1`.
- **FR-008**: Enter and Ctrl+C MUST behave exactly as before and MUST NOT read the status.
- **FR-009**: The control plane's key table MUST list Escape and Ctrl+U as deliverable on Orca, so the live gate is the adapter's.
- **FR-010**: `exit` and `relaunch` MUST remain refused on Orca.
- **FR-011**: The Orca operating documentation, the control documentation, the key-support comments, and the stuck-worker recovery wording MUST state the new behavior and the gate.
- **FR-012**: The opt-in live lab MUST send Escape and Ctrl+U through the adapter and through `fm-send` and `fm-control interrupt`, read them back, and record the version and capability facts.

### Key Entities

- **Floor**: the lowest `appVersion` this adapter has live proof for, 1.4.261.
- **Gating capability**: `terminal.ordered-input.v1`, the marker closest to control-byte passthrough that the proven runtime reports.

## Success Criteria

- **SC-001**: Against a fake Orca reporting the capability, an interrupt of an Escape harness makes exactly one `terminal send` whose text is the ESC byte.
- **SC-002**: Against a fake Orca without the capability, an interrupt of an Escape harness exits non-zero and the call log holds no `terminal send`.
- **SC-003**: Against the lab runtime, `fm-send --key Escape` produces `^[` in the task terminal and `fm-control interrupt` reports delivery on `backend=orca`.

## Assumptions

- Orca documents no capability for control-byte passthrough, and its 306-entry list on 1.4.261 holds none by that name, so `terminal.ordered-input.v1` is a proxy marker chosen because the runtime where passthrough was proven reports it.
- The floor equals the one proven runtime. The 1.4.116 macOS app recorded earlier in the verification record is therefore refused at spawn until it is updated or re-proven.
- An interrupt of a real harness turn is not run in the lab, because its isolated home holds no harness credentials and a turn spends model tokens; the lab proves the byte reaches a real Orca terminal through the real control path.
