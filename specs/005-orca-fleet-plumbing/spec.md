# Feature Specification: Orca Fleet Plumbing

**Feature Branch**: `fm/firstmate-orca-fleet-plumbing`

**Created**: 2026-11-18

**Status**: Draft

**Input**: Make bootstrap checks follow each live task's recorded backend, keep the `ORCA_*` variables in the launch-env floor, and name wakes by task alias for backends with opaque handles (slices P3-B, P3-C, and P3-D of the Orca evaluation plan, section 5.2 rows 12, 13, and 14).

## Overview

Three small gaps keep a home that mixes backends, or runs workers on Orca, from behaving like a single-backend home.

1. Bootstrap checks only the tools the home's default backend needs.
   A task already running on another backend (for example an Orca task in a Herdr home) is never checked, so a missing tool for that backend goes unreported until something fails.
2. The optional launch-env allowlist keeps a fixed floor of backend routing variables for `tmux`, Herdr, cmux, and Zellij, and omits Orca's.
   A worker launched on Orca under an allowlist loses the variables Orca injected into its terminal.
3. A wake for a task on a backend whose terminal handle is opaque reads `stale: term_<uuid>` or `stale: default:w5X:p2`, which names no task.

This feature closes all three, each in the script that already owns the behavior.

## User Scenarios & Testing

### User Story 1 - Bootstrap follows the backends tasks actually run on (Priority: P1)

The operator starts a session in a home whose default backend differs from the backend of some live task.

**Why this priority**: A missing tool for a running task's backend is exactly the failure bootstrap exists to report at session start.

**Independent Test**: Run bootstrap in a fake home whose default backend is one backend and whose `state/` holds a task record for another, with the second backend's tool absent from `PATH`.

**Acceptance Scenarios**:

1. **Given** a default backend of `tmux` and a live task recorded on `orca`, **When** `orca` is absent, **Then** bootstrap reports `orca` missing.
2. **Given** the same fleet, **When** `orca` is present, **Then** bootstrap reports nothing for the task's backend.
3. **Given** a default backend of `orca` and a live task recorded with no backend field, **When** `tmux` and `treehouse` are absent, **Then** bootstrap reports them, because a task without a recorded backend runs on `tmux`.
4. **Given** several live tasks on one non-default backend, **When** its tool is absent, **Then** the tool is reported once.
5. **Given** no live task records, **When** bootstrap runs, **Then** its output is exactly what it was before this change for every default backend.

---

### User Story 2 - An allowlisted Orca launch keeps Orca's variables (Priority: P1)

The operator enables `config/launch-env-allowlist` and dispatches a task on Orca.

**Why this priority**: Without the floor, enabling the allowlist silently strips the identity and hook variables Orca gave the worker's terminal.

**Independent Test**: Spawn on a fake Orca with an empty allowlist file, replay the emitted launch under a synthetic terminal environment carrying Orca's variables, and read what the harness process receives.

**Acceptance Scenarios**:

1. **Given** an enabled allowlist and an Orca terminal carrying the Orca variables, **When** the task launches, **Then** the harness process receives every one of those variables with its value.
2. **Given** a variable the terminal does not carry, **When** the task launches, **Then** it stays unset and is not forced to an empty value.
3. **Given** an enabled allowlist, **When** the task launches, **Then** a variable outside the floor and the allowlist, including an `ORCA_`-prefixed name outside the observed Orca set, is still removed.
4. **Given** no allowlist file, **When** the task launches, **Then** the launch is byte-identical to before.

---

### User Story 3 - Wakes name the task (Priority: P2)

The operator reads a wake for a task on a backend whose terminal handle does not name the task.

**Why this priority**: Every such wake costs a lookup to learn which task it is about.

**Independent Test**: Drive the watcher against a fake fleet with an Orca task and a Herdr task and a tmux task, and read each wake reason and the queued wake record.

**Acceptance Scenarios**:

1. **Given** an Orca task whose terminal handle is `term_<uuid>`, **When** the watcher emits a stale wake, **Then** the reason reads `stale: fm-<id>`.
2. **Given** a Herdr task whose handle is `<session>:<pane>`, **When** the watcher emits a stale wake, **Then** the reason reads `stale: fm-<id>`.
3. **Given** a tmux task whose window name already ends in a component starting `fm-`, **When** the watcher emits a stale wake, **Then** the reason is byte-identical to before.
4. **Given** any backend, **When** a wake is queued, **Then** the queue record's routing key is still the recorded handle.
5. **Given** a stale wake naming a task by label, **When** the away-mode daemon classifies it, **Then** it resolves the same task and keeps the same per-task markers as it does for the handle form.
6. **Given** a window with no task record, **When** a wake is emitted, **Then** the reason keeps the handle, because there is no task to name.

## Edge Cases

- A recorded backend value this version does not know: it has no dependency set, so it adds no tool requirement and no diagnostic; only the default backend's invalid value reports `BACKEND_INVALID`, as before.
- A task record with a blank or missing backend field: it runs on `tmux`.
- A secondmate record counts as a live task for its recorded backend.
- Reasons that carry a detail suffix, such as an idle age or an unread-instruction note, keep that suffix after the label.
- Orca meta carries `window=fm-<id>` and `terminal=term_<uuid>`; the watcher keys the window by the terminal, so the label comes from the task record, not from the window field.

## Requirements

### Functional Requirements

- **FR-001**: Bootstrap MUST require the union of the default backend's tools and the tools of every backend recorded by a live task record in the home's `state/`.
- **FR-002**: A task record with no backend field MUST count as `tmux`.
- **FR-003**: A recorded backend this version does not know MUST add no requirement and MUST NOT change the default backend's invalid-backend diagnostic.
- **FR-004**: A tool required by several backends MUST be reported at most once.
- **FR-005**: The treehouse durable-lease check MUST run whenever any required backend uses treehouse.
- **FR-006**: With no live task records, bootstrap output MUST be unchanged for every default backend.
- **FR-007**: The launch-env operational floor MUST retain every `ORCA_` variable an Orca 1.4.261 terminal exports (terminal identity, CLI routing, agent-hook, runtime-source, and per-agent configuration pointers), as names expanded in the destination terminal, with unset names left unset.
- **FR-008**: The floor MUST NOT retain any other variable, and an absent allowlist MUST leave the launch unchanged.
- **FR-009**: The header contract in `bin/fm-spawn.sh` and the "Variables retained" section of `docs/configuration.md` MUST list the Orca names.
- **FR-010**: A stale wake reason MUST name the task as `fm-<id>` when its window handle's last `:`-component does not already start with `fm-` and a task record resolves the handle.
- **FR-011**: A handle whose last `:`-component already starts with `fm-`, or that no task record resolves, MUST appear unchanged.
- **FR-012**: The wake queue's routing key MUST remain the recorded handle.
- **FR-013**: Every `stale:` reason the watcher emits MUST use the same naming, whatever detail follows it.
- **FR-014**: The away-mode daemon MUST classify a label-form stale reason to the same task and markers as the handle form.

### Key Entities

- **Task record**: `state/<id>.meta`, whose `backend=` field (absent means `tmux`) records where the task runs.
- **Launch-env floor**: the fixed list of variable names `bin/fm-spawn.sh` forwards through the cleared environment.
- **Wake reason**: the human-readable text of a queued wake, distinct from the wake's routing key.

## Success Criteria

- **SC-001**: A home whose default backend differs from a live task's backend reports that task's missing tool at session start.
- **SC-002**: A worker launched on Orca under an empty allowlist starts with the same Orca variables it would receive with no allowlist.
- **SC-003**: No wake reason for a task with a record shows a bare `term_<uuid>` or `<session>:<pane>` handle.
- **SC-004**: A home with only default-backend tasks sees byte-identical bootstrap output, launch text, and tmux wake reasons.

## Assumptions

- Orca 1.4.261 names its terminal variables as observed in a live Orca terminal; names a later Orca adds are not retained until added to the floor.
- Slice P3-A (browser session) and the other Orca slices are separate work and are not touched.
- `CLAUDE_CODE_PLUGIN_DIRS`, which Orca also injects for its agent view, does not carry the `ORCA_` prefix, so this slice leaves it out; it is noted as follow-up.
- Live proof against a real Orca runtime is out of scope; all proof uses fake `orca` fixtures.
