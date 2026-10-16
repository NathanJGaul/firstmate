# Feature Specification: Restore Main CI

**Feature Branch**: `fm/firstmate-ci-green`

**Created**: 2026-10-16

**Status**: Draft

**Input**: User description: "Make the firstmate fork's own CI on main green again. Four of eighteen jobs fail on main (Behavior portable parallel 1, serial 5, serial 6, serial 9) from five distinct causes: the Pi extensions read the prompt on before_agent_start, which current Pi does not provide for custom-message-started runs; a merge dropped the slow-forge fault cases from the contributions test; Calm Pi tests copy the visibility module into scratch projects without its policy dependency; the wake-queue interruption test signals the wake drain at an arbitrary moment. Fix each at its cause without loosening budgets or skipping tests."

## Overview

Main has failed its checks on every run since 2026-10-07.
The latest red run (2026-10-14) has four of eighteen jobs failing.
Each red job was reproduced locally and traced to a separate cause: one real runtime defect in a shipped extension, two test fixtures left inconsistent by a merge or a later module split, and one test that signals a process at an unsafe moment.
While verifying, a fifth cause surfaced in the same job family: an intermittent crash of the OpenCode turn-end guard plugin (a second real runtime defect), added as user story 5.
The operator's standing rule is that lint, test failures, and flakiness are fixed even when unrelated to the work in hand, so the goal is a fleet whose own checks are trustworthy again.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A Pi-hosted primary survives a run that Pi starts from a custom message (Priority: P1)

An operator runs Firstmate's primary inside the current Pi release.
Firstmate's own extension sends a custom message that starts a run, for example the branch processing request.
Pi reports such a run without a user prompt.

**Why this priority**: The extension throws on every such run today, so this is the only cause that harms a real session and not only the checks.

**Independent Test**: Fire a run-start event that carries a custom message and no prompt at the branch-supervision and primary-watch extensions and observe that neither throws, nothing is mirrored as captain dialog, and a user-prompt run still behaves as before.

**Acceptance Scenarios**:

1. **Given** a run started by a custom message, **When** Pi announces the run start, **Then** the branch-supervision extension does not throw and mirrors no captain dialog from it.
2. **Given** a run started by a custom message that is the queued processing request, **When** Pi announces the run start, **Then** the extension still records that the processing request opened this run.
3. **Given** a run started by a user prompt, **When** Pi announces the run start, **Then** the prompt is staged as captain dialog and a pending wake with that exact text is consumed, exactly as today.
4. **Given** a run started by a custom message, **When** Pi announces the run start, **Then** the primary-watch extension consumes no pending wake.
5. **Given** the newest published Pi release and the release the failing run used, **When** the strict no-emit typecheck of the tracked Pi extensions runs, **Then** it reports no error.

---

### User Story 2 - The slow-forge budget check observes a slow forge (Priority: P1)

A maintainer relies on the contributions check test that proves a slow first pull request cannot starve the pull requests behind it.

**Why this priority**: The test currently fails because its fake forge no longer produces the slow reads it depends on, so the guarantee it pins is unverified.

**Independent Test**: Run the contributions test file and confirm the slow-head case spends its core and parallel-wave budget and every other case still passes.

**Acceptance Scenarios**:

1. **Given** the fake forge is set to the slow-wave fault, **When** the first poll runs, **Then** the slow head consumes at least eight seconds before the tail pull requests are read.
2. **Given** the restored fake forge, **When** the other budget cases run (reserve, exhaust, fail-late, hang, latency), **Then** each passes without any change to its asserted budget.
3. **Given** parallel forge callers advancing the shared fake clock, **When** they run concurrently, **Then** no caller observes a torn or lost clock value.

---

### User Story 3 - Calm Pi fixtures hold the complete extension (Priority: P1)

A maintainer runs the Calm Pi extension tests and the queue-retention live guard.
The visibility module they copy into scratch projects imports a policy module that was split out later.

**Why this priority**: Every fixture that lacks the policy module fails to load the extension, which hides the behavior those tests exist to pin.

**Independent Test**: Run the Calm Pi extension test file and the queue-retention live guard against the newest Pi release and confirm they load the extension and pass.

**Acceptance Scenarios**:

1. **Given** a scratch project built by a Calm Pi test, **When** the visibility module is copied in, **Then** the policy module it imports is copied in beside it.
2. **Given** the queue-retention live guard, **When** it builds its scratch project, **Then** Pi loads the probe extension and the guard reaches its assertions.

---

### User Story 4 - The wake-drain interruption test is deterministic (Priority: P2)

A maintainer relies on the test that interrupts the wake drain before it commits its raw read and then proves the durable row survives.

**Why this priority**: It failed once in four recent runs without a code change, and an intermittently red check teaches the fleet to ignore red.

**Independent Test**: Run the interruption case repeatedly under bash 5.2 with randomized fine-grained signal timing and confirm every run interrupts the drain and none lets it complete.

**Acceptance Scenarios**:

1. **Given** a drain parked at its test delay before the raw commit, **When** the test interrupts it, **Then** the drain exits with the interrupted status and the durable row replays exactly once.
2. **Given** the test waits for the drain, **When** the drain has not yet reached its delay, **Then** the test keeps waiting up to its bound and fails naming the missing boundary if it is never reached.
3. **Given** the interruption case, **When** it runs one thousand five hundred times with randomized timing under bash 5.2, **Then** no run reports an unexpected success.

---

### User Story 5 - The OpenCode turn-end guard survives a guard that does not read its payload (Priority: P2)

An operator runs Firstmate's primary inside OpenCode.
The turn-end guard plugin hands its stop payload to the guard script, and the script may exit before reading it.

**Why this priority**: A broken pipe on that write is raised as an unhandled error and crashes the host, and the same defect made the OpenCode plugin check fail about once in thirty isolated runs, which can turn any CI run red.

**Independent Test**: Run the OpenCode plugin case with a guard script that exits at once and a host stalled long enough that the script has already exited when the payload is written, and observe the host survives and still delivers the blind-turn prompt.

**Acceptance Scenarios**:

1. **Given** a guard script that exits without reading its payload, **When** the host fires a session-idle event, **Then** the plugin does not raise an unhandled error and delivers the blind-turn prompt.

---

### Edge Cases

- A Pi release older than the one that split the run-start event is not a supported host for the Pi extensions; the typecheck and the runtime narrowing target the current event shape.
- A newer Pi release changes the event again: the unpinned CI install exists to surface that on the next run, so the fix does not pin a version.
- A custom message that is not the processing request starts a run: it is neither mirrored nor treated as a processing run.
- A fixture lists a new dependency twice or in a different directory layout: the copy step is idempotent.
- The interruption test runs on a machine whose drain reaches the delay slowly: the wait is bounded and its failure names the boundary.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The branch-supervision extension MUST read a run's prompt only for runs started by a user prompt and MUST NOT throw for a run started by a custom message.
- **FR-002**: The branch-supervision extension MUST keep detecting that the queued processing request opened a run, using the custom message the run carries.
- **FR-003**: The primary-watch extension MUST consume a pending wake only for a run started by a user prompt.
- **FR-004**: The strict no-emit typecheck of the tracked Pi extensions MUST pass against the newest published Pi release and the release named in the failing run.
- **FR-005**: A regression case MUST fire a custom-message run-start with no prompt and assert it neither throws nor mirrors captain dialog.
- **FR-006**: The fake forge in the contributions test MUST apply the slow-wave fault to the reads it names, and MUST keep the shared fake clock safe under concurrent callers.
- **FR-007**: Every Calm Pi fixture that copies the visibility module MUST also copy the policy module it imports.
- **FR-008**: The queue-retention live guard MUST build a scratch project in which Pi can load its probe extension.
- **FR-009**: The wake-drain interruption case MUST signal the drain only after the drain is parked at its test delay, and MUST bound and name that wait.
- **FR-010**: No change MAY loosen a time budget, skip a case, delete an assertion, or weaken a gate; the CI gate-skip refusals stay as they are.
- **FR-011**: The change MUST NOT alter supervision behavior beyond FR-001 through FR-003 and FR-012.
- **FR-012**: The OpenCode turn-end guard plugin MUST treat a broken pipe on the guard's stdin as the guard's answer and MUST NOT raise it as an unhandled error.

### Key Entities

- **Run-start event**: Pi's announcement that an agent run is about to begin, carrying either a user prompt or a custom message.
- **Fake forge**: The scripted stand-in for the code host that the contributions test drives with named faults.
- **Calm fixture**: A scratch project a Calm test assembles from tracked extension modules.
- **Wake drain**: The script that presents queued wake rows and commits them once handling is acknowledged.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All eighteen jobs of the CI workflow pass on the delivery pull request.
- **SC-002**: The four named red jobs each pass in the same CI run, with the failing test files exiting zero.
- **SC-003**: A run started by a custom message produces zero extension errors in the regression case.
- **SC-004**: The interruption case shows zero unexpected successes across at least one thousand five hundred randomized runs under bash 5.2, against a baseline of one failure in 931.
- **SC-005**: No time budget, assertion, or skip in the touched tests is weaker than before.
- **SC-006**: The OpenCode plugin case shows zero failures in at least 150 runs under four-way parallel load, against a baseline of 5 failures in 80.

## Assumptions

- The fleet tracks the newest Pi release on purpose, so CI keeps installing it unpinned and the extensions adapt to its event shape.
- The upstream project already carries the Pi narrowing fix and its regression case; this fork adopts the same shape to keep later merges conflict-free.
- Restoring the upstream fake-forge cases is correct because the merge that dropped them kept the fork's older clock fix, and the upstream clock fix addresses the same race.
- A bash 5.2 trap-parsing fault under signal timing is outside this repository's code and is avoided by signalling at a quiescent point.
- Pi release tracking policy needs no new decision because this change keeps the existing unpinned policy.
