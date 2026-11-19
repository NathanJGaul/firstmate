# Feature Specification: Orca Live Test Lab

**Feature Branch**: `fm/firstmate-orca-test-lab`

**Created**: 2026-11-18

**Status**: Draft

**Input**: Build the isolated Linux live test lane for the Orca backend (slice 6, P0-A of the Orca evaluation plan, section 5.2 row 6 and section 6), so Orca behavior is proven against a real Orca runtime and not only fakes.

## Overview

Every Orca test in the repository drives a fake `orca` command, so each proves Firstmate's side of the contract and none proves Orca's real behavior.
Merged slices (startup-terminal adoption, safe branch deletion, folder-kind refusal) and held slices (Escape delivery, agent-state proof, delivery receipts, interrupt and relaunch) depend on response shapes that were never exercised live.

This feature adds an opt-in live lane that starts its own throwaway headless Orca runtime, drives it through the assertions of report section 6.1, then drives Firstmate's own spawn, peek, send, state, and teardown scripts against it.
It also adds guard tests that prove the lane can never reach the operator's own Orca runtime or Orca data.

## User Scenarios & Testing

### User Story 1 - The lab can never touch the operator's Orca (Priority: P1)

A maintainer runs the live lane on a workstation where their own Orca runtime is running with real repositories, worktrees, and terminals.

**Why this priority**: The lane starts processes and creates and removes worktrees; a mistake against the operator's runtime destroys real work.

**Independent Test**: Run the guard test, which needs no Orca installation, and confirm each unsafe setup is refused before any process starts or any path is written.

**Acceptance Scenarios**:

1. **Given** `FM_ORCA_LIVE_E2E` is unset or not `1`, **When** the lane runs, **Then** it skips with an opt-in message and starts nothing.
2. **Given** the data-directory variable is the operator's Orca data directory, a parent of it, or a child of it (including through a symlink), **When** the lane runs, **Then** it refuses and starts nothing.
3. **Given** a caller-supplied data directory that already holds files, **When** the lane runs, **Then** it refuses, because the lab only runs against a fresh directory.
4. **Given** the runtime that answers is not the child process the lab started, or its recorded owner data directory differs from the lab's, **When** any lab step would mutate it, **Then** the step is refused and no signal is sent to that process.
5. **Given** the caller's environment carries other Orca variables that would redirect the command line to another runtime, **When** the lab runs its commands, **Then** those variables are not passed on.
6. **Given** every object the lab creates, **When** it is named, **Then** the name carries the `fm-test-` prefix, and cleanup removes only objects it created by exact name.

---

### User Story 2 - The maintainer sees real Orca shapes (Priority: P1)

A maintainer with Orca installed opts in and runs the lane to learn what Orca really returns.

**Why this priority**: The held slices cannot be designed against shapes nobody has seen.

**Independent Test**: Run the lane with `FM_ORCA_LIVE_E2E=1` on a host with the headless Orca runtime installed and read its output.

**Acceptance Scenarios**:

1. **Given** the lab runtime is ready, **When** the lane runs, **Then** it reports the runtime's app version, capability count, and degradations.
2. **Given** a scratch git repository and a scratch non-git folder, **When** the lane registers them, **Then** it confirms the repository's kind is git and the folder's kind is folder, and reports what a worktree create does under the folder.
3. **Given** a worktree create, **When** the lane inspects the response, **Then** it reports whether a startup terminal, a terminal, or neither was returned, asserts the worktree is a linked git worktree inside the lab, and reports the live terminal count.
4. **Given** a shell and a minimal full-screen program in a lab terminal, **When** the lane sends Escape, Ctrl+U, and an interrupt and reads the terminal, **Then** it records the bytes the program received and the read status and source for each form.
5. **Given** a fake agent started as the terminal's command, **When** the lane reads agent identity and the worktree's agent list before and after it exits, **Then** it reports what Orca can and cannot prove about "no agent".
6. **Given** text sent with the submit-wait and retry options, **When** the lane inspects the receipts, **Then** it records their shape and whether a retried send repeats the input.
7. **Given** a landed branch and an unmerged branch, **When** the lane closes the terminals and removes each worktree, **Then** the landed branch is gone, the unmerged branch is kept, and no terminal, process, or worktree directory remains.
8. **Given** a running terminal, **When** the lab runtime alone is stopped and restarted, **Then** the lane records whether the terminal and its process survive and keep their handle.
9. **Given** an assertion the host cannot run, **When** the lane reaches it, **Then** it states exactly why and what stays unknown, and never reports a pass.

---

### User Story 3 - Firstmate's own scripts run against real Orca (Priority: P1)

A maintainer wants proof that spawn, peek, send, crew state, and teardown work on a real Orca, not only on a fake.

**Why this priority**: The merged slices changed these paths and have only fake-Orca proof.

**Independent Test**: Run the lane's Firstmate-level section against the lab runtime.

**Acceptance Scenarios**:

1. **Given** a lab project and a raw `sh -c cat` harness, **When** the lane spawns a task on the Orca backend, **Then** the task records a terminal and an Orca worktree inside the lab, and the lane reports the live terminal count.
2. **Given** that task, **When** the lane peeks and sends text and a key, **Then** the terminal shows the delivered text, and each key outcome is recorded.
3. **Given** that task, **When** the lane reads crew state, **Then** the state names the task and its backend.
4. **Given** a dirty task worktree, and separately a task branch holding an unlanded commit, **When** teardown runs, **Then** it refuses each time and leaves the terminal and worktree in place.
5. **Given** a clean task, **When** teardown runs, **Then** the worktree, terminal, and records are gone.
6. **Given** the run is over, **When** the lane inventories the lab, **Then** it finds zero leftover terminals, processes, worktrees, and branches, and its runtime and terminal host have stopped.

---

### User Story 4 - The verification record states what was observed (Priority: P2)

A maintainer reads the verification record to learn what the lab proved and what stays unknown.

**Why this priority**: The shapes are only useful if recorded where the held slices look.

**Independent Test**: Read the Linux headless entry of the runtime-backends verification record.

**Acceptance Scenarios**:

1. **Given** a lane run, **When** the record is read, **Then** it holds the dated version, commands, real response shapes, and capabilities.
2. **Given** each assertion, **When** the record is read, **Then** it names the held or merged slice the assertion unblocks or proves.
3. **Given** an assertion that could not run, **When** the record is read, **Then** it says why and what is unknown.

### Edge Cases

- The headless runtime is not installed: the lane skips when not requested and fails when requested, naming what is missing.
- The lab runtime fails to become ready: the lane fails, stops only what it started, and removes its directory.
- The run is interrupted: cleanup still stops the lab runtime and its terminal host, and removes only the lab directory.
- The caller's shell already runs inside an Orca terminal: its Orca variables are not inherited by the lab.
- A worktree is created outside the lab directory: the lane refuses to continue and removes only that worktree by exact id.
- The user home holds the operator's Orca workspaces: the lab runtime gets its own home so nothing is written there.

## Requirements

### Functional Requirements

- **FR-001**: The lane MUST be opt-in and MUST skip with a single runner-readable line unless `FM_ORCA_LIVE_E2E=1`.
- **FR-002**: Before any process starts, the lane MUST refuse a data directory that equals, contains, or lies inside the operator's Orca data directory or Orca installation directory, resolved through symlinks.
- **FR-003**: The lane MUST create its own fresh data directory, and MUST refuse a caller-supplied one that is not empty or absent.
- **FR-004**: The lane MUST start its runtime as its own child, bound to loopback on a free port, with the data directory set explicitly and the Orca variables of the caller removed.
- **FR-005**: The lane MUST give every Orca command line it runs a launcher pinned to the lab data directory, and MUST put that launcher first on the search path.
- **FR-006**: Before every mutating step the lane MUST prove the target runtime is its own child: recorded process id equals the started child, the process environment names the lab data directory, and the reported runtime id matches the recorded one.
- **FR-007**: The lane MUST signal only process ids it has just proven to belong to the lab, and MUST never list-and-delete the operator's repositories, worktrees, or terminals.
- **FR-008**: Every object the lane creates MUST carry the `fm-test-` prefix, and every removal MUST name the exact object.
- **FR-009**: The lane MUST run report assertions 1 through 10 as far as the runtime allows, and MUST record assertion 11 as not run with the reason.
- **FR-010**: The lane MUST run the Firstmate-level checks: spawn on the Orca backend with a raw harness, peek, send text and key, crew state, dirty and unlanded teardown refusals, a clean teardown, and a final inventory.
- **FR-011**: The lane MUST separate hard assertions, which fail the run, from observations and findings, which are reported and never counted as passes.
- **FR-012**: A guard test MUST prove, without Orca installed, that the lane refuses a wrong opt-in, a missing or unsafe data directory, a non-empty data directory, a non-lab runtime, and never signals a non-lab process.
- **FR-013**: Both tests MUST be classified in the test runner so its coverage check stays green, with the live lane in the opt-in live family.
- **FR-014**: The verification record MUST gain a Linux headless entry with the dated version, commands, real shapes, capabilities, the slice each assertion unblocks, and every assertion that could not run.
- **FR-015**: The lane MUST NOT change adapter behavior.
- **FR-016**: A scheduled non-blocking nightly workflow MUST be added only if it fails soft on artifact download errors and cannot affect required checks; otherwise the follow-up MUST be documented.

### Key Entities

- **Lab**: the throwaway directory holding the runtime data, launcher, scratch repository, scratch folder, workspaces, and home.
- **Lab runtime**: the headless Orca runtime process and its terminal host, both started and stopped by the lane.
- **Observation**: a reported fact about a real response that the lane records without asserting it.
- **Finding**: an observation that contradicts what a merged or held slice assumes.

## Success Criteria

### Measurable Outcomes

- **SC-001**: Every unsafe setup in User Story 1 is refused by the guard test, with no process started and no path written.
- **SC-002**: A full lane run on a host with the runtime leaves zero lab processes, zero lab directories, and no change to the operator's Orca data, repositories, worktrees, or terminals.
- **SC-003**: Every assertion in report section 6.1 is either run with a recorded result or recorded as not run with its reason.
- **SC-004**: The verification record names, for every assertion, the slice it unblocks.
- **SC-005**: The default test suite and the runner's coverage check stay green with the live lane skipped.

## Assumptions

- The Linux headless Orca runtime installed by Orca's managed-runtime install is the target; its entry points are found from the command-line shim Orca writes, with an environment override.
- The nightly workflow is a documented follow-up, because a pinned runtime artifact and its mirror are unknown.
- Adapter changes that the findings call for are follow-ups and out of scope here.
- Assertion 11 needs a real browser on the operator's desktop and is recorded as not run.
