# Feature Specification: Orca Close-and-Recreate Reclaim, Exit, and Relaunch

**Feature Branch**: `fm/firstmate-orca-reclaim`

**Created**: 2026-11-19

**Status**: Draft

**Input**: Allow `bin/fm-control.sh` `exit` and `relaunch` and `bin/fm-spawn.sh --relaunch` on Orca tasks, but only on proof, and reclaim a task whose terminal is gone or dead by creating a fresh terminal in the recorded worktree (slice N3 of the Orca agentic CLI scout report, section 3.3 and section 6.2).

## Overview

The endpoint-presence slice and the process classifier made `fm_backend_agent_state` on Orca print `missing`, `alive`, `dead`, `ambiguous`, `unverified`, or `unreadable` from proof, never from Orca's own agent state.
The control plane still refuses `exit` and `relaunch` on Orca, and `bin/fm-spawn.sh --relaunch` carries an Orca arm that can never run: a relaunch gate refuses Orca first, and the arm never recorded the Orca worktree id or terminal it would republish.
A dead Orca worker therefore cannot be recovered without tearing its task down.

Orca offers a better reclaim than an in-place relaunch.
Closing a terminal returns a receipt (`ptyKilled: true`) and takes the agent with it, and `terminal create` makes a replacement terminal inside the same worktree in one call.
So a task whose agent is dead or whose terminal is gone is reclaimed by putting exactly one fresh terminal in its recorded worktree, republishing the task's `terminal=` record, and resuming the harness the way relaunch does on every other backend.
A wedged agent that no read can classify as stopped is stopped by closing its terminal, and the close receipt is the positive stopped proof.

The worktree, its branch, its commits, and its uncommitted changes are never touched, because closing a terminal removes no worktree content and no path here calls `worktree rm`.
Every state that is not proven keeps refusing, and the refusal names the state.

## User Scenarios & Testing

### User Story 1 - A task whose agent died in a live terminal is relaunched in that terminal (Priority: P1)

**Why this priority**: This is the common failure (a harness crashed or was killed) and the case the process classifier was built for.

**Independent Test**: A fake `orca` plus a fake process table reading `dead`, and the live lab with a renamed `sleep` killed with SIGKILL.

**Acceptance Scenarios**:

1. **Given** an Orca task whose terminal is present and holds only shells, **When** `fm-control relaunch` runs, **Then** the existing terminal is adopted, no terminal is created or closed, the record keeps its `terminal=`, and the harness is launched in it.
2. **Given** the same task, **When** `fm-control exit` runs, **Then** it reports `already-stopped` and sends nothing.
3. **Given** the live lab, **When** the raw harness is killed and the task relaunched, **Then** exactly one terminal remains for the worktree, no stray process remains, the worktree and its commits are intact, and the record names the same terminal.

---

### User Story 2 - A task whose terminal is gone is reclaimed with a fresh terminal (Priority: P1)

**Why this priority**: A closed or destroyed terminal strands a worker with nothing to supervise, and this is what Orca's close-and-recreate makes cheap and safe.

**Independent Test**: A fake `orca` that reports the recorded terminal closed, and the live lab with a closed terminal.

**Acceptance Scenarios**:

1. **Given** a recorded terminal that the local runtime positively reports gone, **When** `fm-control exit` runs, **Then** it reports `endpoint-gone`.
2. **Given** the same task, **When** `fm-control relaunch` runs, **Then** the dead terminal is closed first, one fresh terminal is created in the recorded worktree by its recorded id, the task record is republished atomically with the new `terminal=` and the unchanged `orca_worktree_id=`, and the harness is launched in the new terminal.
3. **Given** the reclaim, **When** it finishes, **Then** the worktree, branch, commits, and uncommitted changes are exactly as left, and no `worktree rm` was made.
4. **Given** a terminal that does not read gone once closed, or a replacement that cannot be created or listed, **When** the reclaim runs, **Then** it stops before launching and the previous record stands.

---

### User Story 3 - A wedged agent is stopped by closing its terminal (Priority: P2)

**Why this priority**: No read can prove a wedged but running agent stopped, yet it is the case a supervisor most needs `relaunch` for.

**Independent Test**: A fake `orca` returning a close receipt, and the live lab with a running renamed binary.

**Acceptance Scenarios**:

1. **Given** an Orca task whose agent reads `alive`, **When** `exit` or `relaunch` runs without the explicit close request, **Then** it refuses naming `alive` and the way to close.
2. **Given** the same task, **When** `exit --close-terminal` runs, **Then** the terminal is closed, `ptyKilled: true` is the stopped proof, the endpoint and its processes are confirmed gone, and it reports `closed`.
3. **Given** the same task, **When** `relaunch --close-terminal` runs, **Then** the close is followed by the reclaim of User Story 2.
4. **Given** a close whose receipt is not `ptyKilled: true`, or whose terminal or processes persist, **When** it runs, **Then** it refuses and reports the evidence.

---

### User Story 4 - Everything not proven keeps refusing, naming the state (Priority: P1)

**Why this priority**: A duplicate agent on a live worktree is the failure this slice must not introduce.

**Independent Test**: The fake-Orca matrix for alive, dead, missing, unreadable, ambiguous, and non-local.

**Acceptance Scenarios**:

1. **Given** an endpoint reading `ambiguous`, `unreadable`, or `unverified`, **When** `exit` or `relaunch` runs, **Then** it refuses and the message names that state.
2. **Given** a runtime selected through `ORCA_ENVIRONMENT`, `ORCA_PAIRING_CODE`, or `ORCA_REMOTE_PAIRING`, **When** a terminal reads missing, **Then** absence is unproven and both verbs refuse.
3. **Given** a terminal the runtime reports gone while a local process still carries its handle, **When** the reclaim is considered, **Then** it refuses rather than launching beside a possibly live agent.
4. **Given** `--close-terminal` with any state other than `alive`, or on another backend, **When** it runs, **Then** it refuses.
5. **Given** an Orca secondmate record, **When** a relaunch or reclaim is requested, **Then** it refuses.

---

### User Story 5 - Teardown still refuses unlanded work (Priority: P1)

**Why this priority**: Hard rule 3 holds across every new recovery path.

**Independent Test**: The live lab, after a reclaim.

**Acceptance Scenarios**:

1. **Given** a reclaimed task whose branch holds an unlanded commit, **When** `bin/fm-teardown.sh` runs without force, **Then** it refuses and leaves the terminal, worktree, and record in place.

## Functional Requirements

- **FR-001**: `fm_control_backend_state_verified` admits Orca, and the control plane proceeds only on a state the classifier proves.
- **FR-002**: `fm-control exit` on Orca reports `already-stopped` for `dead`, `endpoint-gone` for a locally proven `missing`, and refuses every other state, naming it, unless `--close-terminal` applies.
- **FR-003**: `--close-terminal` is accepted only by `exit` and `relaunch`, only for an Orca task, and only while the agent reads `alive`; it closes the recorded terminal and takes `ptyKilled: true` as the stopped proof.
- **FR-004**: After a close the endpoint must read `missing` and no local process may carry the handle, within a bounded wait, or the verb refuses.
- **FR-005**: Absence of an Orca terminal is proven only when the runtime is local, reads the terminal missing, and no local process carries its handle.
- **FR-006**: `bin/fm-spawn.sh --relaunch` on Orca adopts a `dead` terminal and reclaims a proven-gone one; it reads `orca_worktree_id=` and `terminal=` from the record and republishes both.
- **FR-007**: A reclaim closes the dead terminal before creating one, creates exactly one terminal by the recorded worktree id, titles it, and confirms it is listed for that worktree and the old one is not.
- **FR-008**: A failed reclaim never removes the worktree, and closes only a terminal it created itself.
- **FR-009**: No path in this feature calls `worktree rm`, `terminal close --all`, or any teardown operation.
- **FR-010**: A relaunch on Orca checks the runtime's readiness and version floor before any mutation.
- **FR-011**: An Orca secondmate record is refused.
- **FR-012**: `fm-control interrupt` on Orca keeps working; its proof stays the endpoint's existence when the agent state is `unverified`, `ambiguous`, or `unreadable`.
- **FR-013**: `docs/agent-control.md`, `docs/orca-backend.md`, the `stuck-crewmate-recovery` skill, and `docs/verification/runtime-backends.md` state the new behavior and drop the wording that exit and relaunch refuse on Orca.

## Out of Scope

- A real-harness turn (a later slice that needs a throwaway login).
- Activating the staged 1.4.263 or 1.4.264 builds.
- `agent launch`, `worktree create --agent`, orchestration, automations, skills, account, or hook verbs.
- Remote or paired runtimes: they stay refused.
- Secondmate reclaim on Orca.

## Edge Cases

- A terminal the runtime reports stale after a restart while its processes survive: refused by FR-005.
- A close that is accepted but whose terminal lingers: refused by FR-004.
- A reclaim interrupted after the new terminal exists but before the record is published: the new terminal is closed on abort, and the old record, worktree, and any unlanded work stay.
- The recorded terminal missing while another terminal of the worktree exists: the other is never closed or adopted.
