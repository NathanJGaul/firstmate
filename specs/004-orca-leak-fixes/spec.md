# Feature Specification: Orca Backend Leak Fixes

**Feature Branch**: `fm/firstmate-orca-leak-fixes`

**Created**: 2026-11-17

**Status**: Draft

**Input**: Stop the Orca backend leaking a spare terminal and a stray branch per task (slices P1-A and P1-B of the Orca evaluation plan, lead 4, section 4 and section 5.2 rows 2 and 3).

## Overview

On Orca 1.4.261, creating a task worktree already starts a terminal for it.
Firstmate ignores that terminal and creates a second one, so every Orca task has two live shells and the first is never recorded, watched, or closed by name.
Orca also names its own branch for each task worktree, and releasing the worktree leaves that branch behind, so every shipped task leaves one stray local branch in the project.

This feature makes an Orca task own exactly one terminal for its whole life, and makes releasing an Orca task remove the branch Orca made when Orca can prove that is safe.
It changes nothing about how firstmate decides whether a task's work has landed.

## User Scenarios & Testing

### User Story 1 - An Orca task has exactly one terminal (Priority: P1)

The operator dispatches a ship or scout task on the Orca backend.

**Why this priority**: The spare shell is a live process per task that firstmate never recorded, and the teardown reaper has to find and kill it.

**Independent Test**: Spawn against a fake Orca whose worktree creation reports a startup terminal, then read the fake's command log and the recorded task metadata.

**Acceptance Scenarios**:

1. **Given** Orca reports a startup terminal for the new worktree, **When** the task is spawned, **Then** that terminal is the task's recorded terminal, it is titled with the task's name, and no second terminal is created.
2. **Given** Orca reports a terminal in the verified `terminal` shape and no startup terminal, **When** the task is spawned, **Then** that terminal is adopted exactly as before and no second terminal is created.
3. **Given** Orca reports neither a startup terminal nor a terminal, **When** the task is spawned, **Then** firstmate creates one titled terminal for the worktree, as before.
4. **Given** Orca reports a startup terminal that it did not spawn, **When** the task is spawned, **Then** firstmate does not adopt it and creates one titled terminal instead.
5. **Given** Orca reports a startup terminal but no worktree path, **When** the spawn fails, **Then** that terminal is closed and the worktree is released, so the failed spawn leaves nothing behind.

---

### User Story 2 - Releasing an Orca task removes the branch Orca made (Priority: P1)

The operator tears down a finished Orca ship task.

**Why this priority**: The stray branch accumulates in the project one per shipped task and is invisible to the task records.

**Independent Test**: Tear down a fake-Orca task and read the fake's command log for the worktree release.

**Acceptance Scenarios**:

1. **Given** a torn-down Orca task, **When** the worktree is released, **Then** the release asks Orca to delete the worktree's branch in Orca's safe mode, and never in a forced mode.
2. **Given** Orca cannot prove the branch merged, **When** the release runs, **Then** Orca keeps the branch and the release still succeeds, so a task with unlanded commits loses nothing.
3. **Given** a spawn that failed after the worktree was created, **When** its cleanup releases the worktree, **Then** the same branch-deleting release is used.
4. **Given** teardown's existing refusals (dirty worktree, unlanded work, id or path mismatch, unresolvable worktree), **When** any applies, **Then** teardown refuses exactly as before and no release is attempted.

## Edge Cases

- Orca returns both a `terminal` and a startup terminal: the verified `terminal` shape is adopted.
  The Orca runtime this was written against returns only the startup terminal, so this case is not expected.
- Orca's rename of the adopted terminal fails: the terminal is already the task's, the title is cosmetic, so the spawn continues.
- Orca reports a startup terminal with an empty or missing handle: treated as no terminal, so the fallback creates one.
- Orca's release reports an error: teardown preserves the task records and refuses, exactly as before.
- An existing stale branch in any project is not touched by this change.

## Requirements

### Functional Requirements

- **FR-001**: The Orca adapter MUST accept the startup terminal's handle from a worktree creation result as the worktree's first terminal, when Orca reports it spawned.
- **FR-002**: The Orca adapter MUST keep accepting the verified `terminal` shape, and that shape MUST win when both shapes are present.
- **FR-003**: When a first terminal is adopted, the adapter MUST title it with the task's name, and a failed title MUST NOT fail the spawn.
- **FR-004**: When a first terminal is adopted, the spawn MUST NOT create another terminal.
- **FR-005**: When neither shape yields a handle, the spawn MUST create one titled terminal for the worktree, unchanged.
- **FR-006**: When worktree creation reports no path, the adapter MUST close the adopted terminal and release the worktree, unchanged in shape and now covering a startup terminal.
- **FR-007**: The Orca worktree release MUST pass Orca's safe branch-deleting option, MUST keep passing the existing force option, and MUST NOT use any forced branch deletion.
- **FR-008**: Teardown's landed-work refusals and the worktree id and path checks MUST be unchanged, and MUST still run before any release.
- **FR-009**: No existing branch in any project is deleted by this change, and no test or fixture may delete one.

### Key Entities

- **Startup terminal**: The terminal Orca starts with a new worktree, reported in the worktree creation result with a handle, a spawned flag, and other fields firstmate does not use.
- **Orca-made branch**: The branch Orca names after the git user and the worktree for each task worktree.
- **Task terminal**: The one terminal firstmate records in a task's metadata and later closes at teardown.

## Success Criteria

### Measurable Outcomes

- **SC-001**: After a spawn against a fake Orca that reports a startup terminal, the log shows exactly one terminal for the task and zero terminal creations.
- **SC-002**: After a spawn against a fake Orca that reports neither shape, the log shows exactly one terminal creation.
- **SC-003**: Every Orca worktree release in the log carries the safe branch-deleting option and no forced branch-deleting option.
- **SC-004**: All existing Orca backend, teardown, and spawn tests pass with their assertions updated only for the new release argument.

## Assumptions

- Orca 1.4.261 is the runtime in use, and its worktree creation result carries `result.startupTerminal.handle` with `spawned: true`, per the evaluation report, which read it from the runtime's response builder.
- Orca 1.4.261's release accepts a branch-deleting option that deletes only branches Orca can prove merged and keeps all others, per its own help text.
- No Linux Orca lab exists yet, so everything here is proven against a fake Orca only.
  Live proof, a single live terminal after spawn and the stray branch gone after a landed ship and kept after an unlanded one, waits for the lab slice.
- Older Orca hosts print a warning for the branch option and keep their existing branch policy, so they behave as today.

## Out of scope

- Deleting the one existing stale branch in `projects/pricing-sheet`, which is a separate captain call.
- Folder-kind repo rejection, CLI discovery, the version and capability gate, Escape delivery, recovery-grade agent state, and delivery receipts, which are other slices.
- The teardown reaper, backend-neutral browser sessions, and the documentation truth pass.
