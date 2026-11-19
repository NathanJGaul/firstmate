# Feature Specification: Orca Spare Terminal

**Feature Branch**: `fm/firstmate-orca-spare-terminal`

**Created**: 2026-11-19

**Status**: Draft

**Input**: Stop each Orca task from ending with two live terminals (slice P1-A of the Orca evaluation plan, re-planned from the live findings of the Linux test lab).

## Overview

Orca starts a terminal together with every new worktree.
On the Linux headless runtime (Orca 1.4.261) the worktree creation response names neither `startupTerminal` nor `terminal`, although that terminal exists and is listed by `orca terminal list --worktree`.
Firstmate therefore finds nothing to adopt, creates a second terminal, and every task ends with two live terminals (`worktree ps` reports `liveTerminalCount=2`).
Only the second one is recorded, watched, and closed by name.

This feature makes the adapter find the worktree's existing terminal when the response names none, adopt and title it, and create a new terminal only when the worktree genuinely has none.
Adoption from the response (`terminal`, then `startupTerminal`) stays as it is, so a newer Orca that names the terminal keeps working.

## User Scenarios & Testing

### User Story 1 - An Orca task has exactly one terminal on a runtime that names none (Priority: P1)

The operator dispatches a ship or scout task on the Orca backend, and Orca's worktree creation response names no terminal.

**Why this priority**: The spare shell is a live process per task that firstmate never recorded.

**Independent Test**: Spawn against a fake Orca whose worktree creation names no terminal and whose terminal list holds one terminal for the worktree, then read the fake's command log and the task metadata.
The same behavior is proven live in the isolated Orca lab (`worktree ps` reports `liveTerminalCount=1` after spawn).

**Acceptance Scenarios**:

1. **Given** the response names no terminal and Orca lists one terminal for the new worktree, **When** the task is spawned, **Then** that terminal is the task's recorded terminal, it is titled with the task's name, and no terminal is created.
2. **Given** the response names no terminal and Orca lists none for the new worktree, **When** the task is spawned, **Then** firstmate creates one titled terminal, as before.
3. **Given** the response names a `terminal` or a spawned `startupTerminal`, **When** the task is spawned, **Then** that terminal is adopted exactly as before and the terminal list is not consulted.
4. **Given** the terminal list cannot be read (the command fails, reports an error, or returns something unparseable), **When** the task is spawned, **Then** firstmate falls back to creating one titled terminal and the spawn does not fail.
5. **Given** the terminal list holds only terminals that cannot be used (orphaned, not writable, belonging to another worktree, or without a handle), **When** the task is spawned, **Then** none is adopted and firstmate creates one titled terminal.
6. **Given** the response names no path and Orca lists a terminal for the worktree, **When** the spawn fails, **Then** the listed terminal is closed and the worktree is released, so the failed spawn leaves nothing behind.

---

### User Story 2 - Teardown closes exactly the recorded terminal (Priority: P1)

The operator tears down a finished Orca task whose terminal was adopted from the list.

**Why this priority**: Adopting a terminal must not change what teardown closes or leave anything behind.

**Independent Test**: Tear down a task whose metadata records the adopted handle against a fake Orca and read the close calls; live, spawn and teardown in the lab and take the final inventory.

**Acceptance Scenarios**:

1. **Given** a task whose recorded terminal was adopted from the list, **When** it is torn down, **Then** exactly that terminal is closed and the worktree is released.
2. **Given** a live lab spawn followed by teardown, **When** the lab takes its final inventory, **Then** zero terminals, worktrees, branches, and lab processes are left over.

## Edge Cases

- The list holds more than one usable terminal for a fresh worktree: the first usable one is adopted and the rest are left alone, since a fresh worktree is not expected to hold more than one.
- The title rename of the adopted terminal fails: the terminal is already the task's, the title is cosmetic, so the spawn continues.
- The terminal list row names a different worktree than the one requested: it is never adopted, so a task can never close another task's terminal.
- Both `terminal` and `startupTerminal` are present: the verified `terminal` shape still wins and the list is not consulted.

## Requirements

### Functional Requirements

- **FR-001**: When worktree creation names no usable terminal, the adapter MUST read `orca terminal list --worktree id:<worktree id> --json` and adopt the first listed terminal that has a non-empty handle, is not orphaned, is not reported unwritable, and (when the row names its worktree) belongs to the created worktree.
- **FR-002**: A terminal named by the worktree creation response (`result.terminal`, then a spawned `result.startupTerminal`) MUST still be adopted first, and the terminal list MUST NOT be consulted in that case.
- **FR-003**: An adopted terminal MUST be titled with the task's name, and a failed title MUST NOT fail the spawn.
- **FR-004**: When a terminal is adopted from the list, the spawn MUST NOT create another terminal.
- **FR-005**: When the list yields no usable terminal, or cannot be read for any reason, the spawn MUST create one titled terminal for the worktree, unchanged.
- **FR-006**: When worktree creation reports no path, the adapter MUST close the terminal adopted from the list, release the worktree, and issue no title, as it already does for a terminal named by the response.
- **FR-007**: Teardown MUST still close exactly the terminal recorded in the task's metadata, and its refusals and checks MUST be unchanged.
- **FR-008**: The adapter MUST NOT create, rename, or close any terminal that it did not either create itself or adopt for the new worktree.
- **FR-009**: The adapter's stdout contract (`<worktree id>\t<path>[\t<terminal>]`) and the task metadata fields MUST be unchanged.

### Key Entities

- **Listed terminal**: A row of `result.terminals[]` from `orca terminal list --worktree`, carrying `handle`, `worktreeId`, `orphaned`, `writable`, `connected`, and other fields firstmate does not use.
- **Task terminal**: The one terminal firstmate records in a task's metadata and later closes at teardown.

## Success Criteria

### Measurable Outcomes

- **SC-001**: A spawn against a fake Orca that names no terminal and lists one logs zero `terminal create` calls and one `terminal rename`, and records the listed handle.
- **SC-002**: A spawn against a fake Orca that names no terminal and lists none logs exactly one `terminal create` call.
- **SC-003**: In the isolated live lab, `worktree ps` reports `liveTerminalCount=1` after `fm-spawn --backend orca`, and the final inventory after teardown finds zero leftovers.
- **SC-004**: All existing Orca backend, spawn, and teardown tests pass with their assertions changed only where the new terminal list call is logged.

## Assumptions

- Orca 1.4.261 (Linux headless runtime) lists the new worktree's terminal immediately after `worktree create` returns, observed live in the isolated lab on three runs with the first poll already reporting `totalCount=1`.
- `terminal list --worktree id:<id> --json` returns `result.terminals[]` rows with `handle`, `worktreeId`, `orphaned`, `writable`, `connected`, and `result.totalCount`, recorded in `docs/verification/runtime-backends.md`.
- A runtime that creates the terminal asynchronously after the response would, at worst, leave the old behavior (one created terminal), never a failure; no retry or delay is added.

## Out of scope

- The version and capability gate, Escape delivery, recovery-grade agent state, delivery receipts, and other slices of the evaluation plan.
- Changing how the Orca-made branch is removed, or the captain's Orca registration.
- Closing any terminal in a worktree other than the one just created.
