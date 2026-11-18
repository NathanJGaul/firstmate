# Feature Specification: Per-Worker Browser Session

**Feature Branch**: `fm/firstmate-worker-browser-session`

**Created**: 2026-11-17

**Status**: Draft

**Input**: Every Firstmate worker gets its own chrome-devtools-axi browser session, so one worker's browser-bridge failure no longer stalls the others, on every runtime backend.

## Overview

All workers launched by Firstmate share one machine-wide default chrome-devtools-axi browser session.
That session is one bridge process on one fixed port with one on-disk state directory.
When that single bridge loses its browser or its port is held by another process, every worker that uses the browser fails together with `BRIDGE_NOT_READY`.
The failure has recurred since 2026-10-18 on every backend, and it currently blocks a worker that needs to sign in to a website.
The tool already supports named sessions, each with its own bridge, port, and state, selected by one environment variable.
Firstmate never sets it.

This feature gives each worker a session named after its task, and stops that session when the task is cleaned up.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A worker's browser is its own (Priority: P1)

The operator dispatches several workers at once.
Each worker that uses the browser gets a bridge that no other worker shares.

**Why this priority**: This is the whole problem.
Without it, one broken bridge stalls every browser-using worker.

**Independent Test**: Spawn workers against a fake pane, run the emitted launch command with the harness replaced by a probe, and read the session variable the probe sees.

**Acceptance Scenarios**:

1. **Given** a ship spawn, **When** the launch command runs, **Then** the agent starts with `CHROME_DEVTOOLS_AXI_SESSION` equal to its task id.
2. **Given** a scout spawn, **When** the launch command runs, **Then** the agent starts with `CHROME_DEVTOOLS_AXI_SESSION` equal to its task id.
3. **Given** a local secondmate spawn, **When** the launch command runs, **Then** the agent starts with `CHROME_DEVTOOLS_AXI_SESSION` equal to its task id.
4. **Given** a pane whose own environment already carries a different `CHROME_DEVTOOLS_AXI_SESSION`, **When** the launch command runs, **Then** the agent still starts with its task id, not the inherited value.
5. **Given** a relaunch of an existing task, **When** the replacement launch command runs, **Then** the agent starts with the same task-id session.
6. **Given** two workers with different task ids, **When** their launch commands run, **Then** their sessions differ.

---

### User Story 2 - The session survives the launch-environment allowlist (Priority: P1)

An operator who opted into the launch-environment allowlist still gets per-worker sessions.

**Why this priority**: The allowlist clears the environment before the agent starts.
A variable that is lost there would silently leave allowlisted fleets on the shared session.

**Independent Test**: Spawn with an empty allowlist file present, run the emitted launch command under a synthetic pane, and read the variable the probe sees, both with and without the pane-side exports having landed.

**Acceptance Scenarios**:

1. **Given** a present, empty launch-environment allowlist, **When** a ship launch runs, **Then** the agent starts with its task-id session.
2. **Given** a present allowlist, **When** only the launch command runs and the pane-side exports never landed, **Then** the agent still starts with its task-id session.
3. **Given** an absent allowlist, **When** a launch runs, **Then** the agent starts with its task-id session, as in the allowlisted case.

---

### User Story 3 - Cleanup stops the task's own session (Priority: P1)

When a task is cleaned up, the browser bridge and browser it started do not outlive it.

**Why this priority**: Bridges are detached daemons whose working directory is outside the task's isolated copy, so the existing leaked-process cleanup never reaches them.
Without a stop, each task would leave a bridge and a browser running.

**Independent Test**: Run cleanup against a fake chrome-devtools-axi that records the session variable and arguments of each call.

**Acceptance Scenarios**:

1. **Given** a task whose launch exported a session, **When** cleanup runs, **Then** chrome-devtools-axi is invoked once with `stop` and with `CHROME_DEVTOOLS_AXI_SESSION` equal to that task's id.
2. **Given** that cleanup, **When** the stop runs, **Then** it runs after the leaked-process cleanup for the task's isolated copy.
3. **Given** a stop that fails or times out, **When** cleanup runs, **Then** cleanup still completes, the failure is reported as a warning, and the exit status is unchanged.
4. **Given** a host with no chrome-devtools-axi installed, **When** cleanup runs, **Then** cleanup completes with no error.
5. **Given** a cleanup that refuses because work is unlanded, **When** it refuses, **Then** no session is stopped.

---

### User Story 4 - The shared default session is never touched (Priority: P1)

The machine-wide default session, and any session that is not the task's own, is left alone.

**Why this priority**: The default session may be in use by the operator or by workers launched before this change.
Stopping it would break them.

**Independent Test**: Spawn and clean up a task whose id is `default`, and clean up tasks around a fake chrome-devtools-axi that fails the test if it sees the default session.

**Acceptance Scenarios**:

1. **Given** a task whose id is `default`, **When** its launch is built, **Then** no `CHROME_DEVTOOLS_AXI_SESSION` is exported by Firstmate.
2. **Given** a task whose id is `default`, **When** cleanup runs, **Then** no stop is issued.
3. **Given** any cleanup, **When** the stop is issued, **Then** `CHROME_DEVTOOLS_AXI_SESSION` is set explicitly to the task's id, so an inherited value from the cleanup caller can never select another session.
4. **Given** a task id that is not a valid session name, **When** cleanup runs, **Then** no stop is issued.

## Edge Cases

- A task id longer than 64 characters or with characters outside the tool's session-name set cannot name a session; such a task launches and cleans up with no session handling.
- A relaunch must not change the session name, so an agent that had a browser open keeps reaching the same bridge.
- Two Firstmate homes that use the same task id name the same session; stopping it from one home stops the other's bridge, which restarts on the next browser command.
- Remote secondmates never pass through the local launch path and are unchanged.
- Cleanup of a task spawned before this change stops a session named after its id; no such bridge exists, so the stop is a no-op.
- The stop can take a few seconds while the bridge and its browser exit, and must not be able to hold cleanup indefinitely.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Every local worker launch (ship, scout, local secondmate, raw command, and relaunch) MUST start its agent with `CHROME_DEVTOOLS_AXI_SESSION` set to the task id.
- **FR-002**: The value MUST override any `CHROME_DEVTOOLS_AXI_SESSION` already present in the pane or the spawning environment.
- **FR-003**: The value MUST reach the agent whether or not a launch-environment allowlist is present, and whether or not the pane-side exports landed.
- **FR-004**: A task id that equals the tool's default session name, or that is not a valid session name for the tool, MUST get no Firstmate-exported session.
- **FR-005**: Task cleanup MUST stop the task's own session by invoking chrome-devtools-axi `stop` with `CHROME_DEVTOOLS_AXI_SESSION` set explicitly to the task id.
- **FR-006**: The stop MUST run after the leaked-process cleanup and only after every refusal that protects unlanded work has passed.
- **FR-007**: The stop MUST be best effort: a missing tool, a failure, or a timeout MUST warn at most and MUST NOT change cleanup's outcome or exit status.
- **FR-008**: The stop MUST be time-bounded.
- **FR-009**: Cleanup MUST NOT stop the default session, and MUST NOT stop any session other than the one named by the task's id.
- **FR-010**: The rule that decides whether a task id names a session MUST have one owner, shared by launch and cleanup, so the two cannot disagree.
- **FR-011**: The launch-environment contract documentation MUST state that the variable is exported on every launch and survives the allowlist.

### Key Entities

- **Task id**: The validated bare slug that names a task; the only input to the session name.
- **Browser session**: The chrome-devtools-axi bridge, port, and state selected by `CHROME_DEVTOOLS_AXI_SESSION`.
- **Default session**: The session chrome-devtools-axi uses when the variable is unset or named `default`.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In a fleet of N concurrent workers, each worker's launch carries a distinct session name, for 100 percent of ship, scout, and local secondmate launches.
- **SC-002**: A failed or wedged browser session for one worker leaves every other worker's browser session working.
- **SC-003**: After cleanup of a task, no browser bridge named after that task remains running.
- **SC-004**: Cleanup never issues a stop for the default session, in any test case.
- **SC-005**: Cleanup's exit status and completion are identical whether the stop succeeds, fails, times out, or the tool is absent.

## Assumptions

- chrome-devtools-axi's named-session support is the supported isolation mechanism, and a session name is 1 to 64 characters from letters, digits, dot, underscore, and hyphen.
- Firstmate task ids are already limited to that character set and, at creation, to 64 characters, and never start with a dot.
- Each named session derives its port from its name, so two names can hash to the same port; the tool documents this as a concurrency limit, and it is out of scope here.
- An operator-set `CHROME_DEVTOOLS_AXI_PORT` overrides the derived port and would put workers back on one port; setting or clearing it is out of scope.
- Workers do not need to share browser state across tasks; the browser profile and connection mode are unchanged by naming a session.

## Out of Scope

- Recycling the existing default bridges, or any worker, browser, or terminal not created by this change.
- Per-task ports, a session registry, or collision avoidance beyond the tool's own derivation.
- Making the browser session visible in task metadata or status.
- Any other runtime-backend or Orca slice.
